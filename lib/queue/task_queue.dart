import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../browser/browser_controller.dart';
import '../capture/capture_job.dart';
import '../core/config.dart';
import '../core/url_utils.dart';
import '../capture/capture_preflight.dart';
import '../capture/capture_state.dart';
import '../library/series_identity.dart';
import '../library/update_checker.dart';
import '../storage/cleanup.dart';
import '../storage/database.dart';
import '../storage/file_store.dart';

const _uuid = Uuid();

/// What a queue entry does. `checkAllSeries` is scheduled here but expands
/// into per-series checks when M15 lands; the scheduler does not special-case
/// it beyond the type name.
enum QueueTaskType {
  chapterCapture,
  multiChapterCapture,
  seriesCheck,
  checkAllSeries,

  /// Bulk offline-file removal (a whole series, or every finished chapter).
  /// Removal is never metadata deletion; see [CleanupService].
  removeOfflineFiles,
}

QueueTaskType queueTaskTypeFromName(String name) => QueueTaskType.values
    .firstWhere((t) => t.name == name, orElse: () => QueueTaskType.seriesCheck);

/// What a removeOfflineFiles task targets, encoded in `startUrl` (the column
/// is free-form text; a cleanup task has no URL): `series` uses
/// libraryItemId; `finishedEverywhere` sweeps every completed offline
/// chapter in the active library.
const kCleanupScopeSeries = 'cleanup:series';
const kCleanupScopeFinished = 'cleanup:finishedEverywhere';

enum QueueTaskState { queued, running, completed, failed, cancelled }

/// Whether a capture task is Browser-dependent from the queue's point of
/// view. Checks drive the WebView too; cleanup never does.
bool taskNeedsBrowser(QueueTaskType type) => switch (type) {
  QueueTaskType.chapterCapture ||
  QueueTaskType.multiChapterCapture ||
  QueueTaskType.seriesCheck ||
  QueueTaskType.checkAllSeries => true,
  QueueTaskType.removeOfflineFiles => false,
};

/// Capture is the only work that waits for an explicit start.
///
/// Update checks and cleanup are cheap, bounded, and already user-initiated
/// per action; making them wait behind a second confirmation would be
/// ceremony. Capture is the one that opens the Browser, holds it for minutes
/// and downloads megabytes — so it is the one the user gets to batch up and
/// start deliberately (D46).
bool taskWaitsForExplicitStart(QueueTaskType type) =>
    type == QueueTaskType.chapterCapture ||
    type == QueueTaskType.multiChapterCapture;

/// What [TaskQueueController.enqueueCapture] did.
///
/// `alreadyQueued` is not a failure: the chapter is in the queue, which is
/// what the user wanted. It exists so the caller can say "already in the
/// queue" instead of a second "added".
class QueueEnqueueResult {
  const QueueEnqueueResult({required this.id, required this.alreadyQueued});

  final String id;
  final bool alreadyQueued;
}

/// The counts the Activity screen and the Library strip both quote.
class QueueSummary {
  const QueueSummary({
    required this.queuedCaptures,
    required this.queuedOther,
    required this.running,
    required this.failed,
    required this.completed,
    required this.cancelled,
  });

  final int queuedCaptures;
  final int queuedOther;
  final int running;
  final int failed;
  final int completed;
  final int cancelled;

  int get queued => queuedCaptures + queuedOther;
  int get remaining => queued + running;
  bool get hasQueuedCaptures => queuedCaptures > 0;

  factory QueueSummary.of(List<QueueTask> tasks) {
    var qc = 0, qo = 0, r = 0, f = 0, c = 0, x = 0;
    for (final t in tasks) {
      switch (queueTaskStateFromName(t.state)) {
        case QueueTaskState.queued:
          if (taskWaitsForExplicitStart(queueTaskTypeFromName(t.taskType))) {
            qc++;
          } else {
            qo++;
          }
        case QueueTaskState.running:
          r++;
        case QueueTaskState.failed:
          f++;
        case QueueTaskState.completed:
          c++;
        case QueueTaskState.cancelled:
          x++;
      }
    }
    return QueueSummary(
      queuedCaptures: qc,
      queuedOther: qo,
      running: r,
      failed: f,
      completed: c,
      cancelled: x,
    );
  }
}

QueueTaskState queueTaskStateFromName(String name) => QueueTaskState.values
    .firstWhere((s) => s.name == name, orElse: () => QueueTaskState.failed);

/// How one task run ended, as the scheduler records it.
class QueueOutcome {
  const QueueOutcome.success(this.summary) : failed = false;
  const QueueOutcome.failure(this.summary) : failed = true;

  final String summary;
  final bool failed;
}

/// Schedules autonomous work — it never performs any.
///
/// The design line that keeps this from becoming a second job system: the
/// queue owns *ordering, persistence and history*; the work itself stays in
/// [CaptureJobController] and [UpdateChecker], which already know how to
/// capture, check, pause, and clean up after themselves. One task runs at a
/// time — the shared WebView (`automationOwner`) makes concurrency structurally
/// impossible anyway, so the scheduler simply respects that.
///
/// Restart semantics: queued work is **offered, never auto-resumed**
/// ([OPEN_QUESTIONS.md] Q24) — the same rule the interrupted-capture card has
/// always followed. Nothing navigates a WebView at launch because a row said
/// so yesterday.
class TaskQueueController extends ChangeNotifier {
  TaskQueueController({
    required this.db,
    required this.captureJob,
    required this.checker,
    required this.browser,
    CleanupService? cleanup,
    this.historyLimit = 50,
    @visibleForTesting this.captureRunner,
    @visibleForTesting this.checkRunner,
  }) : cleanup =
           cleanup ??
           CleanupService(
             db: db,
             fileStore: FileStore(Directory.systemTemp),
             captureJob: captureJob,
           ) {
    // The pump defers while someone else owns the WebView (a resumed capture,
    // a directly-started check). Ownership release does not notify by itself,
    // but both controllers notify at the end of their runs — after clearing
    // the owner — so listening to them closes the stall: queued work drains
    // as soon as the browser frees, not at the next enqueue.
    captureJob.addListener(_maybePump);
    checker.addListener(_maybePump);
  }

  @override
  void dispose() {
    captureJob.removeListener(_maybePump);
    checker.removeListener(_maybePump);
    super.dispose();
  }

  void _maybePump() {
    if (_pumping || _resumeOffered) return;
    if (browser.automationOwner != null) return;
    unawaited(_pump());
  }

  /// Is this chapter already spoken for?
  ///
  /// Matches on the normalised start URL across queued and running capture
  /// rows only. History is deliberately excluded: a chapter captured last
  /// week must not block an intentional re-fetch today.
  Future<QueueTask?> pendingCaptureFor(String startUrl) async {
    final key = normalizeUrl(startUrl);
    if (key.isEmpty) return null;
    final pending = await db.pendingQueueTasks();
    for (final task in pending) {
      if (!taskWaitsForExplicitStart(queueTaskTypeFromName(task.taskType))) {
        continue;
      }
      final url = task.startUrl;
      if (url != null && normalizeUrl(url) == key) return task;
    }
    return null;
  }

  final AppDatabase db;
  final CaptureJobController captureJob;
  final UpdateChecker checker;
  final BrowserController browser;
  final CleanupService cleanup;
  final int historyLimit;

  /// Test seams: replace the real work while keeping the real scheduler.
  final Future<QueueOutcome> Function(QueueTask task)? captureRunner;
  final Future<QueueOutcome> Function(QueueTask task)? checkRunner;

  bool _pumping = false;
  bool get isRunning => _pumping;

  String? _runningTaskId;
  String? get runningTaskId => _runningTaskId;

  /// True after construction when persisted queued work exists but has not
  /// been resumed. The UI offers a single "resume queue" action; nothing
  /// runs until it is taken (or new work is enqueued, which is fresh user
  /// intent).
  bool _resumeOffered = false;
  bool get resumeOffered => _resumeOffered;

  final Set<String> _cancelRequested = {};

  /// True between "the user pressed Start Capture" and the capture queue
  /// running dry.
  ///
  /// **Not persisted, deliberately.** Queued rows survive a restart; the
  /// permission to drive the Browser does not. A relaunch that resumed
  /// scrolling because a row existed yesterday is exactly what Q24 forbids,
  /// and D46 makes it a product rule rather than an accident of timing.
  bool _captureStartAuthorised = false;
  bool get captureStartAuthorised => _captureStartAuthorised;

  /// Asked before a Browser-dependent task runs: bring the Browser forward
  /// and tell us whether its WebView is actually there.
  ///
  /// Injected by the shell, which is the thing that owns tab switching. Null
  /// in tests and headless contexts, where it degrades to "assume visible" —
  /// the capture engine's own render guard is the real safety net, this is
  /// the *navigation*.
  Future<bool> Function()? ensureBrowserVisible;

  /// Queued capture work the user has not started yet.
  Future<List<QueueTask>> queuedCaptures() async {
    final pending = await db.pendingQueueTasks();
    return [
      for (final t in pending)
        if (t.state == QueueTaskState.queued.name &&
            taskWaitsForExplicitStart(queueTaskTypeFromName(t.taskType)))
          t,
    ];
  }

  /// The user pressed Start Capture. Authorises Browser automation for the
  /// queued captures and starts draining; returns how many were released.
  Future<int> startQueuedCaptures() async {
    final waiting = await queuedCaptures();
    if (waiting.isEmpty) return 0;
    _captureStartAuthorised = true;
    _resumeOffered = false;
    notifyListeners();
    unawaited(_pump());
    return waiting.length;
  }

  /// Start one queued capture ahead of the rest: it moves to the front, and
  /// the queue is authorised as if Start Capture had been pressed.
  Future<bool> startQueuedTask(String id) async {
    final task = await db.queueTaskById(id);
    if (task == null || task.state != QueueTaskState.queued.name) return false;
    await moveQueuedToFront(id);
    _captureStartAuthorised = true;
    _resumeOffered = false;
    notifyListeners();
    unawaited(_pump());
    return true;
  }

  /// Stop the batch: the running task is asked to stop and the remaining
  /// queued captures go back to waiting. They are **not** cancelled — the
  /// user stopped the run, not the plan.
  Future<void> stopQueuedCaptures() async {
    _captureStartAuthorised = false;
    final id = _runningTaskId;
    if (id != null) await cancelTask(id);
    notifyListeners();
  }

  /// Call once at startup: discovers leftover work and turns it into an
  /// offer. A row left `running` by a kill is demoted to `queued` — it never
  /// ran to completion, and it must not pretend it did.
  Future<void> restore() async {
    final pending = await db.pendingQueueTasks();
    for (final task in pending.where((t) => t.state == 'running')) {
      await db.upsertQueueTask(
        task.copyWith(state: 'queued', startedAt: const Value(null)),
      );
    }
    _resumeOffered = pending.isNotEmpty;
    notifyListeners();
  }

  /// The user accepted the resume offer. Starts the pump and returns — the
  /// queue drains in the background; progress is observable, not awaited.
  void resumeQueue() {
    _resumeOffered = false;
    notifyListeners();
    unawaited(_pump());
  }

  // --- enqueueing -----------------------------------------------------------

  /// Add a capture request. It **waits** — nothing navigates, nothing
  /// scrolls, no WebView is touched until the user starts the queue (D46).
  ///
  /// Deduplicated against queued and running capture rows by start URL, so a
  /// second tap on the same chapter reports "already queued" rather than
  /// stacking an identical run behind the first.
  Future<QueueEnqueueResult> enqueueCapture({
    required String startUrl,
    required int chapterLimit,
    String? libraryItemId,
    DuplicatePolicy policy = DuplicatePolicy.ask,
    CaptureRangeMode range = CaptureRangeMode.fixedCount,
  }) async {
    final existing = await pendingCaptureFor(startUrl);
    if (existing != null) {
      return QueueEnqueueResult(id: existing.id, alreadyQueued: true);
    }
    final id = await _enqueue(
      QueueTask(
        id: _uuid.v4(),
        taskType: range != CaptureRangeMode.currentChapter && chapterLimit > 1
            ? QueueTaskType.multiChapterCapture.name
            : QueueTaskType.chapterCapture.name,
        libraryItemId: libraryItemId,
        startUrl: startUrl,
        chapterLimit: chapterLimit,
        duplicatePolicy: policy.name,
        rangeMode: range.name,
        state: QueueTaskState.queued.name,
        orderIndex: 0, // assigned in _enqueue
        queuedAt: DateTime.now(),
      ),
    );
    return QueueEnqueueResult(id: id, alreadyQueued: false);
  }

  /// Queue a set of chapters for capture, oldest first.
  ///
  /// [chapters] arrives in whatever order the screen was displaying — which
  /// is usually newest-first — and is re-sorted into **reading order** here.
  /// Capture walks forward through a series; queueing 490, 489, 488 in that
  /// order would fight the chain-following the engine does on its own.
  ///
  /// Each chapter becomes its own single-chapter task against its own stored
  /// URL, so one bad page cannot strand the rest, and every row keeps its
  /// existing chapter record (D48).
  Future<BatchQueueResult> enqueueChapters(
    List<Chapter> chapters, {
    DuplicatePolicy policy = DuplicatePolicy.replaceAll,
  }) async {
    final ordered = sortChaptersForCaptureOrder(chapters);
    final queued = <String>[];
    final already = <Chapter>[];
    final noSource = <Chapter>[];

    for (final chapter in ordered) {
      if (!chapterHasCapturableUrl(chapter)) {
        noSource.add(chapter);
        continue;
      }
      final result = await enqueueCapture(
        startUrl: chapter.sourceUrl.trim(),
        chapterLimit: 1,
        libraryItemId: chapter.libraryItemId,
        policy: policy,
        range: CaptureRangeMode.currentChapter,
      );
      if (result.alreadyQueued) {
        already.add(chapter);
      } else {
        queued.add(result.id);
      }
    }
    return BatchQueueResult(
      queuedIds: queued,
      alreadyQueued: already,
      missingSource: noSource,
    );
  }

  /// Idempotent per series: a check is a metadata read, so a second tap while
  /// one is already queued or running for the same series returns the
  /// existing task instead of stacking a duplicate behind it.
  Future<String> enqueueSeriesCheck(String libraryItemId) async {
    final pending = await db.pendingQueueTasks();
    final existing = pending
        .where(
          (t) =>
              t.taskType == QueueTaskType.seriesCheck.name &&
              t.libraryItemId == libraryItemId,
        )
        .firstOrNull;
    if (existing != null) {
      // Re-offer nothing, but make sure a queued row actually gets pumped.
      _maybePump();
      return existing.id;
    }
    return _enqueue(
      QueueTask(
        id: _uuid.v4(),
        taskType: QueueTaskType.seriesCheck.name,
        libraryItemId: libraryItemId,
        state: QueueTaskState.queued.name,
        orderIndex: 0,
        queuedAt: DateTime.now(),
      ),
    );
  }

  /// M15: "check everything" expands into one [QueueTaskType.seriesCheck] row
  /// per series rather than one opaque mega-task. That choice does the heavy
  /// lifting for free: a kill mid-run leaves the remainder as queued rows the
  /// restart offer picks up, one series' failure is its own history row with
  /// its own reason, and progress is just the queue's own counts.
  ///
  /// Idempotent via [enqueueSeriesCheck]'s per-series dedupe: series already
  /// pending are not stacked again. Returns the task ids, existing or new.
  Future<List<String>> enqueueCheckAll() async {
    final items = await db.allLibraryItems();
    final ids = <String>[];
    for (final item in items) {
      // Archived series are asleep: no checks until restored (M16).
      if (item.lifecycle == 'archived') continue;
      ids.add(await enqueueSeriesCheck(item.id));
    }
    return ids;
  }

  /// Everything still pending for one series — the number the archive dialog
  /// quotes before it cancels them.
  Future<List<QueueTask>> pendingTasksForSeries(String libraryItemId) async {
    final pending = await db.pendingQueueTasks();
    return pending.where((t) => t.libraryItemId == libraryItemId).toList();
  }

  /// M16 (Q25): archiving a series takes its pending work with it — queued
  /// rows are cancelled outright, a running one is asked to stop. Returns how
  /// many tasks were affected.
  Future<int> cancelTasksForSeries(String libraryItemId) async {
    final affected = await pendingTasksForSeries(libraryItemId);
    for (final task in affected) {
      await cancelTask(task.id);
    }
    return affected.length;
  }

  /// Cancel every *queued* check, leaving the in-flight one to finish — the
  /// M15 cancel semantic: "stop after the current series".
  Future<int> cancelQueuedChecks() async {
    final pending = await db.pendingQueueTasks();
    final queuedChecks = pending
        .where(
          (t) =>
              t.state == QueueTaskState.queued.name &&
              (t.taskType == QueueTaskType.seriesCheck.name ||
                  t.taskType == QueueTaskType.checkAllSeries.name),
        )
        .toList();
    for (final task in queuedChecks) {
      await _finish(
        task,
        QueueTaskState.cancelled,
        const QueueOutcome.failure('cancelled before it started'),
      );
    }
    return queuedChecks.length;
  }

  /// Bulk offline-file removal as an observable task: a whole series
  /// (pass [libraryItemId]) or every finished offline chapter everywhere.
  /// Small single-chapter removals stay inline (toast + undo) — a queue row
  /// for an instant is noise.
  Future<String> enqueueCleanup({String? libraryItemId}) => _enqueue(
    QueueTask(
      id: _uuid.v4(),
      taskType: QueueTaskType.removeOfflineFiles.name,
      libraryItemId: libraryItemId,
      startUrl: libraryItemId != null
          ? kCleanupScopeSeries
          : kCleanupScopeFinished,
      state: QueueTaskState.queued.name,
      orderIndex: 0,
      queuedAt: DateTime.now(),
    ),
  );

  Future<String> _enqueue(QueueTask task) async {
    final order = await db.nextQueueOrderIndex();
    await db.upsertQueueTask(task.copyWith(orderIndex: order));
    notifyListeners();
    // Captures wait for an explicit start (D46); checks and cleanup are
    // cheap and already one-action-one-intent, so they drain immediately.
    if (!taskWaitsForExplicitStart(queueTaskTypeFromName(task.taskType))) {
      unawaited(_pump());
    }
    return task.id;
  }

  // --- controls ---------------------------------------------------------------

  /// Cancel a queued task outright, or ask the running one to stop.
  Future<void> cancelTask(String id) async {
    final task = await db.queueTaskById(id);
    if (task == null) return;
    if (task.state == QueueTaskState.queued.name) {
      await _finish(
        task,
        QueueTaskState.cancelled,
        const QueueOutcome.failure('cancelled before it started'),
      );
      return;
    }
    if (task.state == QueueTaskState.running.name) {
      _cancelRequested.add(id);
      switch (queueTaskTypeFromName(task.taskType)) {
        case QueueTaskType.chapterCapture:
        case QueueTaskType.multiChapterCapture:
          captureJob.stop();
        case QueueTaskType.seriesCheck:
        case QueueTaskType.checkAllSeries:
          checker.cancel();
        case QueueTaskType.removeOfflineFiles:
          // Removal batches finish each chapter atomically; there is no
          // mid-chapter state to interrupt. The flag stops it via _finish.
          break;
      }
      notifyListeners();
    }
  }

  // --- reordering and queue management --------------------------------------

  /// Move a queued task to the front of the queue.
  Future<void> moveQueuedToFront(String id) async {
    final queued = await _queuedInOrder();
    final ordered = [
      ...queued.where((t) => t.id == id),
      ...queued.where((t) => t.id != id),
    ];
    await _writeOrder(ordered);
  }

  /// Shift a queued task by [delta] places (-1 up, +1 down). Clamped: the
  /// ends are ends, not wrap-arounds.
  Future<void> moveQueued(String id, int delta) async {
    final queued = await _queuedInOrder();
    final from = queued.indexWhere((t) => t.id == id);
    if (from < 0) return;
    final to = (from + delta).clamp(0, queued.length - 1);
    if (to == from) return;
    final ordered = [...queued];
    ordered.insert(to, ordered.removeAt(from));
    await _writeOrder(ordered);
  }

  Future<List<QueueTask>> _queuedInOrder() async {
    final pending = await db.pendingQueueTasks();
    return [
      for (final t in pending)
        if (t.state == QueueTaskState.queued.name) t,
    ]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  /// Renumber from a base above every existing row, so a reorder can never
  /// collide with a running task's index or with history.
  Future<void> _writeOrder(List<QueueTask> ordered) async {
    var next = await db.nextQueueOrderIndex();
    for (final task in ordered) {
      await db.upsertQueueTask(task.copyWith(orderIndex: next++));
    }
    notifyListeners();
  }

  /// Drop every queued capture. Metadata and offline files are untouched —
  /// this cancels *plans*, never content.
  Future<int> clearQueuedCaptures() async {
    final waiting = await queuedCaptures();
    for (final task in waiting) {
      await _finish(
        task,
        QueueTaskState.cancelled,
        const QueueOutcome.failure('removed from the queue before it started'),
      );
    }
    if (waiting.isNotEmpty) notifyListeners();
    return waiting.length;
  }

  /// Pause/resume forward to the capture job (checks have no pause).
  void pauseRunning() => captureJob.pause();
  void resumeRunning() => captureJob.resume();

  /// Re-enqueue a terminal task as a fresh entry at the back of the queue.
  Future<String?> retryTask(String id) async {
    final task = await db.queueTaskById(id);
    if (task == null) return null;
    final terminal = const ['completed', 'failed', 'cancelled'];
    if (!terminal.contains(task.state)) return null;
    return _enqueue(
      task.copyWith(
        id: _uuid.v4(),
        state: QueueTaskState.queued.name,
        outcome: const Value(null),
        lastError: const Value(null),
        queuedAt: DateTime.now(),
        startedAt: const Value(null),
        finishedAt: const Value(null),
      ),
    );
  }

  /// Delete terminal history. Never touches queued/running rows, and queue
  /// rows are never the content — captured chapters are unaffected.
  Future<void> clearHistory() async {
    await db.clearQueueHistory();
    notifyListeners();
  }

  // --- the pump ---------------------------------------------------------------

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    notifyListeners();
    try {
      while (true) {
        final pending = await db.pendingQueueTasks();
        // Eligible = queued, and either not capture work or capture work the
        // user has explicitly started. A queued capture sitting behind an
        // un-pressed Start button must not block a check behind it.
        final next = pending
            .where(
              (t) =>
                  t.state == 'queued' &&
                  (_captureStartAuthorised ||
                      !taskWaitsForExplicitStart(
                        queueTaskTypeFromName(t.taskType),
                      )),
            )
            .firstOrNull;
        if (next == null) break;

        // One driver on the shared WebView. Someone else (a directly-started
        // capture, a manual check) owning it is not an error — wait our turn
        // by stopping the pump; the next enqueue or resume pumps again.
        if (browser.automationOwner != null) break;

        // The Browser comes forward BEFORE any WebView automation, never as
        // a side effect of it (D47). A queue task must not begin scrolling
        // while the user is still looking at the Library.
        if (taskNeedsBrowser(queueTaskTypeFromName(next.taskType))) {
          final ready = await ensureBrowserVisible?.call() ?? true;
          if (!ready) {
            // Not an error and not a cancellation: the Browser could not be
            // brought up, so the work stays queued for the next attempt.
            break;
          }
        }

        _runningTaskId = next.id;
        await db.upsertQueueTask(
          next.copyWith(state: 'running', startedAt: Value(DateTime.now())),
        );
        notifyListeners();

        QueueOutcome outcome;
        try {
          outcome = await _run(next);
        } catch (e) {
          outcome = QueueOutcome.failure(e.toString());
        }

        final wasCancelled = _cancelRequested.remove(next.id);
        await _finish(
          (await db.queueTaskById(next.id))!,
          wasCancelled
              ? QueueTaskState.cancelled
              : (outcome.failed
                    ? QueueTaskState.failed
                    : QueueTaskState.completed),
          outcome,
        );
        _runningTaskId = null;
        notifyListeners();
      }
    } finally {
      _pumping = false;
      _runningTaskId = null;
      // A drained capture queue revokes its own permission: adding more work
      // later is a new decision and gets a new Start.
      if (_captureStartAuthorised && (await queuedCaptures()).isEmpty) {
        _captureStartAuthorised = false;
      }
      notifyListeners();
    }
  }

  Future<QueueOutcome> _run(QueueTask task) async {
    switch (queueTaskTypeFromName(task.taskType)) {
      case QueueTaskType.chapterCapture:
      case QueueTaskType.multiChapterCapture:
        if (captureRunner != null) return captureRunner!(task);
        await captureJob.start(
          chapterLimit: task.chapterLimit ?? 1,
          startUrl: task.startUrl,
          policy: duplicatePolicyFromName(task.duplicatePolicy),
          range: captureRangeModeFromName(task.rangeMode),
        );
        final p = captureJob.progress;
        final summary =
            '${p.storedChapters} captured'
            '${p.skippedChapters > 0 ? ', ${p.skippedChapters} skipped' : ''}';
        return p.state == CaptureState.failed
            ? QueueOutcome.failure(p.lastError ?? summary)
            : QueueOutcome.success(summary);
      case QueueTaskType.removeOfflineFiles:
        if (checkRunner != null) return checkRunner!(task);
        return _runCleanup(task);
      case QueueTaskType.seriesCheck:
      case QueueTaskType.checkAllSeries:
        if (checkRunner != null) return checkRunner!(task);
        final itemId = task.libraryItemId;
        if (itemId == null) {
          return const QueueOutcome.failure('no series attached to the task');
        }
        final result = await checker.check(itemId);
        final summary = switch (result.state) {
          UpdateCheckState.upToDate => 'up to date',
          UpdateCheckState.updatesAvailable =>
            '${result.newChapters} new chapter(s)',
          UpdateCheckState.cancelled => 'cancelled',
          _ => result.error ?? result.state.name,
        };
        return result.state == UpdateCheckState.failed
            ? QueueOutcome.failure(summary)
            : QueueOutcome.success(summary);
    }
  }

  /// Removal never touches metadata; locked chapters (open reader, active
  /// capture) are kept and counted. Progress lands on the task row so the
  /// Activity screen can show "18 / 42 · 1.2 GB freed" live.
  Future<QueueOutcome> _runCleanup(QueueTask task) async {
    final all = task.libraryItemId != null
        ? await db.chaptersForItem(task.libraryItemId!)
        : await _finishedOfflineEverywhere();
    final targets = [
      for (final c in all)
        if (cleanup.isRemovable(c) &&
            (task.libraryItemId != null || c.readStatus == 'completed'))
          c.id,
    ];
    if (targets.isEmpty) {
      return const QueueOutcome.success('nothing to remove');
    }
    final result = await cleanup.removeOfflineNow(
      targets,
      onProgress: (processed, freed) async {
        if (processed % 5 != 0) return;
        final row = await db.queueTaskById(task.id);
        if (row == null) return;
        await db.upsertQueueTask(
          row.copyWith(
            outcome: Value(
              '$processed / ${targets.length} · ${_fmtBytes(freed)} freed',
            ),
          ),
        );
        notifyListeners();
      },
    );
    final kept = result.keptLocked.isEmpty
        ? ''
        : ' · ${result.keptLocked.length} kept (in use)';
    return QueueOutcome.success(
      '${result.removed} chapter(s) removed · '
      '${_fmtBytes(result.freedBytes)} freed$kept',
    );
  }

  /// Completed offline chapters across the ACTIVE library (archived series
  /// are asleep; their files are removed per-series if the user wants).
  Future<List<Chapter>> _finishedOfflineEverywhere() async {
    final items = await db.allLibraryItems();
    final active = {
      for (final i in items)
        if (i.lifecycle != 'archived') i.id,
    };
    final chapters = await db.allChapters();
    return [
      for (final c in chapters)
        if (active.contains(c.libraryItemId) && c.readStatus == 'completed') c,
    ];
  }

  static String _fmtBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).round()} MB';
    return '${(bytes / 1024).round()} KB';
  }

  Future<void> _finish(
    QueueTask task,
    QueueTaskState state,
    QueueOutcome outcome,
  ) async {
    await db.upsertQueueTask(
      task.copyWith(
        state: state.name,
        outcome: Value(outcome.summary),
        lastError: Value(outcome.failed ? outcome.summary : null),
        finishedAt: Value(DateTime.now()),
      ),
    );
    await db.pruneQueueHistory(keep: historyLimit);
    notifyListeners();
  }
}

/// A chapter can be captured automatically only when it still knows where it
/// came from. Removing offline files never touches `source_url` (D42), so a
/// removed chapter normally does; a row written blank by an older build does
/// not, and must be reported rather than silently dropped.
bool chapterHasCapturableUrl(Chapter chapter) {
  final url = chapter.sourceUrl.trim();
  if (url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}

/// Reading order — the order capture should run in, whatever the list was
/// showing. Decimal-safe, because [compareChaptersForReading] is.
List<Chapter> sortChaptersForCaptureOrder(List<Chapter> chapters) {
  final sorted = [...chapters];
  sorted.sort(
    (a, b) => compareChaptersForReading(
      (number: a.chapterNumber, sequence: a.sequence, capturedAt: a.capturedAt),
      (number: b.chapterNumber, sequence: b.sequence, capturedAt: b.capturedAt),
    ),
  );
  return sorted;
}

/// What a multi-select "add to capture queue" actually did.
///
/// Three outcomes rather than a bool, because a selection of eight chapters
/// where two have no source page is a *partial* success and the sheet has to
/// be able to say so (D48).
class BatchQueueResult {
  const BatchQueueResult({
    required this.queuedIds,
    required this.alreadyQueued,
    required this.missingSource,
  });

  final List<String> queuedIds;
  final List<Chapter> alreadyQueued;
  final List<Chapter> missingSource;

  int get queued => queuedIds.length;
  int get skipped => alreadyQueued.length + missingSource.length;
  bool get didNothing => queuedIds.isEmpty;
}

extension on Iterable<QueueTask> {
  QueueTask? get firstOrNull => isEmpty ? null : first;
}

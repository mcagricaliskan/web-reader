import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../browser/browser_controller.dart';
import '../capture/capture_job.dart';
import '../core/config.dart';
import '../capture/capture_preflight.dart';
import '../capture/capture_state.dart';
import '../library/update_checker.dart';
import '../storage/database.dart';

const _uuid = Uuid();

/// What a queue entry does. `checkAllSeries` is scheduled here but expands
/// into per-series checks when M15 lands; the scheduler does not special-case
/// it beyond the type name.
enum QueueTaskType {
  chapterCapture,
  multiChapterCapture,
  seriesCheck,
  checkAllSeries,
}

QueueTaskType queueTaskTypeFromName(String name) => QueueTaskType.values
    .firstWhere((t) => t.name == name, orElse: () => QueueTaskType.seriesCheck);

enum QueueTaskState { queued, running, completed, failed, cancelled }

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
    this.historyLimit = 50,
    @visibleForTesting this.captureRunner,
    @visibleForTesting this.checkRunner,
  }) {
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

  final AppDatabase db;
  final CaptureJobController captureJob;
  final UpdateChecker checker;
  final BrowserController browser;
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

  Future<String> enqueueCapture({
    required String startUrl,
    required int chapterLimit,
    String? libraryItemId,
    DuplicatePolicy policy = DuplicatePolicy.ask,
    CaptureRangeMode range = CaptureRangeMode.fixedCount,
  }) => _enqueue(
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

  Future<String> _enqueue(QueueTask task) async {
    final order = await db.nextQueueOrderIndex();
    await db.upsertQueueTask(task.copyWith(orderIndex: order));
    notifyListeners();
    // Enqueueing IS user intent, right now — the no-auto-run rule is about
    // restarts, not about work the user just asked for.
    unawaited(_pump());
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
      }
      notifyListeners();
    }
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
        final next = pending.where((t) => t.state == 'queued').firstOrNull;
        if (next == null) break;

        // One driver on the shared WebView. Someone else (a directly-started
        // capture, a manual check) owning it is not an error — wait our turn
        // by stopping the pump; the next enqueue or resume pumps again.
        if (browser.automationOwner != null) break;

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

extension on Iterable<QueueTask> {
  QueueTask? get firstOrNull => isEmpty ? null : first;
}

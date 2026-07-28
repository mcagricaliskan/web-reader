import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_preflight.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/library/update_checker.dart';
import 'package:web_reader/queue/task_queue.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

import 'helpers/fake_browser.dart';

/// Start Capture runs *this* request, now, and leaves the queue alone (D58).
///
/// The rule under test in one sentence: a direct capture creates no pending
/// queue task, releases none, reorders none, and finishing it authorises
/// nothing — the pending batch is still waiting for its own Start.
void main() {
  late AppDatabase db;
  late Directory root;
  late FakeBrowser browser;
  late _ScriptedJob job;
  late _FakeChecker checker;
  late List<String> executed;
  late List<String> browserAsks;
  late bool browserAvailable;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_direct_capture');
    browser = FakeBrowser();
    job = _ScriptedJob(browser: browser, db: db, fileStore: FileStore(root));
    checker = _FakeChecker(browser: browser, db: db);
    executed = [];
    browserAsks = [];
    browserAvailable = true;
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  TaskQueueController makeQueue() {
    final queue = TaskQueueController(
      db: db,
      browser: browser,
      captureJob: job,
      checker: checker,
      captureRunner: (task) async {
        executed.add(task.startUrl ?? task.id);
        return const QueueOutcome.success('captured');
      },
      checkRunner: (task) async {
        executed.add('check:${task.libraryItemId}');
        return const QueueOutcome.success('checked');
      },
    );
    queue.ensureBrowserVisible = () async {
      browserAsks.add('asked');
      return browserAvailable;
    };
    return queue;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 120));

  String url(int n) => 'https://x.example/manga/foo/$n';

  Future<void> queueThree(TaskQueueController queue) async {
    for (final n in [200, 201, 202]) {
      await queue.enqueueCapture(startUrl: url(n), chapterLimit: 1);
    }
  }

  group('starting directly', () {
    test('runs the request and creates no pending queue task', () async {
      final queue = makeQueue();

      final result = await queue.startDirectCapture(
        startUrl: url(350),
        chapterLimit: 1,
        range: CaptureRangeMode.currentChapter,
      );
      expect(result, DirectStartResult.started);
      expect(browserAsks, ['asked'], reason: 'rendered-Browser check first');
      await settle();

      expect(job.started, [url(350)]);
      expect(job.origin, CaptureOrigin.direct);
      expect(
        await queue.queuedCaptures(),
        isEmpty,
        reason: 'a direct capture is not a queue entry',
      );
    });

    test('the run only begins after the Browser is confirmed', () async {
      browserAvailable = false;
      final queue = makeQueue();

      final result = await queue.startDirectCapture(
        startUrl: url(350),
        chapterLimit: 1,
      );
      await settle();

      expect(result, DirectStartResult.browserUnavailable);
      expect(job.started, isEmpty, reason: 'nothing scrolled');
      expect(await db.pendingQueueTasks(), isEmpty, reason: 'and nothing sat');
    });

    test('an empty page is refused before anything is created', () async {
      final queue = makeQueue();
      expect(
        await queue.startDirectCapture(startUrl: '   ', chapterLimit: 1),
        DirectStartResult.noPage,
      );
      expect(browserAsks, isEmpty);
      expect(await db.pendingQueueTasks(), isEmpty);
    });

    test('the outcome lands in Activity history as a direct run', () async {
      final queue = makeQueue();
      await queue.startDirectCapture(startUrl: url(350), chapterLimit: 1);
      await job.finish(stored: 1);
      await settle();

      final rows = await db.watchQueueTasks().first;
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.origin, kQueueOriginDirect);
      expect(isDirectOriginTask(row), isTrue);
      expect(row.state, QueueTaskState.completed.name);
      expect(row.outcome, contains('1 captured'));
      expect(
        row.startedAt,
        isNotNull,
        reason: 'it ran; it never merely waited',
      );
      // History, never a plan: nothing here can be released by the pump.
      expect(await queue.queuedCaptures(), isEmpty);
    });

    test('a failed direct run is reported as failed, with its error', () async {
      final queue = makeQueue();
      await queue.startDirectCapture(startUrl: url(350), chapterLimit: 1);
      await job.finish(
        stored: 0,
        state: CaptureState.failed,
        error: 'insufficientStorage',
      );
      await settle();

      final row = (await db.watchQueueTasks().first).single;
      expect(row.state, QueueTaskState.failed.name);
      expect(row.lastError, 'insufficientStorage');
    });
  });

  group('the pending queue is left alone', () {
    test('queued chapters stay queued, in order, while one runs now', () async {
      final queue = makeQueue();
      await queueThree(queue);
      await settle();
      expect(executed, isEmpty, reason: 'queued work waits for Start (D46)');

      await queue.startDirectCapture(startUrl: url(350), chapterLimit: 1);
      await settle();

      final waiting = await queue.queuedCaptures()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      expect(waiting.map((t) => t.startUrl), [url(200), url(201), url(202)]);
      expect(job.started, [url(350)]);
      expect(executed, isEmpty);
    });

    test('finishing a direct capture does not release the queue', () async {
      final queue = makeQueue();
      await queueThree(queue);
      await queue.startDirectCapture(startUrl: url(350), chapterLimit: 1);
      await job.finish(stored: 1);
      await settle();
      await settle();

      expect(
        executed,
        isEmpty,
        reason: 'the batch still waits for its own Start',
      );
      expect(queue.captureStartAuthorised, isFalse);
      expect(await queue.queuedCaptures(), hasLength(3));
    });

    test('an explicitly started batch survives a direct capture', () async {
      final queue = makeQueue();
      await queueThree(queue);
      await queue.startQueuedCaptures();
      await settle();

      // The batch ran because the user started it — that is the one thing a
      // direct capture must not undo.
      expect(executed, [url(200), url(201), url(202)]);

      await queue.startDirectCapture(startUrl: url(350), chapterLimit: 1);
      await job.finish(stored: 1);
      await settle();
      expect(job.started, [url(350)]);
    });

    test(
      'the queue pump cannot slip in while a direct start is claimed',
      () async {
        final queue = makeQueue();
        // A check drains on its own (D46) — but not into a Browser that a
        // direct capture has already claimed.
        await db.upsertLibraryItem(
          LibraryItem(
            lifecycle: 'active',
            id: 'series-1',
            title: 'Foo',
            sourceUrl: 'https://x.example/manga/foo',
            host: 'x.example',
            seriesKey: '/manga/foo',
            createdAt: DateTime(2026, 7, 1),
          ),
        );
        await queue.startDirectCapture(startUrl: url(350), chapterLimit: 1);
        await queue.enqueueSeriesCheck('series-1');
        await settle();

        expect(executed, isEmpty, reason: 'the check waits its turn');
        expect(queue.directCaptureRunning, isTrue);

        await job.finish(stored: 1);
        await settle();
        expect(executed, ['check:series-1'], reason: 'and then it runs');
      },
    );
  });

  group('Browser ownership', () {
    test('a second direct start is refused while one is running', () async {
      final queue = makeQueue();
      await queue.startDirectCapture(startUrl: url(350), chapterLimit: 1);
      await settle();

      final second = await queue.startDirectCapture(
        startUrl: url(351),
        chapterLimit: 1,
      );
      expect(second, DirectStartResult.browserBusy);
      expect(job.started, [url(350)], reason: 'the first one is untouched');
      expect(await db.pendingQueueTasks(), isEmpty, reason: 'and none queued');
    });

    test('an update check blocks a direct start and is named', () async {
      final queue = makeQueue();
      browser.automationOwner = 'an update check';
      checker.running = true;

      expect(queue.browserOwner?.label, contains('update check'));
      expect(
        await queue.startDirectCapture(startUrl: url(350), chapterLimit: 1),
        DirectStartResult.browserBusy,
      );

      checker.running = false;
      browser.automationOwner = null;
      expect(queue.browserOwner, isNull);
    });

    test(
      'a download-only phase is named as such, not as "using the Browser"',
      () async {
        final queue = makeQueue();
        job.debugSetRunning(true);
        job.debugSetProgress(
          const CaptureProgress(
            state: CaptureState.downloading,
            currentUrl: 'https://x.example/manga/foo/350',
          ),
        );

        final owner = queue.browserOwner!;
        expect(
          owner.needsBrowser,
          isFalse,
          reason: 'downloads need no surface',
        );
        expect(owner.label, contains('downloads'));
        // Queueing is unaffected: it starts nothing, so it cannot conflict.
        final queued = await queue.enqueueCapture(
          startUrl: url(400),
          chapterLimit: 1,
        );
        expect(queued.alreadyQueued, isFalse);
        expect(await queue.queuedCaptures(), hasLength(1));
        job.debugSetRunning(false);
      },
    );
  });

  group('recovery', () {
    test('an interrupted direct capture is recorded as direct', () async {
      final queue = makeQueue();
      await queue.startDirectCapture(
        startUrl: url(350),
        chapterLimit: 3,
        range: CaptureRangeMode.fixedCount,
      );
      await settle();
      await job.persistInterrupted(url(351));

      final row = await db.findResumableJob();
      expect(row, isNotNull);
      expect(row!.origin, CaptureOrigin.direct.name);
      expect(captureOriginFromName(row.origin), CaptureOrigin.direct);
    });

    test('resuming stays direct and never enters the pending queue', () async {
      final queue = makeQueue();
      await queueThree(queue);
      await db.upsertJob(
        CaptureJob(
          id: 'job-1',
          startUrl: url(350),
          currentUrl: url(351),
          requestedChapters: 3,
          completedChapters: 1,
          state: CaptureState.scrolling.name,
          visitedUrls: url(350),
          rangeMode: CaptureRangeMode.fixedCount.name,
          origin: CaptureOrigin.direct.name,
          createdAt: DateTime(2026, 7, 28),
          updatedAt: DateTime(2026, 7, 28),
        ),
      );
      final resumable = (await db.findResumableJob())!;

      final result = await queue.resumeInterruptedCapture(resumable);
      await settle();

      expect(result, DirectStartResult.started);
      expect(job.resumed, ['job-1']);
      expect(job.origin, CaptureOrigin.direct);
      expect(
        (await queue.queuedCaptures()).map((t) => t.startUrl),
        [url(200), url(201), url(202)],
        reason: 'the pending queue is untouched by a recovery',
      );
      expect(executed, isEmpty);
    });

    test('a legacy job with no origin reads as queue work', () {
      expect(captureOriginFromName(null), CaptureOrigin.queue);
    });
  });

  group('preflight sees an active direct job', () {
    test('a running direct capture owns its chapter', () async {
      final queue = makeQueue();
      await queue.startDirectCapture(startUrl: url(350), chapterLimit: 1);
      await settle();
      await job.persistInterrupted(url(350));

      final preflight = CapturePreflight(db: db, fileStore: FileStore(root));
      final result = await preflight.inspect(url(350));
      expect(result.state, ChapterLocalState.inActiveJob);
      expect(result.blockingJob?.origin, CaptureOrigin.direct.name);
    });
  });
}

/// An update checker whose "is it running" answer the test owns.
class _FakeChecker extends UpdateChecker {
  _FakeChecker({required super.browser, required super.db});

  bool running = false;

  @override
  bool get isRunning => running;
}

/// A capture job that can be started and finished on command.
///
/// The real loop needs fixture pages and a WebView; what these tests are about
/// is the *launch*: who started it, what it did to the queue, and what it left
/// behind. Everything below the launch is exercised by the capture suites.
class _ScriptedJob extends CaptureJobController {
  _ScriptedJob({
    required super.browser,
    required super.db,
    required super.fileStore,
  }) : super(config: const CaptureConfig());

  final List<String> started = [];
  final List<String> resumed = [];
  Completer<void>? _gate;
  String? _jobRowId;

  @override
  Future<void> start({
    required int chapterLimit,
    String? startUrl,
    DuplicatePolicy policy = DuplicatePolicy.skipComplete,
    SessionDuplicateDecision sessionDuplicate = SessionDuplicateDecision.ask,
    SessionPartialDecision sessionPartial = SessionPartialDecision.ask,
    CaptureRangeMode range = CaptureRangeMode.fixedCount,
    CaptureOrigin origin = CaptureOrigin.direct,
  }) async {
    started.add(startUrl ?? browser.currentUrl);
    this.origin = origin;
    rangeMode = range;
    duplicatePolicy = policy;
    debugSetRunning(true);
    debugSetProgress(
      CaptureProgress(
        state: CaptureState.inspecting,
        currentUrl: startUrl ?? '',
        requestedChapters: chapterLimit,
        chapterIndex: 1,
      ),
    );
    browser.automationOwner = 'a capture job';
    _gate = Completer<void>();
    await _gate!.future;
    browser.automationOwner = null;
    debugSetRunning(false);
    notifyListeners();
  }

  @override
  Future<void> resumeJob(CaptureJob job) async {
    resumed.add(job.id);
    await start(
      chapterLimit: job.requestedChapters - job.completedChapters,
      startUrl: job.currentUrl ?? job.startUrl,
      range: captureRangeModeFromName(job.rangeMode),
      origin: captureOriginFromName(job.origin),
    );
  }

  /// Persist the row an interrupted run would leave behind.
  Future<void> persistInterrupted(String currentUrl) async {
    debugSetProgress(
      progress.copyWith(state: CaptureState.scrolling, currentUrl: currentUrl),
    );
    await debugPersist();
    _jobRowId = jobId;
  }

  Future<void> finish({
    required int stored,
    CaptureState state = CaptureState.complete,
    String? error,
  }) async {
    debugSetProgress(
      progress.copyWith(
        state: state,
        storedChapters: stored,
        lastError: error,
        message: '$stored captured',
      ),
    );
    if (_jobRowId != null) await db.deleteJob(_jobRowId!);
    _gate?.complete();
    _gate = null;
    await Future<void>.delayed(Duration.zero);
  }
}

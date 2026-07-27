import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/library/update_checker.dart';
import 'package:web_reader/queue/task_queue.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

import 'helpers/fake_browser.dart';

/// The M14 scheduler, tested with fake runners: ordering, one-at-a-time
/// serialization, restart semantics (offer, never auto-run), cancel/retry,
/// bounded history, and the clear-history-keeps-content contract.
void main() {
  late AppDatabase db;
  late FakeBrowser browser;
  late Directory root;

  /// Every executed task id, in execution order.
  late List<String> executed;

  /// Per-task gates so tests can hold a task "running".
  final gates = <String, Completer<QueueOutcome>>{};

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    browser = FakeBrowser();
    root = Directory.systemTemp.createTempSync('webread_queue');
    executed = [];
    gates.clear();
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  TaskQueueController makeQueue({int historyLimit = 50}) {
    Future<QueueOutcome> run(QueueTask task) {
      executed.add(task.id);
      final gate = gates[task.id];
      return gate?.future ?? Future.value(const QueueOutcome.success('done'));
    }

    return TaskQueueController(
      db: db,
      browser: browser,
      captureJob: CaptureJobController(
        browser: browser,
        db: db,
        fileStore: FileStore(root),
      ),
      checker: UpdateChecker(browser: browser, db: db),
      historyLimit: historyLimit,
      captureRunner: run,
      checkRunner: run,
    );
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 120));

  test('tasks run in FIFO order, one at a time', () async {
    final queue = makeQueue();

    final idA = await queue.enqueueSeriesCheck('series-a');
    final idB = await queue.enqueueSeriesCheck('series-b');
    final idC = await queue.enqueueCapture(
      startUrl: 'https://x.example/manga/foo/1',
      chapterLimit: 3,
    );
    await settle();

    expect(executed, [idA, idB, idC], reason: 'strict FIFO');
    final rows = await db.watchQueueTasks().first;
    expect(
      rows.map((t) => t.state).toSet(),
      {'completed'},
      reason: 'everything ran to completion, exactly once each',
    );
  });

  test(
    'only one task runs at a time — the second waits for the gate',
    () async {
      final queue = makeQueue();
      final gate = Completer<QueueOutcome>();

      // Pre-insert a gated task directly so the gate exists before the pump.
      final held = QueueTask(
        id: 'held',
        taskType: 'seriesCheck',
        libraryItemId: 's1',
        state: 'queued',
        orderIndex: 1,
        queuedAt: DateTime(2026, 7, 27),
      );
      gates['held'] = gate;
      await db.upsertQueueTask(held);

      queue.resumeQueue(); // starts the pump (returns immediately)
      await settle();
      final idB = await queue.enqueueSeriesCheck('s2');
      await settle();

      expect(executed, ['held'], reason: 'B must not start while A holds');
      expect(queue.runningTaskId, 'held');

      gate.complete(const QueueOutcome.success('ok'));
      await settle();
      expect(executed, ['held', idB]);
      expect(queue.runningTaskId, isNull);
    },
  );

  test('restart offers the queue and never auto-runs it', () async {
    // What a killed app leaves behind: one running, one queued.
    await db.upsertQueueTask(
      QueueTask(
        id: 'was-running',
        taskType: 'seriesCheck',
        libraryItemId: 's1',
        state: 'running',
        orderIndex: 1,
        queuedAt: DateTime(2026, 7, 27),
        startedAt: DateTime(2026, 7, 27, 10),
      ),
    );
    await db.upsertQueueTask(
      QueueTask(
        id: 'was-queued',
        taskType: 'seriesCheck',
        libraryItemId: 's2',
        state: 'queued',
        orderIndex: 2,
        queuedAt: DateTime(2026, 7, 27),
      ),
    );

    final queue = makeQueue();
    await queue.restore();
    await settle();

    expect(queue.resumeOffered, isTrue);
    expect(executed, isEmpty, reason: 'nothing runs until the user says so');
    expect(
      (await db.queueTaskById('was-running'))!.state,
      'queued',
      reason: 'a kill mid-run demotes to queued — it never pretends it ran',
    );

    queue.resumeQueue();
    await settle();
    expect(executed, ['was-running', 'was-queued']);
    expect(queue.resumeOffered, isFalse);
  });

  test('cancelling a queued task ends it without running it', () async {
    final queue = makeQueue();
    final gate = Completer<QueueOutcome>();
    gates['held'] = gate;
    await db.upsertQueueTask(
      QueueTask(
        id: 'held',
        taskType: 'seriesCheck',
        libraryItemId: 's1',
        state: 'queued',
        orderIndex: 1,
        queuedAt: DateTime(2026, 7, 27),
      ),
    );
    queue.resumeQueue();
    await settle();
    final idB = await queue.enqueueSeriesCheck('s2');
    await settle();

    await queue.cancelTask(idB); // still queued behind the gate
    gate.complete(const QueueOutcome.success('ok'));
    await settle();

    expect(executed, ['held'], reason: 'the cancelled task never ran');
    expect((await db.queueTaskById(idB))!.state, 'cancelled');
  });

  test('retry clones a terminal task to the back of the queue', () async {
    final queue = makeQueue();
    final id = await queue.enqueueSeriesCheck('s1');
    await settle();
    expect((await db.queueTaskById(id))!.state, 'completed');

    final retryId = await queue.retryTask(id);
    await settle();

    expect(retryId, isNotNull);
    expect(retryId, isNot(id), reason: 'a fresh entry, not a resurrection');
    expect((await db.queueTaskById(retryId!))!.state, 'completed');
    expect(executed, [id, retryId]);

    // Retrying a non-terminal task is refused.
    expect(await queue.retryTask('nonsense'), isNull);
  });

  test('history is bounded', () async {
    final queue = makeQueue(historyLimit: 3);
    for (var i = 0; i < 6; i++) {
      await queue.enqueueSeriesCheck('s$i');
      await settle();
    }

    final rows = await db.watchQueueTasks().first;
    expect(
      rows.length,
      3,
      reason: 'terminal entries beyond the cap are pruned',
    );
  });

  test('clearing history never touches captured content', () async {
    // A real captured chapter with real bytes on disk.
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
    await db.upsertChapter(
      Chapter(
        id: 'c1',
        libraryItemId: 'series-1',
        title: 'Foo 1',
        sourceUrl: 'https://x.example/manga/foo/1',
        urlKey: 'https://x.example/manga/foo/1',
        captureStatus: 'complete',
        contentPath: 'library/series-1/chapters/c1',
        detectedImageCount: 1,
        storedImageCount: 1,
        sequence: 1,
        byteSize: 4,
        readStatus: 'completed',
        progressFraction: 1,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
      ),
    );
    final file = File(
      p.join(root.path, 'library/series-1/chapters/c1/assets/001.png'),
    )..createSync(recursive: true);
    file.writeAsBytesSync([1, 2, 3, 4]);

    final queue = makeQueue();
    await queue.enqueueSeriesCheck('series-1');
    await settle();

    await queue.clearHistory();

    expect(await db.watchQueueTasks().first, isEmpty, reason: 'history gone');
    final chapter = (await db.chapterById('c1'))!;
    expect(chapter.captureStatus, 'complete');
    expect(chapter.readStatus, 'completed', reason: 'reading state intact');
    expect(file.existsSync(), isTrue, reason: 'bytes untouched');
  });

  test('the pump defers while something else owns the browser', () async {
    final queue = makeQueue();
    browser.automationOwner = 'a capture job';

    await queue.enqueueSeriesCheck('s1');
    await settle();
    expect(executed, isEmpty, reason: 'one WebView, one driver');

    browser.automationOwner = null;
    queue.resumeQueue();
    await settle();
    expect(executed, hasLength(1));
  });

  test('queued work drains when the direct owner finishes (M14)', () async {
    // A directly-started run (resumed job, manual check) owns the browser;
    // work enqueued meanwhile must start when that run ends — signalled by
    // the owning controller's end-of-run notification, not by the next
    // enqueue.
    final queue = makeQueue();
    browser.automationOwner = 'a capture job';

    await queue.enqueueSeriesCheck('s1');
    await settle();
    expect(executed, isEmpty);

    browser.automationOwner = null;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    queue.captureJob.notifyListeners(); // what a finishing run does last
    await settle();

    expect(executed, hasLength(1), reason: 'no enqueue needed to unstick');
  });

  test('a second check for the same series does not stack (M14)', () async {
    final queue = makeQueue();
    browser.automationOwner = 'blocked'; // hold everything queued

    final first = await queue.enqueueSeriesCheck('s1');
    final dup = await queue.enqueueSeriesCheck('s1');
    final other = await queue.enqueueSeriesCheck('s2');
    await settle();

    expect(dup, first, reason: 'idempotent per series while pending');
    expect(other, isNot(first));
    final rows = await db.watchQueueTasks().first;
    expect(rows.where((t) => t.libraryItemId == 's1'), hasLength(1));
  });

  group('check all series (M15)', () {
    Future<void> seedSeries(String id) => db.upsertLibraryItem(
      LibraryItem(
        lifecycle: 'active',
        id: id,
        title: 'Series $id',
        sourceUrl: 'https://x.example/manga/$id',
        host: 'x.example',
        seriesKey: '/manga/$id',
        createdAt: DateTime(2026, 7, 1),
      ),
    );

    test('expands to one sequential check per series', () async {
      await seedSeries('s1');
      await seedSeries('s2');
      await seedSeries('s3');
      final queue = makeQueue();

      final ids = await queue.enqueueCheckAll();
      await settle();

      expect(ids, hasLength(3));
      expect(executed, ids, reason: 'sequential, FIFO, one WebView owner');
      final rows = await db.watchQueueTasks().first;
      expect(
        rows.map((t) => t.taskType).toSet(),
        {QueueTaskType.seriesCheck.name},
        reason: 'per-series rows, not one opaque mega-task',
      );
    });

    test('one failing series does not stop the rest', () async {
      await seedSeries('s1');
      await seedSeries('s2');
      await seedSeries('s3');
      final queue = makeQueue();

      // Fail the middle series only.
      final failing = Completer<QueueOutcome>()
        ..complete(const QueueOutcome.failure('host unreachable'));
      final all = await db.allLibraryItems();
      // Ids are minted at enqueue; gate by observing execution instead:
      // the runner consults `gates` by task id, so pre-wire after enqueue.
      browser.automationOwner = 'hold';
      final ids = await queue.enqueueCheckAll();
      gates[ids[1]] = failing;
      browser.automationOwner = null;
      queue.resumeQueue();
      await settle();

      expect(executed, ids, reason: 'the failure did not break the chain');
      final rows = await db.watchQueueTasks().first;
      final failed = rows.where((t) => t.state == 'failed').toList();
      expect(failed, hasLength(1));
      expect(failed.single.lastError, contains('host unreachable'));
      expect(rows.where((t) => t.state == 'completed'), hasLength(2));
      expect(all, hasLength(3));
    });

    test(
      'cancelQueuedChecks drops the waiting rows, not the running one',
      () async {
        await seedSeries('s1');
        await seedSeries('s2');
        await seedSeries('s3');
        final queue = makeQueue();

        browser.automationOwner = 'hold';
        final ids = await queue.enqueueCheckAll();
        // Let the first start and stay running behind a gate.
        gates[ids[0]] = Completer<QueueOutcome>();
        browser.automationOwner = null;
        queue.resumeQueue();
        await settle();
        expect(executed, [ids[0]], reason: 'first is in flight');

        final dropped = await queue.cancelQueuedChecks();
        expect(dropped, 2);

        gates[ids[0]]!.complete(const QueueOutcome.success('up to date'));
        await settle();

        final rows = await db.watchQueueTasks().first;
        expect(
          rows.firstWhere((t) => t.id == ids[0]).state,
          'completed',
          reason: 'the in-flight check finished normally',
        );
        expect(
          rows.where((t) => t.state == 'cancelled').map((t) => t.id).toSet(),
          {ids[1], ids[2]},
        );
        expect(executed, [ids[0]], reason: 'cancelled rows never ran');
      },
    );

    test('kill mid-run leaves the remainder as a restart offer', () async {
      await seedSeries('s1');
      await seedSeries('s2');
      await seedSeries('s3');
      final queue = makeQueue();

      browser.automationOwner = 'hold';
      final ids = await queue.enqueueCheckAll();
      gates[ids[0]] = Completer<QueueOutcome>(); // never completes = "killed"
      browser.automationOwner = null;
      queue.resumeQueue();
      await settle();

      // A new controller over the same database = the relaunched app.
      final relaunched = makeQueue();
      await relaunched.restore();

      expect(relaunched.resumeOffered, isTrue);
      final rows = await db.watchQueueTasks().first;
      expect(
        rows.where((t) => t.state == 'queued'),
        hasLength(3),
        reason: 'the killed running row demoted to queued, remainder intact',
      );
      expect(executed, [ids[0]], reason: 'nothing auto-ran on relaunch');
    });
  });
}

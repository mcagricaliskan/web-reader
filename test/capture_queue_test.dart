import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_preflight.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/library/update_checker.dart';
import 'package:web_reader/queue/task_queue.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

import 'helpers/fake_browser.dart';

/// Queueing a capture does not start it (D46), and starting one navigates to
/// the Browser before it touches a WebView (D47).
void main() {
  late AppDatabase db;
  late FakeBrowser browser;
  late Directory root;
  late List<String> executed;

  /// How many times the queue asked for the Browser, and what it was told.
  late List<String> browserAsks;
  late bool browserAvailable;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    browser = FakeBrowser();
    root = Directory.systemTemp.createTempSync('webread_capture_queue');
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
      captureJob: CaptureJobController(
        browser: browser,
        db: db,
        fileStore: FileStore(root),
      ),
      checker: UpdateChecker(browser: browser, db: db),
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

  Future<void> seedSeries() => db.upsertLibraryItem(
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

  Future<Chapter> seedChapter(
    double number, {
    bool offline = false,
    String? sourceUrl,
    String readStatus = 'unread',
    double progress = 0,
  }) async {
    final src = sourceUrl ?? url(number.round());
    final id = 'c$number';
    await db.upsertChapter(
      Chapter(
        id: id,
        libraryItemId: 'series-1',
        title: 'Chapter $number',
        sourceUrl: src,
        urlKey: '$src#$id',
        captureStatus: offline ? 'complete' : 'complete',
        contentPath: offline ? 'library/series-1/chapters/$id' : null,
        capturedAt: DateTime(2026, 7, 20),
        detectedImageCount: 3,
        storedImageCount: offline ? 3 : 0,
        sequence: number.round(),
        byteSize: offline ? 2048 : 0,
        chapterNumber: number,
        chapterLabel: 'Chapter $number',
        readStatus: readStatus,
        progressFraction: progress,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
        offlineRemovedAt: offline ? null : DateTime(2026, 7, 26),
      ),
    );
    return (await db.chapterById(id))!;
  }

  group('queueing does not start', () {
    test('a capture request waits, and touches no browser', () async {
      final queue = makeQueue();

      final result = await queue.enqueueCapture(
        startUrl: url(1),
        chapterLimit: 1,
      );
      await settle();

      expect(result.alreadyQueued, isFalse);
      expect(executed, isEmpty, reason: 'nothing ran');
      expect(browserAsks, isEmpty, reason: 'and nothing asked for the Browser');
      expect(browser.automationOwner, isNull);

      final waiting = await queue.queuedCaptures();
      expect(waiting.single.state, QueueTaskState.queued.name);
      expect(queue.captureStartAuthorised, isFalse);
    });

    test('the queued row survives a restart, still unstarted', () async {
      final first = makeQueue();
      await first.enqueueCapture(startUrl: url(1), chapterLimit: 1);
      await settle();

      // A new controller over the same database is what a relaunch looks
      // like from the queue's point of view.
      final second = makeQueue();
      await second.restore();
      await settle();

      expect(executed, isEmpty, reason: 'a restart never resumes capture');
      expect((await second.queuedCaptures()), hasLength(1));
      expect(second.captureStartAuthorised, isFalse);
    });

    test('a kill mid-capture demotes the row rather than losing it', () async {
      final queue = makeQueue();
      final result = await queue.enqueueCapture(
        startUrl: url(1),
        chapterLimit: 1,
      );
      await db.upsertQueueTask(
        (await db.queueTaskById(result.id))!.copyWith(state: 'running'),
      );

      final restarted = makeQueue();
      await restarted.restore();

      expect((await restarted.queuedCaptures()), hasLength(1));
      expect(executed, isEmpty);
    });

    test('checks and cleanup still drain without a start', () async {
      final queue = makeQueue();
      await queue.enqueueSeriesCheck('series-1');
      await settle();

      expect(executed, ['check:series-1']);
    });

    test('a queued capture does not block a check behind it', () async {
      final queue = makeQueue();
      await queue.enqueueCapture(startUrl: url(1), chapterLimit: 1);
      await queue.enqueueSeriesCheck('series-1');
      await settle();

      expect(executed, [
        'check:series-1',
      ], reason: 'the unstarted capture is skipped, not a roadblock');
    });
  });

  group('explicit start', () {
    test('start releases the queue and asks for the Browser first', () async {
      final queue = makeQueue();
      await queue.enqueueCapture(startUrl: url(1), chapterLimit: 1);

      final released = await queue.startQueuedCaptures();
      await settle();

      expect(released, 1);
      expect(browserAsks, hasLength(1));
      expect(executed, [url(1)]);
    });

    test('nothing starts when the Browser cannot be shown', () async {
      browserAvailable = false;
      final queue = makeQueue();
      await queue.enqueueCapture(startUrl: url(1), chapterLimit: 1);

      await queue.startQueuedCaptures();
      await settle();

      expect(browserAsks, hasLength(1));
      expect(
        executed,
        isEmpty,
        reason: 'automation must never begin behind another screen (D47)',
      );
      expect(
        (await queue.queuedCaptures()),
        hasLength(1),
        reason: 'the work stays queued for the next attempt',
      );
    });

    test('tasks process sequentially, in queue order', () async {
      final queue = makeQueue();
      await queue.enqueueCapture(startUrl: url(1), chapterLimit: 1);
      await queue.enqueueCapture(startUrl: url(2), chapterLimit: 1);
      await queue.enqueueCapture(startUrl: url(3), chapterLimit: 1);

      await queue.startQueuedCaptures();
      await settle();

      expect(executed, [url(1), url(2), url(3)]);
      expect(browserAsks, hasLength(3), reason: 'one gate per task');
    });

    test('a drained queue revokes its own authorisation', () async {
      final queue = makeQueue();
      await queue.enqueueCapture(startUrl: url(1), chapterLimit: 1);
      await queue.startQueuedCaptures();
      await settle();
      expect(queue.captureStartAuthorised, isFalse);

      // Adding more is a new decision, and waits again.
      await queue.enqueueCapture(startUrl: url(2), chapterLimit: 1);
      await settle();
      expect(executed, [url(1)]);
    });

    test('one failure does not discard the rest of the batch', () async {
      final queue = TaskQueueController(
        db: db,
        browser: browser,
        captureJob: CaptureJobController(
          browser: browser,
          db: db,
          fileStore: FileStore(root),
        ),
        checker: UpdateChecker(browser: browser, db: db),
        captureRunner: (task) async {
          executed.add(task.startUrl!);
          return task.startUrl == url(2)
              ? const QueueOutcome.failure('boom')
              : const QueueOutcome.success('captured');
        },
      );
      for (final n in [1, 2, 3]) {
        await queue.enqueueCapture(startUrl: url(n), chapterLimit: 1);
      }

      await queue.startQueuedCaptures();
      await settle();

      expect(executed, [url(1), url(2), url(3)]);
      final rows = await db.watchQueueTasks().first;
      expect(rows.where((t) => t.state == 'failed'), hasLength(1));
      expect(rows.where((t) => t.state == 'completed'), hasLength(2));
    });

    test('stopping keeps the remainder queued, not cancelled', () async {
      final queue = makeQueue();
      await queue.enqueueCapture(startUrl: url(1), chapterLimit: 1);
      await queue.enqueueCapture(startUrl: url(2), chapterLimit: 1);

      await queue.stopQueuedCaptures();
      await settle();

      expect(executed, isEmpty);
      expect((await queue.queuedCaptures()), hasLength(2));
    });
  });

  group('duplicate prevention', () {
    test('the same chapter is not queued twice', () async {
      final queue = makeQueue();
      final first = await queue.enqueueCapture(
        startUrl: url(1),
        chapterLimit: 1,
      );
      final second = await queue.enqueueCapture(
        startUrl: url(1),
        chapterLimit: 1,
      );

      expect(second.alreadyQueued, isTrue);
      expect(second.id, first.id);
      expect((await queue.queuedCaptures()), hasLength(1));
    });

    test('history does not block a fresh re-fetch', () async {
      final queue = makeQueue();
      final first = await queue.enqueueCapture(
        startUrl: url(1),
        chapterLimit: 1,
      );
      await queue.startQueuedCaptures();
      await settle();
      expect((await db.queueTaskById(first.id))!.state, 'completed');

      final again = await queue.enqueueCapture(
        startUrl: url(1),
        chapterLimit: 1,
      );
      expect(
        again.alreadyQueued,
        isFalse,
        reason: 'a completed run last week must not veto an intentional one',
      );
    });
  });

  group('batch re-download', () {
    test('queues ascending, whatever order the list was showing', () async {
      await seedSeries();
      final queue = makeQueue();
      final c488 = await seedChapter(488);
      final c489 = await seedChapter(489);
      final c490 = await seedChapter(490);

      // Newest-first, exactly as the episode list renders it.
      final result = await queue.enqueueChapters([c490, c489, c488]);

      expect(result.queued, 3);
      final rows = (await queue.queuedCaptures())
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      expect(rows.map((t) => t.startUrl), [url(488), url(489), url(490)]);
    });

    test('decimal chapters keep their place', () async {
      await seedSeries();
      final queue = makeQueue();
      final a = await seedChapter(385, sourceUrl: url(385));
      final b = await seedChapter(385.5, sourceUrl: 'https://x.example/385-5');
      final c = await seedChapter(386, sourceUrl: url(386));

      await queue.enqueueChapters([c, a, b]);

      final rows = (await queue.queuedCaptures())
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      expect(rows.map((t) => t.startUrl), [
        url(385),
        'https://x.example/385-5',
        url(386),
      ]);
    });

    test('chapters with no source page are reported, not dropped', () async {
      await seedSeries();
      final queue = makeQueue();
      final ok1 = await seedChapter(1);
      final ok2 = await seedChapter(2);
      final bad = await seedChapter(3, sourceUrl: '');

      final result = await queue.enqueueChapters([ok1, ok2, bad]);

      expect(result.queued, 2);
      expect(result.missingSource, hasLength(1));
      expect(result.missingSource.single.id, bad.id);
      expect(
        (await queue.queuedCaptures()),
        hasLength(2),
        reason: 'one unusable chapter must not fail the whole selection',
      );
    });

    test('already-queued chapters are counted separately', () async {
      await seedSeries();
      final queue = makeQueue();
      final a = await seedChapter(1);
      final b = await seedChapter(2);
      await queue.enqueueCapture(startUrl: url(1), chapterLimit: 1);

      final result = await queue.enqueueChapters([a, b]);

      expect(result.queued, 1);
      expect(result.alreadyQueued, hasLength(1));
      expect((await queue.queuedCaptures()), hasLength(2));
    });

    test('re-download reuses the row and its reading state', () async {
      await seedSeries();
      final queue = makeQueue();
      final chapter = await seedChapter(
        7,
        readStatus: 'completed',
        progress: 1,
      );

      await queue.enqueueChapters([chapter]);

      // The queue carries a URL, never a copy of the chapter — so there is
      // nothing for it to duplicate.
      expect(await db.chaptersForItem('series-1'), hasLength(1));
      final after = (await db.chapterById(chapter.id))!;
      expect(after.readStatus, 'completed');
      expect(after.progressFraction, 1);
      expect(after.sourceUrl, url(7));
      expect(after.chapterNumber, 7);
    });

    test(
      'a batch uses the replacing policy, so files swap atomically',
      () async {
        await seedSeries();
        final queue = makeQueue();
        final chapter = await seedChapter(1, offline: true);

        await queue.enqueueChapters([chapter]);

        final row = (await queue.queuedCaptures()).single;
        expect(row.duplicatePolicy, DuplicatePolicy.replaceAll.name);
        expect(row.rangeMode, CaptureRangeMode.currentChapter.name);
        expect(row.chapterLimit, 1);
      },
    );
  });

  group('queue management', () {
    test('reordering moves a task without touching the others', () async {
      final queue = makeQueue();
      for (final n in [1, 2, 3]) {
        await queue.enqueueCapture(startUrl: url(n), chapterLimit: 1);
      }

      final third = (await queue.queuedCaptures()).firstWhere(
        (t) => t.startUrl == url(3),
      );
      await queue.moveQueued(third.id, -1);

      final rows = (await queue.queuedCaptures())
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      expect(rows.map((t) => t.startUrl), [url(1), url(3), url(2)]);
    });

    test('moving up from the front is a no-op, not a wrap', () async {
      final queue = makeQueue();
      for (final n in [1, 2]) {
        await queue.enqueueCapture(startUrl: url(n), chapterLimit: 1);
      }
      final first = (await queue.queuedCaptures()).firstWhere(
        (t) => t.startUrl == url(1),
      );
      await queue.moveQueued(first.id, -1);

      final rows = (await queue.queuedCaptures())
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      expect(rows.map((t) => t.startUrl), [url(1), url(2)]);
    });

    test('starting one task moves it to the front', () async {
      final queue = makeQueue();
      for (final n in [1, 2, 3]) {
        await queue.enqueueCapture(startUrl: url(n), chapterLimit: 1);
      }
      final third = (await queue.queuedCaptures()).firstWhere(
        (t) => t.startUrl == url(3),
      );

      await queue.startQueuedTask(third.id);
      await settle();

      expect(executed.first, url(3));
    });

    test('clearing the queue removes plans, never content', () async {
      await seedSeries();
      final queue = makeQueue();
      final chapter = await seedChapter(1, offline: true);
      await queue.enqueueChapters([chapter]);

      final cleared = await queue.clearQueuedCaptures();

      expect(cleared, 1);
      expect(await queue.queuedCaptures(), isEmpty);
      expect(executed, isEmpty);
      // The chapter, its files and its metadata are all untouched.
      final after = (await db.chapterById(chapter.id))!;
      expect(after.contentPath, isNotNull);
      expect(after.sourceUrl, url(1));
      expect(await db.chaptersForItem('series-1'), hasLength(1));
    });

    test('the summary counts what each section shows', () async {
      final queue = makeQueue();
      await queue.enqueueCapture(startUrl: url(1), chapterLimit: 1);
      await queue.enqueueCapture(startUrl: url(2), chapterLimit: 1);
      await queue.enqueueSeriesCheck('series-1');
      await settle();

      final summary = QueueSummary.of(await db.watchQueueTasks().first);
      expect(summary.queuedCaptures, 2);
      expect(summary.completed, 1, reason: 'the check drained by itself');
      expect(summary.hasQueuedCaptures, isTrue);
    });
  });

  group('ordering helpers', () {
    test('capture order is reading order, decimal-safe', () async {
      await seedSeries();
      final list = [
        await seedChapter(386),
        await seedChapter(385),
        await seedChapter(385.5, sourceUrl: 'https://x.example/385-5'),
      ];
      expect(sortChaptersForCaptureOrder(list).map((c) => c.chapterNumber), [
        385,
        385.5,
        386,
      ]);
    });

    test('a chapter needs a real URL to be capturable', () async {
      await seedSeries();
      expect(chapterHasCapturableUrl(await seedChapter(1)), isTrue);
      expect(
        chapterHasCapturableUrl(await seedChapter(2, sourceUrl: '')),
        isFalse,
      );
      expect(
        chapterHasCapturableUrl(await seedChapter(3, sourceUrl: '/relative')),
        isFalse,
      );
    });
  });
}

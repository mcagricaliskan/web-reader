import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/features/archived_screen.dart';
import 'package:web_reader/features/library_screen.dart';
import 'package:web_reader/features/series_detail_screen.dart';
import 'package:web_reader/library/series_repository.dart';
import 'package:web_reader/library/update_checker.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/queue/task_queue.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

import 'helpers/fake_browser.dart';

/// M16: archive/restore. The contract under test: archiving changes
/// visibility and checking — never chapters, files, or reading state.
void main() {
  late AppDatabase db;
  late Directory root;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_archive');
  });
  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> seedSeries(String id, {int chapters = 2}) async {
    await db.upsertLibraryItem(
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
    for (var n = 1; n <= chapters; n++) {
      await db.upsertChapter(
        Chapter(
          id: '$id-c$n',
          libraryItemId: id,
          title: 'Series $id Chapter $n',
          sourceUrl: 'https://x.example/manga/$id/$n',
          urlKey: 'https://x.example/manga/$id/$n',
          captureStatus: 'complete',
          contentPath: 'library/$id/chapters/$id-c$n',
          capturedAt: DateTime(2026, 7, 20),
          detectedImageCount: 6,
          storedImageCount: 6,
          sequence: n,
          byteSize: 1024,
          chapterNumber: n.toDouble(),
          chapterLabel: 'Chapter $n',
          readStatus: 'unread',
          progressFraction: 0,
          progressImageIndex: 0,
          progressOffsetInImage: 0,
        ),
      );
    }
  }

  group('lifecycle column (schema v7)', () {
    test('fresh series come out active with no archived timestamp', () async {
      await seedSeries('s1');
      final item = (await db.libraryItemById('s1'))!;
      expect(item.lifecycle, 'active');
      expect(item.archivedAt, isNull);
    });

    test('archive/restore round-trip touches only lifecycle fields', () async {
      await seedSeries('s1');
      final repo = SeriesRepository(db);
      final before = (await db.libraryItemById('s1'))!;

      await repo.archive('s1');
      final archived = (await db.libraryItemById('s1'))!;
      expect(archived.lifecycle, 'archived');
      expect(archived.archivedAt, isNotNull);
      expect(
        await db.chaptersForItem('s1'),
        hasLength(2),
        reason: 'chapters untouched',
      );

      await repo.restore('s1');
      final restored = (await db.libraryItemById('s1'))!;
      expect(restored.lifecycle, 'active');
      expect(restored.archivedAt, isNull, reason: 'timestamp cleared');
      expect(restored.title, before.title);
      expect(restored.seriesKey, before.seriesKey);
      final chapters = await db.chaptersForItem('s1');
      expect(chapters.map((c) => c.readStatus).toSet(), {'unread'});
      expect(chapters.map((c) => c.contentPath), everyElement(isNotNull));
    });
  });

  group('queue integration', () {
    late FakeBrowser browser;
    late List<String> executed;

    setUp(() {
      browser = FakeBrowser();
      executed = [];
    });

    TaskQueueController makeQueue() => TaskQueueController(
      db: db,
      browser: browser,
      captureJob: CaptureJobController(
        browser: browser,
        db: db,
        fileStore: FileStore(root),
      ),
      checker: UpdateChecker(browser: browser, db: db),
      captureRunner: (t) async {
        executed.add(t.id);
        return const QueueOutcome.success('done');
      },
      checkRunner: (t) async {
        executed.add(t.id);
        return const QueueOutcome.success('done');
      },
    );

    test('check-all skips archived series', () async {
      await seedSeries('active-1');
      await seedSeries('active-2');
      await seedSeries('sleeping');
      await SeriesRepository(db).archive('sleeping');
      final queue = makeQueue();

      final ids = await queue.enqueueCheckAll();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(ids, hasLength(2), reason: 'archived series not checked');
      final rows = await db.watchQueueTasks().first;
      expect(rows.map((t) => t.libraryItemId).toSet(), {
        'active-1',
        'active-2',
      });
    });

    test('archiving cancels the series’ pending tasks (Q25)', () async {
      await seedSeries('s1');
      await seedSeries('s2');
      final queue = makeQueue();

      browser.automationOwner = 'hold'; // keep everything queued
      await queue.enqueueSeriesCheck('s1');
      await queue.enqueueSeriesCheck('s2');
      expect(await queue.pendingTasksForSeries('s1'), hasLength(1));

      final cancelled = await queue.cancelTasksForSeries('s1');
      await SeriesRepository(db).archive('s1');

      expect(cancelled, 1);
      final rows = await db.watchQueueTasks().first;
      expect(
        rows.firstWhere((t) => t.libraryItemId == 's1').state,
        'cancelled',
      );
      expect(
        rows.firstWhere((t) => t.libraryItemId == 's2').state,
        'queued',
        reason: 'the other series’ work is untouched',
      );
    });
  });

  group('screens', () {
    Widget harness(Widget child) {
      final browser = BrowserController();
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          updateCheckerProvider.overrideWithValue(
            UpdateChecker(browser: browser, db: db),
          ),
          captureJobProvider.overrideWithValue(
            CaptureJobController(
              browser: browser,
              db: db,
              fileStore: FileStore(root),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(path: '/', builder: (_, _) => child),
              GoRoute(
                path: '/series/:id',
                builder: (_, state) =>
                    SeriesDetailScreen(seriesId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: '/archived',
                builder: (_, _) => const ArchivedScreen(),
              ),
              GoRoute(path: '/reader/:id', builder: (_, _) => const SizedBox()),
              GoRoute(path: '/rules', builder: (_, _) => const SizedBox()),
            ],
          ),
        ),
      );
    }

    Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('timed out waiting for $finder');
    }

    Future<void> settleDown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('an archived series leaves the library list', (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await seedSeries('s1');
      await seedSeries('s2');
      await SeriesRepository(db).archive('s2');

      await tester.pumpWidget(harness(const LibraryScreen()));
      await pumpUntil(tester, find.text('Series s1'));

      expect(find.text('Series s1'), findsWidgets);
      expect(find.text('Series s2'), findsNothing);
      await settleDown(tester);
    });

    testWidgets('the Archived screen lists and restores', (tester) async {
      await seedSeries('s1');
      await SeriesRepository(db).archive('s1');

      await tester.pumpWidget(harness(const ArchivedScreen()));
      await pumpUntil(tester, find.text('Series s1'));

      expect(find.textContaining('2 chapters offline'), findsOneWidget);
      expect(find.textContaining('archived'), findsWidgets);

      await tester.tap(find.text('Restore'));
      await pumpUntil(tester, find.text('Nothing archived'));

      expect((await db.libraryItemById('s1'))!.lifecycle, 'active');
      await settleDown(tester);
    });

    testWidgets('detail of an archived series offers restore, not checks', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await seedSeries('s1');
      await SeriesRepository(db).archive('s1');

      await tester.pumpWidget(
        harness(const SeriesDetailScreen(seriesId: 's1')),
      );
      await pumpUntil(tester, find.text('Archived'));

      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Check now'), findsNothing);
      expect(find.text('Check again'), findsNothing);

      await tester.tap(find.text('Restore'));
      await pumpUntil(tester, find.text('Check now'));

      expect((await db.libraryItemById('s1'))!.lifecycle, 'active');
      await settleDown(tester);
    });
  });
}

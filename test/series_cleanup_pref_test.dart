import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/features/series_detail_screen.dart';
import 'package:web_reader/library/update_checker.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/cleanup.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

/// Series detail › Downloaded chapters: where a series' cleanup decision is
/// changed and reset (D37). The reader asks once; this is the only other place
/// the value can move, and it moves for exactly one series.
void main() {
  late AppDatabase db;
  late Directory root;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_series_cleanup');
  });
  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> seedSeries(String id) async {
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
    await db.upsertChapter(
      Chapter(
        id: '$id-c1',
        libraryItemId: id,
        title: 'Series $id Chapter 1',
        sourceUrl: 'https://x.example/manga/$id/1',
        urlKey: 'https://x.example/manga/$id/1',
        captureStatus: 'complete',
        contentPath: 'library/$id/chapters/$id-c1',
        capturedAt: DateTime(2026, 7, 20),
        detectedImageCount: 6,
        storedImageCount: 6,
        sequence: 1,
        byteSize: 1024,
        chapterNumber: 1,
        chapterLabel: 'Chapter 1',
        readStatus: 'unread',
        progressFraction: 0,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
      ),
    );
  }

  Widget harness(String seriesId) {
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
            GoRoute(
              path: '/',
              builder: (_, _) => SeriesDetailScreen(seriesId: seriesId),
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

  final entry = find.byKey(const ValueKey('seriesCleanupPrefEntry'));

  /// Open Series actions → Downloaded chapters.
  ///
  /// Each sheet is let settle before it is tapped: a row that exists in the
  /// tree is still sliding up, and a tap at its final position misses.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Series actions'));
    await pumpUntil(tester, entry);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(entry);
    // The sheet's own option rows, not the menu row's title — that text is
    // still in the tree while the menu pops.
    await pumpUntil(
      tester,
      find.byKey(const ValueKey('seriesCleanupPref-ask')),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<SeriesCleanupPref?> prefOf(String id) async =>
      seriesCleanupFromName((await db.libraryItemById(id))!.finishedCleanup);

  Future<void> tapOption(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(ValueKey('seriesCleanupPref-$name')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('the menu row states the series decision', (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await seedSeries('s1');
    await tester.pumpWidget(harness('s1'));
    await pumpUntil(tester, find.text('Series s1'));

    await tester.tap(find.byTooltip('Series actions'));
    await pumpUntil(tester, entry);
    expect(
      find.text('Not set · asked when you finish a chapter'),
      findsOneWidget,
    );
    await settleDown(tester);
  });

  testWidgets('choosing an option writes it to this series only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await seedSeries('s1');
    await seedSeries('s2');
    await tester.pumpWidget(harness('s1'));
    await pumpUntil(tester, find.text('Series s1'));
    await openSheet(tester);

    await tapOption(tester, 'keep');
    expect(await prefOf('s1'), SeriesCleanupPref.keep);
    expect(
      await prefOf('s2'),
      isNull,
      reason: 'the sheet writes to the series it was opened from',
    );

    await tapOption(tester, 'remove');
    expect(await prefOf('s1'), SeriesCleanupPref.remove);
    expect(await prefOf('s2'), isNull);
    await settleDown(tester);
  });

  testWidgets('Ask again next time clears the stored decision', (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await seedSeries('s1');
    await seedSeries('s2');
    await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.remove.name);
    await db.setSeriesFinishedCleanup('s2', SeriesCleanupPref.remove.name);

    await tester.pumpWidget(harness('s1'));
    await pumpUntil(tester, find.text('Series s1'));
    await openSheet(tester);

    expect(
      find.text('Ask again next time'),
      findsOneWidget,
      reason:
          'the reset is offered by name — there is no global to fall back '
          'to',
    );
    expect(find.textContaining('global'), findsNothing);

    await tapOption(tester, 'ask');
    expect(await prefOf('s1'), isNull);
    expect(
      await prefOf('s2'),
      SeriesCleanupPref.remove,
      reason: 'resetting one series leaves every other one alone',
    );
    await settleDown(tester);
  });

  testWidgets('the sheet never touches files', (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await seedSeries('s1');
    await tester.pumpWidget(harness('s1'));
    await pumpUntil(tester, find.text('Series s1'));
    await openSheet(tester);
    await tapOption(tester, 'remove');

    final chapter = (await db.chapterById('s1-c1'))!;
    expect(chapter.contentPath, isNotNull);
    expect(chapter.offlineRemovedAt, isNull);
    await settleDown(tester);
  });
}

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/features/reader_screen.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/storage/manifest.dart';

import '../tool/fixture/fixture_site.dart';

/// The reader against real files: restore-at-open, lifecycle flushes, the
/// no-false-completion rule, and manifest dimension repair on open.
///
/// iOS gives no callback on a hard force-quit, so the design under test is:
/// throttled writes bound the loss, lifecycle callbacks flush when they do
/// arrive, and nothing written during termination may claim a completion the
/// dwell rule did not grant.
void main() {
  late AppDatabase db;
  late Directory root;
  late FileStore store;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_reader');
    store = FileStore(root);
    Directory(
      p.join(root.path, FileStore.libraryFolderName),
    ).createSync(recursive: true);
    Directory(
      p.join(root.path, FileStore.tmpFolderName),
    ).createSync(recursive: true);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Three real 800x1200 panels on disk; the manifest records
  /// [manifestWidth]x[manifestHeight] (defaults: the truth).
  Future<void> seedChapter({
    int manifestWidth = 800,
    int manifestHeight = 1200,
    bool verified = true,
  }) async {
    await db.upsertLibraryItem(
      LibraryItem(
        lifecycle: 'active',
        id: 'series-1',
        title: 'Fixture',
        sourceUrl: 'https://x.example/manga/foo',
        host: 'x.example',
        seriesKey: '/manga/foo',
        createdAt: DateTime(2026, 7, 1),
      ),
    );
    final staging = await store.beginChapter(
      libraryItemId: 'series-1',
      chapterId: 'c1',
    );
    final entries = <AssetEntry>[];
    for (var i = 1; i <= 3; i++) {
      await staging
          .assetFile('00$i.png')
          .writeAsBytes(panelPng(chapter: 1, index: i));
      entries.add(
        AssetEntry(
          index: i,
          sourceUrl: 'https://cdn.example/$i.png',
          status: AssetStatus.stored,
          relativePath: 'assets/00$i.png',
          width: manifestWidth,
          height: manifestHeight,
          dimensionsVerified: verified,
        ),
      );
    }
    final relative = await store.commit(
      staging,
      ChapterManifest(
        schemaVersion: 1,
        chapterId: 'c1',
        libraryItemId: 'series-1',
        sourceUrl: 'https://x.example/manga/foo/1',
        title: 'Foo Chapter 1',
        capturedAt: DateTime(2026, 7, 20),
        status: CaptureStatus.complete,
        detectedImageCount: 3,
        storedImageCount: 3,
        assets: entries,
      ),
    );
    await db.upsertChapter(
      Chapter(
        id: 'c1',
        libraryItemId: 'series-1',
        title: 'Foo Chapter 1',
        sourceUrl: 'https://x.example/manga/foo/1',
        urlKey: 'https://x.example/manga/foo/1',
        captureStatus: 'complete',
        contentPath: relative,
        capturedAt: DateTime(2026, 7, 20),
        detectedImageCount: 3,
        storedImageCount: 3,
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

  Widget harness() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      fileStoreProvider.overrideWithValue(store),
    ],
    child: const MaterialApp(home: ReaderScreen(chapterId: 'c1')),
  );

  /// Real file IO cannot complete inside the test's fake-async zone, so the
  /// load is pumped with `runAsync` windows that let the event loop turn.
  Future<void> openReader(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(ListView).evaluate().isNotEmpty) return;
    }
    fail('reader never finished loading');
  }

  ScrollPosition scrollPosition(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  testWidgets('opens at the saved anchor, not at the top', (tester) async {
    await tester.runAsync(seedChapter);
    await db.writeChapterReading(
      'c1',
      ChaptersCompanion(
        readStatus: const Value('inProgress'),
        progressFraction: const Value(0.45),
        progressImageIndex: const Value(1),
        progressOffsetInImage: const Value(0.25),
        lastReadAt: Value(DateTime(2026, 7, 26)),
        progressUpdatedAt: Value(DateTime(2026, 7, 26)),
      ),
    );

    await openReader(tester);

    // Viewport width 800, panels 800x1200 → each lays out 1200 tall.
    // Anchor: panel 1 + 25% of it = 1200 + 300, plus the lead-in that keeps
    // content out from under the top chrome.
    expect(scrollPosition(tester).pixels, closeTo(kReaderTopSpacer + 1500, 1));
  });

  testWidgets('a lifecycle change flushes without waiting for the debounce', (
    tester,
  ) async {
    await tester.runAsync(seedChapter);
    await openReader(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 50));

    // Backgrounded well inside the 2s debounce window.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 100));

    final chapter = (await db.chapterById('c1'))!;
    expect(
      chapter.progressUpdatedAt,
      isNotNull,
      reason: 'the position was written on backgrounding, not 2s later',
    );
    expect(chapter.progressFraction, greaterThan(0));
    expect(chapter.readStatus, 'inProgress');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3)); // drain the debounce timer
  });

  testWidgets('termination during a fling never fakes a completion', (
    tester,
  ) async {
    await tester.runAsync(seedChapter);
    await openReader(tester);

    // Straight to the bottom…
    scrollPosition(tester).jumpTo(scrollPosition(tester).maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 16));
    // …and killed before the dwell (800ms) elapses.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 100));

    final chapter = (await db.chapterById('c1'))!;
    expect(
      chapter.readStatus,
      isNot('completed'),
      reason: 'reaching the end for an instant is not reading the chapter',
    );
    expect(chapter.completedAt, isNull);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('staying past the threshold for the dwell completes', (
    tester,
  ) async {
    await tester.runAsync(seedChapter);
    await openReader(tester);

    final position = scrollPosition(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 16));
    // The dwell measures wall-clock time, so wait for real; then a second
    // scroll event confirms the stay.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    position.jumpTo(position.maxScrollExtent - 1);
    await tester.pump(const Duration(milliseconds: 50));

    final chapter = (await db.chapterById('c1'))!;
    expect(chapter.readStatus, 'completed');
    expect(chapter.completedAt, isNotNull);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a finished chapter re-read from the top stays at 100%', (
    tester,
  ) async {
    await tester.runAsync(seedChapter);
    await db.writeChapterReading(
      'c1',
      ChaptersCompanion(
        readStatus: const Value('completed'),
        completedAt: Value(DateTime(2026, 7, 25)),
        progressFraction: const Value(1),
        progressImageIndex: const Value(2),
        progressOffsetInImage: const Value(0.9),
      ),
    );

    await openReader(tester);

    // Back to the beginning to read it again. The scroll is real; the
    // *completion* is not undone by it.
    final position = scrollPosition(tester);
    position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(seconds: 3)); // let the debounce fire

    final chapter = (await db.chapterById('c1'))!;
    expect(chapter.readStatus, 'completed');
    expect(
      chapter.progressFraction,
      1,
      reason: 'finished means 100%, whatever the scroll says',
    );
    expect(
      chapter.progressImageIndex,
      0,
      reason: 'the anchor still follows, so resuming lands where they are',
    );
  });

  testWidgets('progress readout is live; persistence stays debounced (M12)', (
    tester,
  ) async {
    await tester.runAsync(seedChapter);
    await openReader(tester);

    // At the top: 0%, panel 1. The reader chrome shows the percentage and the
    // panel anchor as two labels at either end of the progress bar.
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('panel 1 / 3'), findsOneWidget);

    // Scroll into panel 2 and give the UI a single frame — far inside the
    // 2 s persistence debounce.
    scrollPosition(tester).jumpTo(1500);
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('panel 2 / 3'),
      findsOneWidget,
      reason: 'the anchor must move while scrolling, not after leaving',
    );
    expect(
      find.text('0%'),
      findsNothing,
      reason: 'the percentage must move while scrolling',
    );

    // …and the database has NOT been written yet: the visible state leads,
    // the persisted state follows on the debounce.
    final beforeDebounce = (await db.chapterById('c1'))!;
    expect(
      beforeDebounce.progressUpdatedAt,
      isNull,
      reason: 'DB writes stay throttled — nothing lands inside the window',
    );

    // After the debounce elapses the same value is persisted.
    await tester.pump(const Duration(seconds: 3));
    final afterDebounce = (await db.chapterById('c1'))!;
    expect(afterDebounce.progressUpdatedAt, isNotNull);
    expect(afterDebounce.progressImageIndex, 1);
  });

  testWidgets('wrong manifest dimensions are repaired from the files on open', (
    tester,
  ) async {
    // The manifest lies (square panels); the files are 800x1200.
    await tester.runAsync(
      () => seedChapter(manifestHeight: 800, verified: false),
    );
    await openReader(tester);

    // Layout must use the FILE dimensions: 3 panels x 1200, not x 800.
    expect(
      scrollPosition(tester).maxScrollExtent,
      greaterThan(2000),
      reason: 'geometry built from repaired dimensions',
    );

    final manifest = (await tester.runAsync(
      () => store.readManifest('library/series-1/chapters/c1'),
    ))!;
    for (final asset in manifest.storedAssets) {
      expect(asset.width, 800);
      expect(asset.height, 1200);
      expect(asset.dimensionsVerified, isTrue);
      expect(asset.domHeight, 800, reason: 'the old claim kept as diagnostic');
    }
    await tester.pump(const Duration(seconds: 3));
  });
}

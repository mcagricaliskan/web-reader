import 'dart:io';

import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/features/reader_screen.dart';
import 'package:web_reader/features/series_detail_screen.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/library/update_checker.dart';
import 'package:web_reader/storage/manifest.dart';

import '../tool/fixture/fixture_site.dart';

/// Swiping right in the reader goes back to the series' episode list.
///
/// The two things that make this correct rather than merely present: the
/// gesture must not fire on ordinary reading (which is vertical), and the
/// reading position must be written before the screen goes away.
void main() {
  late AppDatabase db;
  late Directory root;
  late FileStore store;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_reader_nav');
    store = FileStore(root);
    Directory(
      p.join(root.path, FileStore.libraryFolderName),
    ).createSync(recursive: true);
    Directory(p.join(root.path, FileStore.tmpFolderName)).createSync(
      recursive: true,
    );
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> seed() async {
    await db.upsertLibraryItem(
      LibraryItem(
        lifecycle: 'active',
        id: 'series-1',
        title: 'Fixture Series',
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
          width: 800,
          height: 1200,
          dimensionsVerified: true,
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

  /// The two real routes involved, so the test exercises the actual
  /// pop-or-replace decision rather than a stand-in.
  Widget harness({required String start}) {
    final router = GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(
          path: '/series/:seriesId',
          builder: (context, state) =>
              SeriesDetailScreen(seriesId: state.pathParameters['seriesId']!),
          routes: const [],
        ),
        GoRoute(
          path: '/reader/:chapterId',
          builder: (context, state) =>
              ReaderScreen(chapterId: state.pathParameters['chapterId']!),
        ),
      ],
    );
    // The episode list reaches the update checker and the capture job for its
    // own actions; both get inert instances over an unattached browser, so no
    // WebView is stood up.
    final browser = BrowserController();
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(store),
        updateCheckerProvider.overrideWithValue(
          UpdateChecker(browser: browser, db: db),
        ),
        captureJobProvider.overrideWithValue(
          CaptureJobController(browser: browser, db: db, fileStore: store),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  /// Real file IO needs the event loop to turn (`runAsync`), and route
  /// transitions need the test clock to advance (`pump(duration)`). Both.
  Future<void> settleAsync(WidgetTester tester, {int rounds = 30}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  /// Unmount inside the body, then let the disposal timers drift's stream
  /// teardown schedules actually run — the fake clock only turns while the
  /// test body is still going.
  void navTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  }

  Future<void> openReader(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(ListView).evaluate().isNotEmpty) return;
    }
    fail('reader never finished loading');
  }

  navTest('a right swipe leaves for the episode list', (tester) async {
    await tester.runAsync(seed);
    await openReader(tester, harness(start: '/reader/c1'));

    await tester.drag(find.byType(ListView), const Offset(220, 0));
    await settleAsync(tester);

    expect(find.byType(ReaderScreen), findsNothing);
    expect(find.byType(SeriesDetailScreen), findsOneWidget);
  });

  navTest('the position is written before the reader goes away', (
    tester,
  ) async {
    await tester.runAsync(seed);
    await openReader(tester, harness(start: '/reader/c1'));

    // Read a little — well inside the 2s save debounce, so nothing has been
    // persisted yet when the swipe happens.
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 50));
    expect((await db.chapterById('c1'))!.progressUpdatedAt, isNull);

    await tester.drag(find.byType(ListView), const Offset(220, 0));
    await settleAsync(tester);

    final chapter = (await db.chapterById('c1'))!;
    expect(chapter.progressUpdatedAt, isNotNull);
    expect(chapter.progressFraction, greaterThan(0));
  });

  navTest('scrolling to read never triggers it', (tester) async {
    await tester.runAsync(seed);
    await openReader(tester, harness(start: '/reader/c1'));

    // A long read scroll with the sideways wobble of a real thumb.
    await tester.drag(find.byType(ListView), const Offset(40, -600));
    await settleAsync(tester, rounds: 20);

    expect(
      find.byType(ReaderScreen),
      findsOneWidget,
      reason: 'a vertical drag belongs to the scroll view, not to navigation',
    );

    // Neither does a leftward one.
    await tester.drag(find.byType(ListView), const Offset(-220, 0));
    await settleAsync(tester, rounds: 20);
    expect(find.byType(ReaderScreen), findsOneWidget);
  });

  navTest('opened from the episode list, it pops back onto the same one', (
    tester,
  ) async {
    await tester.runAsync(seed);
    final app = harness(start: '/series/series-1');
    await tester.pumpWidget(app);
    await settleAsync(tester, rounds: 40);

    final router = GoRouter.of(tester.element(find.byType(SeriesDetailScreen)));
    router.push('/reader/c1');
    final readerList = find.descendant(
      of: find.byType(ReaderScreen),
      matching: find.byType(ListView),
    );
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 40));
      if (readerList.evaluate().isNotEmpty) break;
    }
    expect(readerList, findsOneWidget, reason: 'the reader opened');

    await tester.drag(readerList.first, const Offset(220, 0));
    await settleAsync(tester);

    expect(find.byType(SeriesDetailScreen), findsOneWidget);
    expect(find.byType(ReaderScreen), findsNothing);
    // Popped rather than stacked: there is no second episode list underneath.
    expect(
      router.routerDelegate.currentConfiguration.matches,
      hasLength(1),
      reason: 'in-and-out must not pile up routes',
    );
  });
}

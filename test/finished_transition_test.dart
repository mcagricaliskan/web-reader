import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/features/reader_screen.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/cleanup.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/storage/manifest.dart';

import '../tool/fixture/fixture_site.dart';

/// The finished-chapter transition, driven through the real reader: when the
/// dialog appears, what each answer does, and what "Don't ask again" saves.
void main() {
  late AppDatabase db;
  late Directory root;
  late FileStore store;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_finish');
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

  Future<void> seedSeries() => db.upsertLibraryItem(
    LibraryItem(
      lifecycle: 'active',
      id: 's1',
      title: 'Foo',
      sourceUrl: 'https://x.example/manga/foo',
      host: 'x.example',
      seriesKey: '/manga/foo',
      createdAt: DateTime(2026, 7, 1),
    ),
  );

  /// Real files so the reader actually opens.
  Future<void> seedChapter(
    int n, {
    required String readStatus,
    bool withFiles = true,
  }) async {
    final id = 'c$n';
    String? relative;
    if (withFiles) {
      final staging = await store.beginChapter(
        libraryItemId: 's1',
        chapterId: id,
      );
      final entries = <AssetEntry>[];
      for (var i = 1; i <= 3; i++) {
        await staging
            .assetFile('00$i.png')
            .writeAsBytes(panelPng(chapter: n, index: i));
        entries.add(
          AssetEntry(
            index: i,
            sourceUrl: 'https://cdn.example/$n/$i.png',
            status: AssetStatus.stored,
            relativePath: 'assets/00$i.png',
            width: 800,
            height: 1200,
            dimensionsVerified: true,
          ),
        );
      }
      relative = await store.commit(
        staging,
        ChapterManifest(
          schemaVersion: ChapterManifest.currentSchemaVersion,
          chapterId: id,
          libraryItemId: 's1',
          sourceUrl: 'https://x.example/manga/foo/$n',
          title: 'Foo Chapter $n',
          capturedAt: DateTime(2026, 7, 20),
          status: CaptureStatus.complete,
          detectedImageCount: 3,
          storedImageCount: 3,
          assets: entries,
        ),
      );
    }
    await db.upsertChapter(
      Chapter(
        id: id,
        libraryItemId: 's1',
        title: 'Foo Chapter $n',
        sourceUrl: 'https://x.example/manga/foo/$n',
        urlKey: 'https://x.example/manga/foo/$n',
        captureStatus: withFiles ? 'complete' : 'knownRemote',
        contentPath: relative,
        capturedAt: DateTime(2026, 7, 20),
        detectedImageCount: 3,
        storedImageCount: withFiles ? 3 : 0,
        sequence: n,
        byteSize: withFiles ? 1500 : 0,
        chapterNumber: n.toDouble(),
        chapterLabel: 'Chapter $n',
        readStatus: readStatus,
        progressFraction: readStatus == 'completed' ? 1 : 0.4,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
        completedAt: readStatus == 'completed' ? DateTime(2026, 7, 22) : null,
      ),
    );
  }

  Widget harness(String chapterId) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      fileStoreProvider.overrideWithValue(store),
      // A short undo window so the timer cannot outlive the test.
      cleanupProvider.overrideWithValue(
        CleanupService(
          db: db,
          fileStore: store,
          undoWindow: const Duration(milliseconds: 50),
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => ReaderScreen(chapterId: chapterId),
          ),
        ],
      ),
    ),
  );

  /// Real file IO cannot complete inside the fake-async zone, so the load is
  /// pumped with `runAsync` windows.
  Future<void> openReader(WidgetTester tester, String chapterId) async {
    await tester.pumpWidget(harness(chapterId));
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(ListView).evaluate().isNotEmpty) return;
      if (find.textContaining('Not available offline').evaluate().isNotEmpty) {
        return;
      }
    }
    fail('reader never finished loading');
  }

  /// Tap "next chapter" in the bottom chrome.
  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Next saved chapter'));
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(AlertDialog).evaluate().isNotEmpty) return;
    }
  }

  Future<void> settleDown(WidgetTester tester) async {
    // The undo window is a timer inside the fake-async zone: advance the
    // fake clock past it, or the tree is disposed with it still pending.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('asks when moving forward from a finished chapter', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(find.text('Remove the finished chapter?'), findsOneWidget);
    expect(find.textContaining('You finished Chapter 1'), findsOneWidget);
    expect(find.text('Keep offline'), findsOneWidget);
    expect(find.text('Remove offline files'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('a partially read chapter never asks', (tester) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'inProgress');
      await seedChapter(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect((await db.chapterById('c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  testWidgets('moving backward never asks', (tester) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'completed');
    });
    await openReader(tester, 'c2');
    await tester.tap(find.byTooltip('Previous saved chapter'));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(find.byType(AlertDialog), findsNothing);
    expect((await db.chapterById('c2'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  testWidgets('Keep without remember leaves the preference at ask', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    await tester.tap(find.text('Keep offline'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();

    expect((await db.chapterById('c1'))!.contentPath, isNotNull);
    expect(
      afterFinishedFromName(await db.getSetting(kAfterFinishedPrefKey)),
      AfterFinishedPref.ask,
      reason: 'one-off choice does not become a preference',
    );
    await settleDown(tester);
  });

  testWidgets('Remove without remember removes only this chapter', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    await tester.tap(find.text('Remove offline files'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    final removed = (await db.chapterById('c1'))!;
    expect(removed.contentPath, isNull);
    expect(removed.readStatus, 'completed', reason: 'history kept');
    expect(
      afterFinishedFromName(await db.getSetting(kAfterFinishedPrefKey)),
      AfterFinishedPref.ask,
      reason: 'still asks next time',
    );
    // The chapter now open was never touched.
    expect((await db.chapterById('c2'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  testWidgets("Keep with 'Don't ask again' saves keep offline", (tester) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    await tester.tap(find.textContaining("Don't ask again"));
    await tester.pump();
    await tester.tap(find.text('Keep offline'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();

    expect(
      afterFinishedFromName(await db.getSetting(kAfterFinishedPrefKey)),
      AfterFinishedPref.keep,
    );
    expect((await db.chapterById('c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  testWidgets("Remove with 'Don't ask again' saves remove automatically", (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    await tester.tap(find.textContaining("Don't ask again"));
    await tester.pump();
    await tester.tap(find.text('Remove offline files'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(
      afterFinishedFromName(await db.getSetting(kAfterFinishedPrefKey)),
      AfterFinishedPref.remove,
    );
    expect((await db.chapterById('c1'))!.contentPath, isNull);
    await settleDown(tester);
  });

  testWidgets('Keep offline preference suppresses the dialog entirely', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
      await db.setSetting(kAfterFinishedPrefKey, AfterFinishedPref.keep.name);
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect((await db.chapterById('c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  testWidgets('Remove automatically removes without asking', (tester) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
      await db.setSetting(kAfterFinishedPrefKey, AfterFinishedPref.remove.name);
    });
    await openReader(tester, 'c1');
    await tapNext(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    final removed = (await db.chapterById('c1'))!;
    expect(removed.contentPath, isNull);
    expect(removed.completedAt, isNotNull, reason: 'history kept');
    expect(
      (await db.chapterById('c2'))!.contentPath,
      isNotNull,
      reason: 'the newly opened chapter is never the one removed',
    );
    await settleDown(tester);
  });

  testWidgets('a removed chapter reads as not-downloaded, not an error', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      final cleanup = CleanupService(db: db, fileStore: store);
      await cleanup.removeOffline(['c1']);
    });
    await openReader(tester, 'c1');

    expect(find.text('Not available offline'), findsOneWidget);
    expect(
      find.textContaining('files for this chapter are gone'),
      findsNothing,
      reason: 'the user did this on purpose; do not alarm them',
    );
    expect(find.textContaining('capture it again'), findsOneWidget);
    await settleDown(tester);
  });
}

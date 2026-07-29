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
/// series is asked, what each answer stores, and that the answer belongs to
/// that series and to no other (D37).
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

  Future<void> seedSeries({String id = 's1', String title = 'Foo'}) =>
      db.upsertLibraryItem(
        LibraryItem(
          lifecycle: 'active',
          id: id,
          title: title,
          sourceUrl: 'https://x.example/manga/$id',
          host: 'x.example',
          seriesKey: '/manga/$id',
          createdAt: DateTime(2026, 7, 1),
        ),
      );

  /// Chapter ids stay `c1`, `c2`… for the first series so the common case
  /// reads plainly; a second series prefixes its own.
  String chapterId(String seriesId, int n) =>
      seriesId == 's1' ? 'c$n' : '${seriesId}c$n';

  /// Real files so the reader actually opens.
  Future<void> seedChapter(
    int n, {
    required String readStatus,
    bool withFiles = true,
    String seriesId = 's1',
  }) async {
    final id = chapterId(seriesId, n);
    String? relative;
    if (withFiles) {
      final staging = await store.beginChapter(
        libraryItemId: seriesId,
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
          libraryItemId: seriesId,
          sourceUrl: 'https://x.example/manga/$seriesId/$n',
          title: 'Chapter $n',
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
        libraryItemId: seriesId,
        title: 'Chapter $n',
        sourceUrl: 'https://x.example/manga/$seriesId/$n',
        urlKey: 'https://x.example/manga/$seriesId/$n',
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

  Future<SeriesCleanupPref?> prefOf(String seriesId) async =>
      seriesCleanupFromName(
        (await db.libraryItemById(seriesId))!.finishedCleanup,
      );

  /// [undoWindow] defaults to a short one so the finalize timer cannot outlive
  /// the test; the Undo test needs a real window and passes its own.
  Widget harness(
    String chapterId, {
    Duration undoWindow = const Duration(milliseconds: 50),
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      fileStoreProvider.overrideWithValue(store),
      cleanupProvider.overrideWithValue(
        CleanupService(db: db, fileStore: store, undoWindow: undoWindow),
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
  Future<void> openReader(
    WidgetTester tester,
    String chapterId, {
    Duration undoWindow = const Duration(milliseconds: 50),
  }) async {
    await tester.pumpWidget(harness(chapterId, undoWindow: undoWindow));
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

  /// Real file IO again: pump `runAsync` windows until [ready], without
  /// advancing the fake clock (which would spend the notice's own timeout).
  Future<void> pumpUntil(
    WidgetTester tester,
    Future<bool> Function() ready, {
    required String reason,
  }) async {
    for (var i = 0; i < 80; i++) {
      var done = false;
      await tester.runAsync(() async {
        done = await ready();
      });
      if (done) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    fail(reason);
  }

  final noticeText = find.text('Previous chapter removed offline');
  final cleanupDialog = find.text('Downloaded chapters in this series');
  final removeOption = find.byKey(const ValueKey('seriesCleanup-remove'));
  final keepOption = find.byKey(const ValueKey('seriesCleanup-keep'));

  /// Which option the dialog has selected right now.
  bool isSelected(Finder option) => find
      .descendant(of: option, matching: find.byIcon(Icons.radio_button_checked))
      .evaluate()
      .isNotEmpty;

  Future<void> saveChoice(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('saveSeriesCleanup')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  /// A series already set to remove, one finished chapter and one to move on
  /// to; returns with the removal notice on screen.
  Future<void> removeByMovingOn(WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.remove.name);
    });
    await openReader(tester, 'c1');
    await tester.tap(find.byTooltip('Next saved chapter'));
    await pumpUntil(
      tester,
      () async => noticeText.evaluate().isNotEmpty,
      reason: 'the removal notice never appeared',
    );
  }

  Future<void> settleDown(WidgetTester tester) async {
    // The undo window is a timer inside the fake-async zone: advance the
    // fake clock past it, or the tree is disposed with it still pending.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
  }

  // --- when the question is asked -------------------------------------------

  testWidgets('an undecided series is asked on the first forward transition', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(cleanupDialog, findsOneWidget);
    expect(
      find.textContaining('after you continue to the next'),
      findsOneWidget,
    );
    expect(find.text('Remove after continuing'), findsOneWidget);
    expect(find.text('Keep downloaded files'), findsOneWidget);
    expect(find.text('Save choice'), findsOneWidget);
    expect(
      find.textContaining('applies only to this series'),
      findsOneWidget,
      reason: 'the scope is stated where the decision is made',
    );
    await settleDown(tester);
  });

  testWidgets('Remove after continuing is the preselected answer', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(isSelected(removeOption), isTrue);
    expect(isSelected(keepOption), isFalse);
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
    expect(await prefOf('s1'), isNull, reason: 'nothing was decided');
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

  // --- what an answer does --------------------------------------------------

  testWidgets('saving Remove stores it on this series and applies it now', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedSeries(id: 's2', title: 'Bar');
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);
    await saveChoice(tester);

    expect(await prefOf('s1'), SeriesCleanupPref.remove);
    expect(
      await prefOf('s2'),
      isNull,
      reason: 'a decision reaches exactly one series',
    );

    final removed = (await db.chapterById('c1'))!;
    expect(removed.contentPath, isNull);
    expect(removed.readStatus, 'completed', reason: 'history kept');
    expect(removed.completedAt, isNotNull);
    expect(removed.sourceUrl, isNotEmpty, reason: 'metadata kept');
    expect(await db.libraryItemById('s1'), isNotNull);
    expect(
      (await db.chapterById('c2'))!.contentPath,
      isNotNull,
      reason: 'the newly opened chapter is never the one removed',
    );
    await settleDown(tester);
  });

  testWidgets('saving Keep stores it on this series and removes nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedSeries(id: 's2', title: 'Bar');
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    await tester.tap(keepOption);
    await tester.pump();
    expect(isSelected(keepOption), isTrue);
    expect(isSelected(removeOption), isFalse);
    await saveChoice(tester);

    expect(await prefOf('s1'), SeriesCleanupPref.keep);
    expect(await prefOf('s2'), isNull);
    expect((await db.chapterById('c1'))!.contentPath, isNotNull);
    expect(
      Directory(
        store.resolve((await db.chapterById('c1'))!.contentPath!),
      ).existsSync(),
      isTrue,
    );
    await settleDown(tester);
  });

  testWidgets('dismissing without saving stores nothing and keeps the files', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    // The scrim: dismissal, not an answer.
    await tester.tapAt(const Offset(20, 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();

    expect(cleanupDialog, findsNothing);
    expect(await prefOf('s1'), isNull);
    expect((await db.chapterById('c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  testWidgets('one dialog per transition, never a stacked second one', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'completed');
      await seedChapter(3, readStatus: 'unread');
    });
    await openReader(tester, 'c1');

    // Two forward taps in quick succession: the second lands while the first
    // transition is still resolving its question. Both chapters are finished,
    // so without the guard each would raise its own dialog.
    final next = find.byTooltip('Next saved chapter');
    await tester.tap(next);
    await tester.pump();
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next, warnIfMissed: false);
    }
    await pumpUntil(
      tester,
      () async => find.byType(AlertDialog).evaluate().isNotEmpty,
      reason: 'the cleanup question never appeared',
    );

    expect(find.byType(AlertDialog), findsOneWidget);
    await saveChoice(tester);
    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'answering once answers it — no queued duplicate behind it',
    );
    expect(await prefOf('s1'), SeriesCleanupPref.remove);
    await settleDown(tester);
  });

  // --- a decided series -----------------------------------------------------

  testWidgets('a series set to remove is never asked again', (tester) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.remove.name);
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
    await settleDown(tester);
  });

  testWidgets('a series set to keep is never asked and keeps its files', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.keep.name);
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect((await db.chapterById('c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  testWidgets('another series is still asked, and keeps its own answer', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedSeries(id: 's2', title: 'Bar');
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
      await seedChapter(1, readStatus: 'completed', seriesId: 's2');
      await seedChapter(2, readStatus: 'unread', seriesId: 's2');
      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.remove.name);
    });

    await openReader(tester, 's2c1');
    await tapNext(tester);
    expect(
      cleanupDialog,
      findsOneWidget,
      reason: "another series' decision is not this one's",
    );
    expect(isSelected(removeOption), isTrue);

    await tester.tap(keepOption);
    await tester.pump();
    await saveChoice(tester);

    expect(await prefOf('s2'), SeriesCleanupPref.keep);
    expect(
      await prefOf('s1'),
      SeriesCleanupPref.remove,
      reason: 'deciding one series leaves the other exactly as it was',
    );
    expect((await db.chapterById('s2c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  testWidgets('a reset series asks again, preselecting Remove', (tester) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
      // Decided as keep, then reset from the series settings.
      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.keep.name);
      await db.setSeriesFinishedCleanup('s1', null);
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(cleanupDialog, findsOneWidget);
    expect(
      isSelected(removeOption),
      isTrue,
      reason: 'the preselection is fixed, never the previous answer',
    );
    await settleDown(tester);
  });

  testWidgets('a stale global storage.afterFinished value changes nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
      // The obsolete key, written by an old build that auto-removed.
      await db.setSetting('storage.afterFinished', 'remove');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(
      cleanupDialog,
      findsOneWidget,
      reason: 'the series has not been asked; a stale row is not an answer',
    );
    expect((await db.chapterById('c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  // --- the removal notice ---------------------------------------------------
  //
  // It is a moment on the reader, not a message in a queue: it says one thing,
  // it offers the undo it can honour, and it ends — on its own, on a tap, on a
  // chapter change, or on leaving the app. Nothing about it is persisted, so
  // there is nothing for a later screen or a later launch to restore.

  testWidgets('says what happened, offers Undo, and never quotes bytes', (
    tester,
  ) async {
    await removeByMovingOn(tester);

    expect(noticeText, findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(
      find.textContaining('freed'),
      findsNothing,
      reason: 'how much space came back is not a mid-read decision',
    );
    expect(find.textContaining('KB'), findsNothing);
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'not on the app-wide messenger, which outlives this screen',
    );
    await settleDown(tester);
  });

  testWidgets('times out on its own and does not come back', (tester) async {
    await removeByMovingOn(tester);

    await tester.pump(kReaderNoticeDuration + const Duration(seconds: 1));
    await tester.pump();
    expect(noticeText, findsNothing);

    // Rebuild the screen and let far more than a timeout pass: a dismissed
    // notice has no state left to redisplay.
    await tester.pump(const Duration(seconds: 30));
    expect(noticeText, findsNothing);
    await settleDown(tester);
  });

  testWidgets('closing it ends it for good', (tester) async {
    await removeByMovingOn(tester);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(noticeText, findsNothing);

    await tester.pump(const Duration(seconds: 10));
    expect(noticeText, findsNothing);
    await settleDown(tester);
  });

  testWidgets('leaving the app ends it, and returning does not restore it', (
    tester,
  ) async {
    await removeByMovingOn(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(noticeText, findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      noticeText,
      findsNothing,
      reason: 'a resume must not replay what the user already saw',
    );
    await settleDown(tester);
  });

  testWidgets('moving on again clears it instead of stacking a second one', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'completed');
      await seedChapter(3, readStatus: 'unread');
      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.remove.name);
    });
    await openReader(tester, 'c1');

    await tester.tap(find.byTooltip('Next saved chapter'));
    await pumpUntil(
      tester,
      () async => noticeText.evaluate().isNotEmpty,
      reason: 'the first removal notice never appeared',
    );

    await pumpUntil(
      tester,
      () async => find.byTooltip('Next saved chapter').evaluate().isNotEmpty,
      reason: 'the next chapter never finished loading',
    );
    await tester.tap(find.byTooltip('Next saved chapter'));
    await pumpUntil(
      tester,
      () async => (await db.chapterById('c2'))?.contentPath == null,
      reason: 'the second chapter was never removed',
    );

    expect(
      noticeText,
      findsOneWidget,
      reason: 'one notice at a time, replaced rather than queued',
    );
    await settleDown(tester);
  });

  testWidgets('a chapter change with nothing removed clears the notice', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
      await seedChapter(3, readStatus: 'unread');
      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.remove.name);
    });
    await openReader(tester, 'c1');
    await tester.tap(find.byTooltip('Next saved chapter'));
    await pumpUntil(
      tester,
      () async => noticeText.evaluate().isNotEmpty,
      reason: 'the removal notice never appeared',
    );

    // c2 is unread, so moving on from it removes nothing — and the notice
    // about c1 has no business surviving onto c3.
    await pumpUntil(
      tester,
      () async => find.byTooltip('Next saved chapter').evaluate().isNotEmpty,
      reason: 'the next chapter never finished loading',
    );
    await tester.tap(find.byTooltip('Next saved chapter'));
    await tester.pump();
    expect(noticeText, findsNothing);
    await settleDown(tester);
  });

  testWidgets('Undo puts the files back and says so', (tester) async {
    await tester.runAsync(() async {
      await seedSeries();
      await seedChapter(1, readStatus: 'completed');
      await seedChapter(2, readStatus: 'unread');
      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.remove.name);
    });
    // Undo() cancels the finalize timer, so a real window leaves nothing
    // pending at teardown.
    await openReader(tester, 'c1', undoWindow: const Duration(seconds: 10));
    await tester.tap(find.byTooltip('Next saved chapter'));
    await pumpUntil(
      tester,
      () async => noticeText.evaluate().isNotEmpty,
      reason: 'the removal notice never appeared',
    );

    await tester.tap(find.text('Undo'));
    await pumpUntil(
      tester,
      () async => find.text('Chapter restored').evaluate().isNotEmpty,
      reason: 'the restore confirmation never appeared',
    );

    final restored = (await db.chapterById('c1'))!;
    expect(restored.contentPath, isNotNull);
    expect(restored.byteSize, 1500);
    expect(store.chapterExists(restored.contentPath!), isTrue);
    expect(noticeText, findsNothing, reason: 'replaced, not stacked');
    expect(find.text('Undo'), findsNothing);
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

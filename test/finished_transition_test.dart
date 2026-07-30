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

/// The finished-entry transition, driven through the real reader: when the
/// collection is asked, what each answer stores, and that the answer belongs to
/// that collection and to no other (D37).
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

  Future<void> seedCollection({String id = 's1', String title = 'Foo'}) =>
      db.upsertCollection(
        Collection(
          contentKind: 'unknownWebContent',
          sequenceKind: 'none',
          orderingBasis: 'discoveryOrder',
          shapeConfidence: 'low',
          lifecycle: 'active',
          id: id,
          title: title,
          sourceUrl: 'https://x.example/guide/$id',
          host: 'x.example',
          collectionKey: '/guide/$id',
          createdAt: DateTime(2026, 7, 1),
        ),
      );

  /// Entry ids stay `c1`, `c2`… for the first collection so the common case
  /// reads plainly; a second collection prefixes its own.
  String entryId(String collectionId, int n) =>
      collectionId == 's1' ? 'c$n' : '${collectionId}c$n';

  /// Real files so the reader actually opens.
  Future<void> seedEntry(
    int n, {
    required String readStatus,
    bool withFiles = true,
    String collectionId = 's1',
  }) async {
    final id = entryId(collectionId, n);
    String? relative;
    if (withFiles) {
      final staging = await store.beginEntry(
        collectionId: collectionId,
        entryId: id,
      );
      final entries = <EntryAsset>[];
      for (var i = 1; i <= 3; i++) {
        await staging
            .assetFile('00$i.png')
            .writeAsBytes(panelPng(entry: n, index: i));
        entries.add(
          EntryAsset(
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
        EntryManifest(
          schemaVersion: EntryManifest.currentSchemaVersion,
          entryId: id,
          collectionId: collectionId,
          sourceUrl: 'https://x.example/guide/$collectionId/$n',
          title: 'Entry $n',
          savedAt: DateTime(2026, 7, 20),
          status: SaveStatus.complete,
          detectedAssetCount: 3,
          storedAssetCount: 3,
          assets: entries,
        ),
      );
    }
    await db.upsertEntry(
      Entry(
        host: '',
        contentKind: 'unknownWebContent',
        contentKindConfidence: 'low',
        contentKindIsUserSet: false,
        id: id,
        collectionId: collectionId,
        title: 'Entry $n',
        sourceUrl: 'https://x.example/guide/$collectionId/$n',
        urlKey: 'https://x.example/guide/$collectionId/$n',
        saveStatus: withFiles ? 'complete' : 'knownRemote',
        contentPath: relative,
        savedAt: DateTime(2026, 7, 20),
        detectedAssetCount: 3,
        storedAssetCount: withFiles ? 3 : 0,
        entryOrder: n,
        byteSize: withFiles ? 1500 : 0,
        entryNumber: n.toDouble(),
        sourceMarker: 'Entry $n',
        readStatus: readStatus,
        progressFraction: readStatus == 'completed' ? 1 : 0.4,
        progressPageIndex: 0,
        progressOffsetInPage: 0,
        completedAt: readStatus == 'completed' ? DateTime(2026, 7, 22) : null,
      ),
    );
  }

  Future<CollectionCleanupPreference?> prefOf(String collectionId) async =>
      collectionCleanupFromName(
        (await db.collectionById(collectionId))!.cleanupPreference,
      );

  /// [undoWindow] defaults to a short one so the finalize timer cannot outlive
  /// the test; the Undo test needs a real window and passes its own.
  Widget harness(
    String entryId, {
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
            builder: (_, _) => ReaderScreen(entryId: entryId),
          ),
        ],
      ),
    ),
  );

  /// Real file IO cannot complete inside the fake-async zone, so the load is
  /// pumped with `runAsync` windows.
  Future<void> openReader(
    WidgetTester tester,
    String entryId, {
    Duration undoWindow = const Duration(milliseconds: 50),
  }) async {
    await tester.pumpWidget(harness(entryId, undoWindow: undoWindow));
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

  /// Tap "next entry" in the bottom chrome.
  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Next saved entry'));
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

  final noticeText = find.text('Removed downloads');
  final restoredText = find.text('Restored downloads');
  final cleanupDialog = find.text('Downloaded entries in this collection');
  final removeOption = find.byKey(const ValueKey('collectionCleanup-remove'));
  final keepOption = find.byKey(const ValueKey('collectionCleanup-keep'));

  /// Which option the dialog has selected right now.
  bool isSelected(Finder option) => find
      .descendant(of: option, matching: find.byIcon(Icons.radio_button_checked))
      .evaluate()
      .isNotEmpty;

  Future<void> saveChoice(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('saveCollectionCleanup')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  /// A collection already set to remove, one finished entry and one to move on
  /// to; returns with the removal notice on screen.
  Future<void> removeByMovingOn(WidgetTester tester) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
      await db.setCollectionCleanupPreference(
        's1',
        CollectionCleanupPreference.remove.name,
      );
    });
    await openReader(tester, 'c1');
    await tester.tap(find.byTooltip('Next saved entry'));
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

  testWidgets(
    'an undecided collection is asked on the first forward transition',
    (tester) async {
      await tester.runAsync(() async {
        await seedCollection();
        await seedEntry(1, readStatus: 'completed');
        await seedEntry(2, readStatus: 'unread');
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
        find.textContaining('applies only to this collection'),
        findsOneWidget,
        reason: 'the scope is stated where the decision is made',
      );
      await settleDown(tester);
    },
  );

  testWidgets('Remove after continuing is the preselected answer', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(isSelected(removeOption), isTrue);
    expect(isSelected(keepOption), isFalse);
    await settleDown(tester);
  });

  testWidgets('a partially read entry never asks', (tester) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'inProgress');
      await seedEntry(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect((await db.entryById('c1'))!.contentPath, isNotNull);
    expect(await prefOf('s1'), isNull, reason: 'nothing was decided');
    await settleDown(tester);
  });

  testWidgets('moving backward never asks', (tester) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'completed');
    });
    await openReader(tester, 'c2');
    await tester.tap(find.byTooltip('Previous saved entry'));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    expect(find.byType(AlertDialog), findsNothing);
    expect((await db.entryById('c2'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  // --- what an answer does --------------------------------------------------

  testWidgets('saving Remove stores it on this collection and applies it now', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedCollection(id: 's2', title: 'Bar');
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);
    await saveChoice(tester);

    expect(await prefOf('s1'), CollectionCleanupPreference.remove);
    expect(
      await prefOf('s2'),
      isNull,
      reason: 'a decision reaches exactly one collection',
    );

    final removed = (await db.entryById('c1'))!;
    expect(removed.contentPath, isNull);
    expect(removed.readStatus, 'completed', reason: 'history kept');
    expect(removed.completedAt, isNotNull);
    expect(removed.sourceUrl, isNotEmpty, reason: 'metadata kept');
    expect(await db.collectionById('s1'), isNotNull);
    expect(
      (await db.entryById('c2'))!.contentPath,
      isNotNull,
      reason: 'the newly opened entry is never the one removed',
    );
    await settleDown(tester);
  });

  testWidgets('saving Keep stores it on this collection and removes nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedCollection(id: 's2', title: 'Bar');
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    await tester.tap(keepOption);
    await tester.pump();
    expect(isSelected(keepOption), isTrue);
    expect(isSelected(removeOption), isFalse);
    await saveChoice(tester);

    expect(await prefOf('s1'), CollectionCleanupPreference.keep);
    expect(await prefOf('s2'), isNull);
    expect((await db.entryById('c1'))!.contentPath, isNotNull);
    expect(
      Directory(
        store.resolve((await db.entryById('c1'))!.contentPath!),
      ).existsSync(),
      isTrue,
    );
    await settleDown(tester);
  });

  testWidgets('dismissing without saving stores nothing and keeps the files', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
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
    expect((await db.entryById('c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  testWidgets('one dialog per transition, never a stacked second one', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'completed');
      await seedEntry(3, readStatus: 'unread');
    });
    await openReader(tester, 'c1');

    // Two forward taps in quick succession: the second lands while the first
    // transition is still resolving its question. Both entries are finished,
    // so without the guard each would raise its own dialog.
    final next = find.byTooltip('Next saved entry');
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
    expect(await prefOf('s1'), CollectionCleanupPreference.remove);
    await settleDown(tester);
  });

  // --- a decided collection -----------------------------------------------------

  testWidgets('a collection set to remove is never asked again', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
      await db.setCollectionCleanupPreference(
        's1',
        CollectionCleanupPreference.remove.name,
      );
    });
    await openReader(tester, 'c1');
    await tapNext(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    final removed = (await db.entryById('c1'))!;
    expect(removed.contentPath, isNull);
    expect(removed.completedAt, isNotNull, reason: 'history kept');
    await settleDown(tester);
  });

  testWidgets('a collection set to keep is never asked and keeps its files', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
      await db.setCollectionCleanupPreference(
        's1',
        CollectionCleanupPreference.keep.name,
      );
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect((await db.entryById('c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  testWidgets('another collection is still asked, and keeps its own answer', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedCollection(id: 's2', title: 'Bar');
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
      await seedEntry(1, readStatus: 'completed', collectionId: 's2');
      await seedEntry(2, readStatus: 'unread', collectionId: 's2');
      await db.setCollectionCleanupPreference(
        's1',
        CollectionCleanupPreference.remove.name,
      );
    });

    await openReader(tester, 's2c1');
    await tapNext(tester);
    expect(
      cleanupDialog,
      findsOneWidget,
      reason: "another collection's decision is not this one's",
    );
    expect(isSelected(removeOption), isTrue);

    await tester.tap(keepOption);
    await tester.pump();
    await saveChoice(tester);

    expect(await prefOf('s2'), CollectionCleanupPreference.keep);
    expect(
      await prefOf('s1'),
      CollectionCleanupPreference.remove,
      reason: 'deciding one collection leaves the other exactly as it was',
    );
    expect((await db.entryById('s2c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  testWidgets('a reset collection asks again, preselecting Remove', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
      // Decided as keep, then reset from the collection settings.
      await db.setCollectionCleanupPreference(
        's1',
        CollectionCleanupPreference.keep.name,
      );
      await db.setCollectionCleanupPreference('s1', null);
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
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
      // The obsolete key, written by an old build that auto-removed.
      await db.setSetting('storage.afterFinished', 'remove');
    });
    await openReader(tester, 'c1');
    await tapNext(tester);

    expect(
      cleanupDialog,
      findsOneWidget,
      reason: 'the collection has not been asked; a stale row is not an answer',
    );
    expect((await db.entryById('c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  // --- the removal notice ---------------------------------------------------
  //
  // It is a moment on the reader, not a message in a queue: it says one thing,
  // it offers the undo it can honour, and it ends — on its own, on a tap, on a
  // entry change, or on leaving the app. Nothing about it is persisted, so
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
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'completed');
      await seedEntry(3, readStatus: 'unread');
      await db.setCollectionCleanupPreference(
        's1',
        CollectionCleanupPreference.remove.name,
      );
    });
    await openReader(tester, 'c1');

    await tester.tap(find.byTooltip('Next saved entry'));
    await pumpUntil(
      tester,
      () async => noticeText.evaluate().isNotEmpty,
      reason: 'the first removal notice never appeared',
    );

    await pumpUntil(
      tester,
      () async => find.byTooltip('Next saved entry').evaluate().isNotEmpty,
      reason: 'the next entry never finished loading',
    );
    await tester.tap(find.byTooltip('Next saved entry'));
    await pumpUntil(
      tester,
      () async => (await db.entryById('c2'))?.contentPath == null,
      reason: 'the second entry was never removed',
    );

    expect(
      noticeText,
      findsOneWidget,
      reason: 'one notice at a time, replaced rather than queued',
    );
    await settleDown(tester);
  });

  testWidgets('an entry change with nothing removed clears the notice', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
      await seedEntry(3, readStatus: 'unread');
      await db.setCollectionCleanupPreference(
        's1',
        CollectionCleanupPreference.remove.name,
      );
    });
    await openReader(tester, 'c1');
    await tester.tap(find.byTooltip('Next saved entry'));
    await pumpUntil(
      tester,
      () async => noticeText.evaluate().isNotEmpty,
      reason: 'the removal notice never appeared',
    );

    // c2 is unread, so moving on from it removes nothing — and the notice
    // about c1 has no business surviving onto c3.
    await pumpUntil(
      tester,
      () async => find.byTooltip('Next saved entry').evaluate().isNotEmpty,
      reason: 'the next entry never finished loading',
    );
    await tester.tap(find.byTooltip('Next saved entry'));
    await tester.pump();
    expect(noticeText, findsNothing);
    await settleDown(tester);
  });

  testWidgets('Undo puts the files back and says so', (tester) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
      await db.setCollectionCleanupPreference(
        's1',
        CollectionCleanupPreference.remove.name,
      );
    });
    // Undo() cancels the finalize timer, so a real window leaves nothing
    // pending at teardown.
    await openReader(tester, 'c1', undoWindow: const Duration(seconds: 10));
    await tester.tap(find.byTooltip('Next saved entry'));
    await pumpUntil(
      tester,
      () async => noticeText.evaluate().isNotEmpty,
      reason: 'the removal notice never appeared',
    );

    await tester.tap(find.text('Undo'));
    await pumpUntil(
      tester,
      () async => restoredText.evaluate().isNotEmpty,
      reason: 'the restore confirmation never appeared',
    );

    final restored = (await db.entryById('c1'))!;
    expect(restored.contentPath, isNotNull);
    expect(restored.byteSize, 1500);
    expect(store.entryExists(restored.contentPath!), isTrue);
    expect(noticeText, findsNothing, reason: 'replaced, not stacked');
    expect(find.text('Undo'), findsNothing);
    await settleDown(tester);
  });

  testWidgets('Undo is still live in the notice\'s last moments', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      await seedEntry(2, readStatus: 'unread');
      await db.setCollectionCleanupPreference(
        's1',
        CollectionCleanupPreference.remove.name,
      );
    });
    await openReader(tester, 'c1', undoWindow: const Duration(seconds: 10));
    await tester.tap(find.byTooltip('Next saved entry'));
    await pumpUntil(
      tester,
      () async => noticeText.evaluate().isNotEmpty,
      reason: 'the removal notice never appeared',
    );

    // A frame short of the timeout — the notice is fading out but has not
    // dismissed, so what it still offers must still work. A shorter notice than
    // the undo window is fine; a notice that outlives what it can honour is not.
    await tester.pump(kReaderNoticeDuration - const Duration(milliseconds: 16));
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await pumpUntil(
      tester,
      () async => restoredText.evaluate().isNotEmpty,
      reason: 'a notice fading out still took the Undo, but never confirmed it',
    );
    expect((await db.entryById('c1'))!.contentPath, isNotNull);
    await settleDown(tester);
  });

  test('the notice never outlasts the undo it offers', () {
    expect(
      kReaderNoticeDuration,
      lessThanOrEqualTo(CleanupService(db: db, fileStore: store).undoWindow),
      reason: 'past that window Undo is a dead button',
    );
  });

  testWidgets('a removed entry reads as not-downloaded, not an error', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedCollection();
      await seedEntry(1, readStatus: 'completed');
      final cleanup = CleanupService(db: db, fileStore: store);
      await cleanup.removeOffline(['c1']);
    });
    await openReader(tester, 'c1');

    expect(find.text('Not available offline'), findsOneWidget);
    expect(
      find.textContaining('files for this entry are gone'),
      findsNothing,
      reason: 'the user did this on purpose; do not alarm them',
    );
    expect(find.textContaining('save it again'), findsOneWidget);
    await settleDown(tester);
  });
}

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/storage/cleanup.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/storage/manifest.dart';

/// Offline-file removal: the files go, everything that makes the chapter a
/// chapter stays. This is the contract the whole cleanup feature rests on.
void main() {
  late AppDatabase db;
  late Directory root;
  late FileStore store;
  late CleanupService cleanup;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_cleanup');
    store = FileStore(root);
    Directory(
      p.join(root.path, FileStore.libraryFolderName),
    ).createSync(recursive: true);
    Directory(
      p.join(root.path, FileStore.tmpFolderName),
    ).createSync(recursive: true);
    cleanup = CleanupService(
      db: db,
      fileStore: store,
      undoWindow: const Duration(milliseconds: 200),
    );
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

  /// A committed chapter with real files, fully read by default.
  Future<Chapter> seedChapter(
    int n, {
    String readStatus = 'completed',
    String captureStatus = 'complete',
  }) async {
    final id = 'c$n';
    final staging = await store.beginChapter(
      libraryItemId: 's1',
      chapterId: id,
    );
    for (var i = 1; i <= 3; i++) {
      await staging.assetFile('00$i.png').writeAsBytes(List.filled(500, 7));
    }
    final relative = await store.commit(
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
        assets: const [],
      ),
    );
    final chapter = Chapter(
      id: id,
      libraryItemId: 's1',
      title: 'Foo Chapter $n',
      sourceUrl: 'https://x.example/manga/foo/$n',
      urlKey: 'https://x.example/manga/foo/$n',
      captureStatus: captureStatus,
      contentPath: relative,
      capturedAt: DateTime(2026, 7, 20),
      detectedImageCount: 3,
      storedImageCount: 3,
      sequence: n,
      byteSize: 1500,
      chapterNumber: n.toDouble(),
      chapterLabel: 'Chapter $n',
      readStatus: readStatus,
      progressFraction: readStatus == 'completed' ? 1 : 0.42,
      progressImageIndex: 2,
      progressOffsetInImage: 0.25,
      firstOpenedAt: DateTime(2026, 7, 21),
      lastReadAt: DateTime(2026, 7, 22),
      completedAt: readStatus == 'completed' ? DateTime(2026, 7, 22) : null,
      discoveredAt: DateTime(2026, 7, 19),
      discoveryBasis: 'chapterList',
      discoveryConfidence: 'high',
    );
    await db.upsertChapter(chapter);
    return chapter;
  }

  test('files go; every piece of metadata stays', () async {
    await seedSeries();
    final before = await seedChapter(1);
    final dir = Directory(store.resolve(before.contentPath!));
    expect(dir.existsSync(), isTrue);

    final result = await cleanup.removeOffline([before.id]);
    expect(result.removed, 1);
    expect(result.freedBytes, 1500);

    final after = (await db.chapterById('c1'))!;
    expect(after.contentPath, isNull, reason: 'no longer offline');
    expect(after.byteSize, 0);
    expect(after.offlineRemovedAt, isNotNull, reason: 'user removal recorded');

    // Everything that must survive.
    expect(after.libraryItemId, before.libraryItemId);
    expect(after.sourceUrl, before.sourceUrl);
    expect(after.urlKey, before.urlKey);
    expect(after.sequence, before.sequence);
    expect(after.chapterNumber, before.chapterNumber);
    expect(after.chapterLabel, before.chapterLabel);
    expect(after.readStatus, 'completed');
    expect(after.progressFraction, before.progressFraction);
    expect(after.progressImageIndex, before.progressImageIndex);
    expect(after.completedAt, before.completedAt);
    expect(after.lastReadAt, before.lastReadAt);
    expect(after.firstOpenedAt, before.firstOpenedAt);
    expect(after.discoveredAt, before.discoveredAt);
    expect(after.discoveryBasis, before.discoveryBasis);
    // The series itself is untouched.
    expect(await db.libraryItemById('s1'), isNotNull);
  });

  test('the chapter can be captured again afterwards', () async {
    await seedSeries();
    final chapter = await seedChapter(1);
    await cleanup.removeOffline([chapter.id]);
    expect((await db.chapterById('c1'))!.contentPath, isNull);

    // A re-capture writes the row and explicitly clears the removed marker
    // (drift's upsert treats a null field as "leave it alone", so the engine
    // clears it deliberately — see AppDatabase.clearOfflineRemovedMark).
    await db.upsertChapter(
      chapter.copyWith(contentPath: Value(chapter.contentPath), byteSize: 1500),
    );
    await db.clearOfflineRemovedMark(chapter.id);
    final recaptured = (await db.chapterById('c1'))!;
    expect(recaptured.contentPath, isNotNull);
    expect(recaptured.offlineRemovedAt, isNull);
    expect(recaptured.readStatus, 'completed', reason: 'history survived');
  });

  test('undo restores both the files and the row', () async {
    await seedSeries();
    final chapter = await seedChapter(1);
    final dir = Directory(store.resolve(chapter.contentPath!));

    final result = await cleanup.removeOffline([chapter.id]);
    expect(dir.existsSync(), isFalse, reason: 'moved aside');
    expect(result.canUndo, isTrue);

    await result.undo.undo();
    expect(dir.existsSync(), isTrue, reason: 'files are back');
    final after = (await db.chapterById('c1'))!;
    expect(after.contentPath, chapter.contentPath);
    expect(after.byteSize, 1500);
    expect(after.offlineRemovedAt, isNull);
  });

  test('after the undo window the files are really gone', () async {
    await seedSeries();
    final chapter = await seedChapter(1);
    final dir = Directory(store.resolve(chapter.contentPath!));

    final result = await cleanup.removeOffline([chapter.id]);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(result.canUndo, isFalse);
    expect(dir.existsSync(), isFalse);
    final undoDir = Directory(
      p.join(root.path, FileStore.tmpFolderName, 'undo-c1'),
    );
    expect(undoDir.existsSync(), isFalse, reason: 'staging cleaned');
  });

  test('a chapter open in the reader cannot be removed', () async {
    await seedSeries();
    final chapter = await seedChapter(1);
    cleanup.openReaderChapterId.value = chapter.id;

    expect(await cleanup.lockReasonFor(chapter), 'open in the reader');
    final result = await cleanup.removeOffline([chapter.id]);

    expect(result.removed, 0);
    expect(result.keptLocked, hasLength(1));
    expect(result.keptLocked.single, contains('open in the reader'));
    expect((await db.chapterById('c1'))!.contentPath, isNotNull);
    expect(Directory(store.resolve(chapter.contentPath!)).existsSync(), isTrue);
  });

  test('a chapter being captured cannot be removed', () async {
    await seedSeries();
    final chapter = await seedChapter(1, captureStatus: 'capturing');
    expect(await cleanup.lockReasonFor(chapter), 'being captured');
    final result = await cleanup.removeOffline([chapter.id]);
    expect(result.removed, 0, reason: 'not even eligible');
  });

  test('bulk removal reports progress and skips locked chapters', () async {
    await seedSeries();
    for (var n = 1; n <= 5; n++) {
      await seedChapter(n);
    }
    cleanup.openReaderChapterId.value = 'c3';

    final progress = <(int, int)>[];
    final result = await cleanup.removeOfflineNow([
      'c1',
      'c2',
      'c3',
      'c4',
      'c5',
    ], onProgress: (processed, freed) => progress.add((processed, freed)));

    expect(result.removed, 4, reason: 'c3 was open');
    expect(result.freedBytes, 4 * 1500);
    expect(result.keptLocked, hasLength(1));
    expect(progress, isNotEmpty, reason: 'observable while it runs');
    expect((await db.chapterById('c3'))!.contentPath, isNotNull);
    for (final id in ['c1', 'c2', 'c4', 'c5']) {
      expect((await db.chapterById(id))!.contentPath, isNull);
      expect((await db.chapterById(id))!.readStatus, 'completed');
    }
  });

  test(
    'removing a chapter whose files already vanished still records it',
    () async {
      await seedSeries();
      final chapter = await seedChapter(1);
      Directory(
        store.resolve(chapter.contentPath!),
      ).deleteSync(recursive: true);

      final result = await cleanup.removeOffline([chapter.id]);
      expect(result.removed, 1);
      expect((await db.chapterById('c1'))!.offlineRemovedAt, isNotNull);
    },
  );

  group('the per-series cleanup preference', () {
    Future<SeriesCleanupPref?> prefOf(String id) async =>
        seriesCleanupFromName((await db.libraryItemById(id))!.finishedCleanup);

    Future<void> seedSecondSeries() => db.upsertLibraryItem(
      LibraryItem(
        lifecycle: 'active',
        id: 's2',
        title: 'Bar',
        sourceUrl: 'https://x.example/manga/bar',
        host: 'x.example',
        seriesKey: '/manga/bar',
        createdAt: DateTime(2026, 7, 2),
      ),
    );

    test('a new series has no decision', () async {
      await seedSeries();
      expect(await prefOf('s1'), isNull);
    });

    test('stores, reads back, and resets to undecided', () async {
      await seedSeries();
      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.remove.name);
      expect(await prefOf('s1'), SeriesCleanupPref.remove);

      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.keep.name);
      expect(await prefOf('s1'), SeriesCleanupPref.keep);

      // "Ask again next time" — a null that must actually reach the column.
      await db.setSeriesFinishedCleanup('s1', null);
      expect(await prefOf('s1'), isNull);
    });

    test('each series carries its own, and resets independently', () async {
      await seedSeries();
      await seedSecondSeries();

      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.remove.name);
      await db.setSeriesFinishedCleanup('s2', SeriesCleanupPref.keep.name);
      expect(await prefOf('s1'), SeriesCleanupPref.remove);
      expect(await prefOf('s2'), SeriesCleanupPref.keep);

      await db.setSeriesFinishedCleanup('s1', null);
      expect(await prefOf('s1'), isNull);
      expect(
        await prefOf('s2'),
        SeriesCleanupPref.keep,
        reason: 'resetting one series says nothing about another',
      );
    });

    test('an unknown or empty stored value reads as undecided', () async {
      await seedSeries();
      for (final stored in ['nonsense', '', 'ask', 'REMOVE']) {
        await db.setSeriesFinishedCleanup('s1', stored);
        expect(
          await prefOf('s1'),
          isNull,
          reason: '"$stored" is not a decision; ask rather than guess',
        );
      }
    });

    test('the obsolete global key is not a decision for any series', () async {
      await seedSeries();
      await seedSecondSeries();
      for (final stale in ['remove', 'keep', 'ask', 'nonsense']) {
        await db.setSetting('storage.afterFinished', stale);
        expect(await prefOf('s1'), isNull);
        expect(await prefOf('s2'), isNull);
      }
    });

    test('changing it never touches already-stored chapters', () async {
      await seedSeries();
      final chapter = await seedChapter(1);
      await db.setSeriesFinishedCleanup('s1', SeriesCleanupPref.remove.name);
      // The decision is a rule for future transitions, not a command.
      expect((await db.chapterById(chapter.id))!.contentPath, isNotNull);
      expect(
        Directory(store.resolve(chapter.contentPath!)).existsSync(),
        isTrue,
      );
    });
  });

  group('across a restart', () {
    test('each series keeps its own decision, on disk', () async {
      final file = File(p.join(root.path, 'restart.sqlite'));
      var reopened = AppDatabase.forTesting(NativeDatabase(file));
      for (final (id, title) in [('s1', 'Foo'), ('s2', 'Bar')]) {
        await reopened.upsertLibraryItem(
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
      }
      await reopened.setSeriesFinishedCleanup(
        's1',
        SeriesCleanupPref.remove.name,
      );
      await reopened.setSeriesFinishedCleanup(
        's2',
        SeriesCleanupPref.keep.name,
      );
      await reopened.close();

      // A second process opening the same file — the restart case.
      reopened = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await reopened.libraryItemById('s1'))!.finishedCleanup,
        SeriesCleanupPref.remove.name,
      );
      expect(
        (await reopened.libraryItemById('s2'))!.finishedCleanup,
        SeriesCleanupPref.keep.name,
      );

      await reopened.setSeriesFinishedCleanup('s2', null);
      await reopened.close();

      reopened = AppDatabase.forTesting(NativeDatabase(file));
      expect(
        (await reopened.libraryItemById('s2'))!.finishedCleanup,
        isNull,
        reason: 'a reset survives too — it is a stored null, not a gap',
      );
      await reopened.close();
    });
  });

  group('the global preference model is gone', () {
    /// A stale reader trusts what it finds. These names described an app-wide
    /// cleanup default that no longer exists (D37), so the only safe number of
    /// them in shipping code is zero.
    test('no source file mentions it any more', () {
      const obsolete = [
        'storage.afterFinished',
        'AfterFinishedPref',
        'afterFinishedPrefProvider',
        'setAfterFinishedPref',
        'afterFinishedFromName',
        'kAfterFinishedPrefKey',
        'showAfterFinishedSheet',
        'showFinishedChapterDialog',
        'FinishedChapterChoice',
        "Don't ask again",
        'Ask each time',
        'Remove automatically',
        'After finishing a chapter',
      ];
      // The one legitimate mention left: the migration that deletes the
      // obsolete row names the key it is deleting. Nothing reads it.
      const allowed = {'storage.afterFinished': 'lib/storage/database.dart'};

      final offenders = <String>[];
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        for (final name in obsolete) {
          if (!source.contains(name)) continue;
          if (allowed[name] == file.path) continue;
          offenders.add('${file.path}: $name');
        }
      }
      expect(offenders, isEmpty);
    });

    test('the migration deletes the obsolete row rather than reading it', () {
      final source = File('lib/storage/database.dart').readAsStringSync();
      expect(
        source,
        contains("t.key.equals('storage.afterFinished')"),
        reason: 'the only mention left is the one that removes it',
      );
      expect(
        source.contains("getSetting('storage.afterFinished')") ||
            source.contains("watchSetting('storage.afterFinished')"),
        isFalse,
      );
    });
  });
}

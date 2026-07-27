import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/capture/capture_preflight.dart';
import 'package:web_reader/reading/reading_position.dart';
import 'package:web_reader/reading/reading_repository.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/storage/manifest.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late FileStore store;
  late CapturePreflight preflight;

  const chapterUrl = 'https://x.example/manga/foo/883';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_dup');
    store = FileStore(root);
    Directory(
      p.join(root.path, FileStore.libraryFolderName),
    ).createSync(recursive: true);
    Directory(
      p.join(root.path, FileStore.tmpFolderName),
    ).createSync(recursive: true);
    preflight = CapturePreflight(db: db, fileStore: store);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  ChapterManifest manifestFor(
    String chapterId, {
    CaptureStatus status = CaptureStatus.complete,
    int assets = 2,
  }) => ChapterManifest(
    schemaVersion: 1,
    chapterId: chapterId,
    libraryItemId: 'series-1',
    sourceUrl: chapterUrl,
    title: 'Foo 883',
    capturedAt: DateTime(2026, 7, 20),
    status: status,
    detectedImageCount: assets,
    storedImageCount: assets,
    sequence: 1,
    assets: [
      for (var i = 1; i <= assets; i++)
        AssetEntry(
          index: i,
          sourceUrl: 'https://cdn.example/$i.png',
          status: AssetStatus.stored,
          relativePath: 'assets/${i.toString().padLeft(3, '0')}.png',
        ),
    ],
  );

  Future<String> seedCaptured({
    String status = 'complete',
    bool withFiles = true,
    String chapterId = 'c1',
  }) async {
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

    String? relative;
    if (withFiles) {
      final staging = await store.beginChapter(
        libraryItemId: 'series-1',
        chapterId: chapterId,
      );
      await staging.assetFile('001.png').writeAsBytes([1, 2, 3, 4]);
      await staging.assetFile('002.png').writeAsBytes([5, 6, 7, 8]);
      relative = await store.commit(staging, manifestFor(chapterId));
    } else {
      relative = FileStore.chapterRelativePath('series-1', chapterId);
    }

    await db.upsertChapter(
      Chapter(
        id: chapterId,
        libraryItemId: 'series-1',
        title: 'Foo 883',
        sourceUrl: chapterUrl,
        urlKey: chapterUrl,
        captureStatus: status,
        contentPath: relative,
        capturedAt: DateTime(2026, 7, 20),
        detectedImageCount: 2,
        storedImageCount: status == 'partial' ? 1 : 2,
        sequence: 1,
        byteSize: 8,
        readStatus: 'unread',
        progressFraction: 0,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
      ),
    );
    return relative;
  }

  group('job self-collision', _selfCollisionTests);

  group('preflight classification', () {
    test('a chapter never seen is free to capture', () async {
      final result = await preflight.inspect(chapterUrl);
      expect(result.state, ChapterLocalState.none);
      expect(result.needsUserDecision, isFalse);
    });

    test('a complete chapter prompts rather than silently skipping', () async {
      await seedCaptured();
      final result = await preflight.inspect(chapterUrl);

      expect(result.state, ChapterLocalState.complete);
      expect(
        result.needsUserDecision,
        isTrue,
        reason: 'the old behaviour logged "already captured" and did nothing',
      );
      expect(result.chapter, isNotNull);
    });

    test('a partial chapter is distinguished from a complete one', () async {
      await seedCaptured(status: 'partial');
      expect(
        (await preflight.inspect(chapterUrl)).state,
        ChapterLocalState.partial,
      );
    });

    test('a failed chapter is not treated as available', () async {
      await seedCaptured(status: 'failed', withFiles: false);
      expect(
        (await preflight.inspect(chapterUrl)).state,
        ChapterLocalState.failed,
      );
    });

    test(
      'captured in the database but missing on disk is its own state',
      () async {
        await seedCaptured(withFiles: false);
        final result = await preflight.inspect(chapterUrl);

        expect(result.state, ChapterLocalState.filesMissing);
        expect(
          result.existsLocally,
          isFalse,
          reason: 'must never be reported as safely available offline',
        );
      },
    );

    test(
      'a chapter owned by an unfinished job blocks a second capture',
      () async {
        await seedCaptured();
        await db.upsertJob(
          CaptureJob(
            rangeMode: 'fixedCount',
            id: 'job-1',
            startUrl: chapterUrl,
            currentUrl: chapterUrl,
            requestedChapters: 3,
            completedChapters: 1,
            state: 'downloading',
            visitedUrls: chapterUrl,
            createdAt: DateTime(2026, 7, 20),
            updatedAt: DateTime(2026, 7, 20),
          ),
        );

        final result = await preflight.inspect(chapterUrl);
        expect(result.state, ChapterLocalState.inActiveJob);
        expect(result.blockingJob!.id, 'job-1');
        expect(
          result.shouldCaptureUnder(DuplicatePolicy.replaceAll),
          isFalse,
          reason: 'two jobs on one chapter would fight over the same files',
        );
      },
    );
  });

  group('duplicate policy', () {
    ChapterPreflight of(ChapterLocalState state) =>
        ChapterPreflight(state: state, url: chapterUrl);

    test('skipComplete leaves saved chapters alone but fixes broken ones', () {
      const policy = DuplicatePolicy.skipComplete;
      expect(
        of(ChapterLocalState.complete).shouldCaptureUnder(policy),
        isFalse,
      );
      expect(of(ChapterLocalState.partial).shouldCaptureUnder(policy), isFalse);
      expect(of(ChapterLocalState.failed).shouldCaptureUnder(policy), isTrue);
      expect(
        of(ChapterLocalState.filesMissing).shouldCaptureUnder(policy),
        isTrue,
      );
      expect(of(ChapterLocalState.none).shouldCaptureUnder(policy), isTrue);
    });

    test('retryPartial also re-attempts incomplete chapters', () {
      const policy = DuplicatePolicy.retryPartial;
      expect(of(ChapterLocalState.partial).shouldCaptureUnder(policy), isTrue);
      expect(
        of(ChapterLocalState.complete).shouldCaptureUnder(policy),
        isFalse,
      );
    });

    test('replaceAll re-captures even complete chapters', () {
      const policy = DuplicatePolicy.replaceAll;
      expect(of(ChapterLocalState.complete).shouldCaptureUnder(policy), isTrue);
      expect(of(ChapterLocalState.partial).shouldCaptureUnder(policy), isTrue);
    });
  });

  group('range preview', () {
    test('summarises what is already saved across a known chain', () async {
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
      for (var n = 1; n <= 2; n++) {
        await db.upsertChapter(
          Chapter(
            id: 'c$n',
            libraryItemId: 'series-1',
            title: 'Foo $n',
            sourceUrl: 'https://x.example/manga/foo/$n',
            urlKey: 'https://x.example/manga/foo/$n',
            captureStatus: n == 2 ? 'partial' : 'complete',
            contentPath: 'library/series-1/chapters/c$n',
            capturedAt: DateTime(2026, 7, 20),
            detectedImageCount: 2,
            storedImageCount: n == 2 ? 1 : 2,
            nextSourceUrl: 'https://x.example/manga/foo/${n + 1}',
            sequence: n,
            byteSize: 8,
            readStatus: 'unread',
            progressFraction: 0,
            progressImageIndex: 0,
            progressOffsetInImage: 0,
          ),
        );
        Directory(
          store.resolve('library/series-1/chapters/c$n'),
        ).createSync(recursive: true);
      }

      final range = await preflight.inspectRange(
        'https://x.example/manga/foo/1',
        5,
      );

      expect(range.savedCount, 1);
      expect(range.partialCount, 1);
      expect(range.newCount, 3);
      expect(range.hasExisting, isTrue);
      expect(range.lines.join(' '), contains('already saved'));
      expect(
        range.knownCount,
        lessThan(5),
        reason: 'the rest is only discoverable by visiting each page',
      );
    });

    test('a fresh series previews as entirely new', () async {
      final range = await preflight.inspectRange(chapterUrl, 3);
      expect(range.hasExisting, isFalse);
      expect(range.newCount, 3);
    });
  });

  group('safe replacement', () {
    test('keeps the previous copy until the new one lands', () async {
      final relative = await seedCaptured();
      final original = await store
          .assetFile(relative, 'assets/001.png')
          .readAsBytes();

      final staging = await store.beginChapter(
        libraryItemId: 'series-1',
        chapterId: 'c1',
      );
      await staging.assetFile('001.png').writeAsBytes([9, 9, 9, 9]);
      await staging.assetFile('002.png').writeAsBytes([8, 8, 8, 8]);
      await store.commitReplacing(staging, manifestFor('c1'));

      final replaced = await store
          .assetFile(relative, 'assets/001.png')
          .readAsBytes();
      expect(replaced, isNot(original));
      expect(
        Directory('${store.resolve(relative)}.previous').existsSync(),
        isFalse,
        reason: 'the backup is cleaned up once the replacement succeeds',
      );
    });

    test('a failed replacement leaves the old chapter readable', () async {
      final relative = await seedCaptured();
      final original = await store
          .assetFile(relative, 'assets/001.png')
          .readAsBytes();

      // Staging that cannot be committed: the directory is gone.
      final staging = await store.beginChapter(
        libraryItemId: 'series-1',
        chapterId: 'c1',
      );
      staging.dir.deleteSync(recursive: true);

      await expectLater(
        store.commitReplacing(staging, manifestFor('c1')),
        throwsA(anything),
      );

      expect(
        store.chapterExists(relative),
        isTrue,
        reason: 'a failed re-download must not cost a readable chapter',
      );
      expect(
        await store.assetFile(relative, 'assets/001.png').readAsBytes(),
        original,
      );
      expect(await store.readManifest(relative), isNotNull);
    });

    test('an interrupted replacement is restored at startup', () async {
      final relative = await seedCaptured();
      final target = Directory(store.resolve(relative));

      // Exactly what a kill between "step aside" and "move in" leaves.
      target.renameSync('${target.path}.previous');
      expect(store.chapterExists(relative), isFalse);

      final restored = await store.restoreInterruptedReplacements();

      expect(restored, 1);
      expect(store.chapterExists(relative), isTrue);
      expect(await store.readManifest(relative), isNotNull);
    });

    test(
      'a leftover backup beside a good chapter is just cleaned up',
      () async {
        final relative = await seedCaptured();
        Directory(
          '${store.resolve(relative)}.previous',
        ).createSync(recursive: true);

        final restored = await store.restoreInterruptedReplacements();

        expect(restored, 0, reason: 'nothing needed restoring');
        expect(store.chapterExists(relative), isTrue);
        expect(
          Directory('${store.resolve(relative)}.previous').existsSync(),
          isFalse,
        );
      },
    );
  });

  group('re-download preserves reading state', () {
    test('progress and completion survive replacing the files', () async {
      await seedCaptured();
      final reading = ReadingRepository(db);
      await reading.saveProgress(
        'c1',
        const ReadingPosition(
          fraction: 0.6,
          imageIndex: 1,
          offsetInImage: 0.25,
        ),
        completed: true,
      );

      final before = (await db.chapterById('c1'))!;

      // What the engine does on a replace: same row, refreshed capture fields,
      // reading fields carried across verbatim.
      await db.upsertChapter(
        before.copyWith(
          capturedAt: Value(DateTime(2026, 8, 1)),
          detectedImageCount: 4,
          storedImageCount: 4,
          byteSize: 4096,
        ),
      );

      final after = (await db.chapterById('c1'))!;
      expect(after.storedImageCount, 4, reason: 'capture metadata refreshed');
      expect(after.readStatus, 'completed');
      expect(after.progressFraction, 1, reason: 'completed reads 100%');
      expect(after.progressImageIndex, 1);
      expect(after.progressOffsetInImage, closeTo(0.25, 0.001));
      expect(after.completedAt, before.completedAt);
    });

    test('replacing does not create a second chapter row', () async {
      await seedCaptured();
      final staging = await store.beginChapter(
        libraryItemId: 'series-1',
        chapterId: 'c1',
      );
      await staging.assetFile('001.png').writeAsBytes([9, 9, 9]);
      await store.commitReplacing(staging, manifestFor('c1'));

      final rows = (await db.allChapters())
          .where((c) => c.urlKey == chapterUrl)
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.id, 'c1');
    });
  });
}

/// Regression: a running job must not collide with itself.
void _selfCollisionTests() {
  late AppDatabase db;
  late Directory root;
  late CapturePreflight preflight;

  const url = 'https://x.example/manga/foo/1';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_self');
    preflight = CapturePreflight(db: db, fileStore: FileStore(root));
  });
  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> seedRunningJob(String id) => db.upsertJob(
    CaptureJob(
      rangeMode: 'fixedCount',
      id: id,
      startUrl: url,
      currentUrl: url,
      requestedChapters: 2,
      completedChapters: 0,
      state: 'inspecting',
      visitedUrls: url,
      createdAt: DateTime(2026, 7, 27),
      updatedAt: DateTime(2026, 7, 27),
    ),
  );

  test('a job does not treat its own row as a competing job', () async {
    await seedRunningJob('job-self');

    final result = await preflight.inspect(url, ignoreJobId: 'job-self');

    expect(
      result.state,
      ChapterLocalState.none,
      reason:
          'the running job persists its own state before the first '
          'preflight; seeing that as a collision made every capture skip '
          'the chapter it was asked to capture',
    );
    expect(result.shouldCaptureUnder(DuplicatePolicy.skipComplete), isTrue);
  });

  test('a genuinely different job still blocks', () async {
    await seedRunningJob('job-other');

    final result = await preflight.inspect(url, ignoreJobId: 'job-mine');

    expect(result.state, ChapterLocalState.inActiveJob);
    expect(result.blockingJob!.id, 'job-other');
  });

  test('with no job id supplied, any unfinished job blocks', () async {
    await seedRunningJob('job-other');
    expect((await preflight.inspect(url)).state, ChapterLocalState.inActiveJob);
  });
}

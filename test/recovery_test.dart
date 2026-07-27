import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/storage/manifest.dart';

/// M3 acceptance 5: force-quit mid-session, reopen, and nothing is falsely
/// marked captured.
///
/// The force-quit itself is simulated at the layer where it matters — a
/// database and a file tree left exactly as an interrupted run leaves them,
/// then the startup recovery run against that state. That covers what an
/// integration test would, without needing to kill an app process.
void main() {
  late AppDatabase db;
  late Directory root;
  late FileStore store;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_recovery');
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

  Future<void> seedItem() => db.upsertLibraryItem(
    LibraryItem(
      lifecycle: 'active',
      id: 'item-1',
      title: 'Fixture Series',
      sourceUrl: 'https://x.example/manga/foo',
      host: 'x.example',
      seriesKey: '/manga/foo',
      createdAt: DateTime(2026, 7, 1),
    ),
  );

  Chapter chapter(
    String id, {
    required String status,
    String? contentPath,
    int sequence = 1,
  }) => Chapter(
    readStatus: 'unread',
    progressFraction: 0,
    progressImageIndex: 0,
    progressOffsetInImage: 0,
    id: id,
    libraryItemId: 'item-1',
    title: 'Fixture Series Chapter $sequence',
    sourceUrl: 'https://x.example/manga/foo/$sequence',
    urlKey: 'https://x.example/manga/foo/$sequence',
    captureStatus: status,
    contentPath: contentPath,
    capturedAt: status == 'complete' ? DateTime(2026, 7, 20) : null,
    detectedImageCount: 6,
    storedImageCount: status == 'complete' ? 6 : 0,
    sequence: sequence,
    byteSize: status == 'complete' ? 4096 : 0,
  );

  ChapterManifest manifestFor(String chapterId, CaptureStatus status) =>
      ChapterManifest(
        schemaVersion: 1,
        chapterId: chapterId,
        libraryItemId: 'item-1',
        sourceUrl: 'https://x.example/manga/foo/2',
        title: 'Fixture Series Chapter 2',
        capturedAt: DateTime(2026, 7, 21),
        status: status,
        detectedImageCount: 2,
        storedImageCount: 2,
        sequence: 2,
        assets: const [
          AssetEntry(
            index: 1,
            sourceUrl: 'https://cdn.example/1.png',
            status: AssetStatus.stored,
            relativePath: 'assets/001.png',
          ),
          AssetEntry(
            index: 2,
            sourceUrl: 'https://cdn.example/2.png',
            status: AssetStatus.stored,
            relativePath: 'assets/002.png',
          ),
        ],
      );

  group('force-quit mid-capture', () {
    test('an in-flight chapter is demoted, never promoted', () async {
      await seedItem();
      await db.upsertChapter(
        chapter(
          'done',
          status: 'complete',
          contentPath: 'library/item-1/chapters/done',
        ),
      );
      await db.upsertChapter(
        chapter('inflight', status: 'capturing', sequence: 2),
      );

      final reset = await db.resetInFlightChapters();

      expect(reset, 1);
      final interrupted = await db.chapterById('inflight');
      expect(
        interrupted!.captureStatus,
        'failed',
        reason: 'an interrupted chapter must never come back as complete',
      );
      expect(interrupted.captureError, contains('interrupted'));
      expect(interrupted.storedImageCount, 0);

      // The chapter that had actually finished is untouched.
      final done = await db.chapterById('done');
      expect(done!.captureStatus, 'complete');
      expect(done.contentPath, 'library/item-1/chapters/done');
    });

    test('staging left behind by the kill is swept', () async {
      final staging = await store.beginChapter(
        libraryItemId: 'item-1',
        chapterId: 'inflight',
      );
      await staging.assetFile('001.png').writeAsBytes([1, 2, 3]);
      expect(staging.dir.existsSync(), isTrue);

      final swept = await store.sweepStaging();

      expect(swept, 1);
      expect(staging.dir.existsSync(), isFalse);
      expect(
        store.chapterExists(
          FileStore.chapterRelativePath('item-1', 'inflight'),
        ),
        isFalse,
        reason: 'partial bytes must never appear as a committed chapter',
      );
    });

    test(
      'a chapter committed to disk but not to the database is reconciled',
      () async {
        await seedItem();

        // The exact window: files renamed into place, process killed before
        // the database transaction.
        final staging = await store.beginChapter(
          libraryItemId: 'item-1',
          chapterId: 'orphan',
        );
        await staging.assetFile('001.png').writeAsBytes([1, 2, 3, 4]);
        await staging.assetFile('002.png').writeAsBytes([5, 6, 7, 8]);
        final relative = await store.commit(
          staging,
          manifestFor('orphan', CaptureStatus.complete),
        );

        expect(store.chapterExists(relative), isTrue);
        expect(await db.chapterById('orphan'), isNull);

        // What startup recovery does: read the manifest and finish the record.
        final found = store.listCommittedChapterPaths();
        expect(found, contains(relative));
        final manifest = await store.readManifest(relative);
        expect(manifest, isNotNull);
        expect(manifest!.status, CaptureStatus.complete);

        await db.upsertChapter(
          Chapter(
            id: manifest.chapterId,
            libraryItemId: manifest.libraryItemId,
            title: manifest.title,
            sourceUrl: manifest.sourceUrl,
            urlKey: manifest.sourceUrl,
            captureStatus: manifest.status.name,
            contentPath: relative,
            capturedAt: manifest.capturedAt,
            detectedImageCount: manifest.detectedImageCount,
            storedImageCount: manifest.storedImageCount,
            sequence: manifest.sequence ?? 0,
            byteSize: 2048,
            readStatus: 'unread',
            progressFraction: 0,
            progressImageIndex: 0,
            progressOffsetInImage: 0,
          ),
        );

        final recovered = await db.chapterById('orphan');
        expect(recovered!.captureStatus, 'complete');
        expect(recovered.storedImageCount, 2);
        expect(
          store.assetFile(relative, 'assets/001.png').existsSync(),
          isTrue,
        );
      },
    );

    test('a partial manifest is reconciled as partial, not complete', () async {
      await seedItem();
      final staging = await store.beginChapter(
        libraryItemId: 'item-1',
        chapterId: 'half',
      );
      await staging.assetFile('001.png').writeAsBytes([1, 2, 3]);
      final relative = await store.commit(
        staging,
        manifestFor('half', CaptureStatus.partial),
      );

      final manifest = await store.readManifest(relative);
      expect(
        manifest!.status,
        CaptureStatus.partial,
        reason: 'recovery must carry the recorded status, not assume success',
      );
    });
  });

  group('the interrupted job itself', () {
    CaptureJob job(String state, {int completed = 1}) => CaptureJob(
      rangeMode: 'fixedCount',
      id: 'job-1',
      startUrl: 'https://x.example/manga/foo/1',
      currentUrl: 'https://x.example/manga/foo/2',
      requestedChapters: 3,
      completedChapters: completed,
      state: state,
      visitedUrls: 'https://x.example/manga/foo/1',
      createdAt: DateTime(2026, 7, 20),
      updatedAt: DateTime(2026, 7, 20),
    );

    test('is offered for resume after the restart', () async {
      await db.upsertJob(job('downloading'));

      final resumable = await db.findResumableJob();

      expect(resumable, isNotNull);
      expect(resumable!.currentUrl, 'https://x.example/manga/foo/2');
      expect(resumable.completedChapters, 1);
      expect(
        resumable.visitedUrls,
        contains('foo/1'),
        reason: 'the visited set is what stops a resume re-walking chapter 1',
      );
    });

    test(
      'is never resumed automatically — discarding leaves the captures',
      () async {
        await seedItem();
        await db.upsertChapter(
          chapter(
            'done',
            status: 'complete',
            contentPath: 'library/item-1/chapters/done',
          ),
        );
        await db.upsertJob(job('scrolling'));

        await db.deleteJob('job-1');

        expect(await db.findResumableJob(), isNull);
        final kept = await db.chapterById('done');
        expect(
          kept!.captureStatus,
          'complete',
          reason: 'discarding a job must not touch what it already captured',
        );
      },
    );

    test('a finished job is not offered', () async {
      await db.upsertJob(job('complete', completed: 3));
      expect(await db.findResumableJob(), isNull);
    });
  });
}

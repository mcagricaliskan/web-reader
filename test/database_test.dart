import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/storage/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  LibraryItem item(String id) => LibraryItem(
    lifecycle: 'active',
    id: id,
    title: 'Fixture Webtoon',
    sourceUrl: 'http://localhost:8099/chapter',
    host: 'localhost',
    createdAt: DateTime(2026, 7, 25),
  );

  Chapter chapter(
    String id,
    String itemId, {
    int sequence = 1,
    String status = 'complete',
    String? urlKey,
  }) => Chapter(
    readStatus: 'unread',
    progressFraction: 0,
    progressImageIndex: 0,
    progressOffsetInImage: 0,
    id: id,
    libraryItemId: itemId,
    title: 'Chapter $sequence',
    sourceUrl: 'http://localhost:8099/chapter/$sequence',
    urlKey: urlKey ?? 'http://localhost:8099/chapter/$sequence',
    captureStatus: status,
    contentPath: 'library/$itemId/chapters/$id',
    capturedAt: DateTime(2026, 7, 25, 12, sequence),
    detectedImageCount: 6,
    storedImageCount: 6,
    sequence: sequence,
    byteSize: 1024,
  );

  test('insert and read back a library item', () async {
    await db.upsertLibraryItem(item('item-1'));

    final found = await db.findLibraryItemBySourceUrl(
      'http://localhost:8099/chapter',
    );
    expect(found, isNotNull);
    expect(found!.title, 'Fixture Webtoon');
    expect(found.host, 'localhost');
  });

  test('chapters are returned in capture-chain order', () async {
    await db.upsertLibraryItem(item('item-1'));
    // Insert out of order on purpose.
    await db.upsertChapter(chapter('c3', 'item-1', sequence: 3));
    await db.upsertChapter(chapter('c1', 'item-1', sequence: 1));
    await db.upsertChapter(chapter('c2', 'item-1', sequence: 2));

    final chapters = await db.chaptersForItem('item-1');
    expect(chapters.map((c) => c.sequence), [1, 2, 3]);
    expect(chapters.map((c) => c.id), ['c1', 'c2', 'c3']);
  });

  test('the same urlKey cannot be captured twice for one item', () async {
    await db.upsertLibraryItem(item('item-1'));
    await db.upsertChapter(chapter('c1', 'item-1', sequence: 1));

    final duplicate = chapter(
      'c-other',
      'item-1',
      sequence: 9,
    ).copyWith(urlKey: 'http://localhost:8099/chapter/1');

    await expectLater(db.upsertChapter(duplicate), throwsA(isA<Exception>()));
  });

  test('findChapterByUrlKey locates an existing capture', () async {
    await db.upsertLibraryItem(item('item-1'));
    await db.upsertChapter(chapter('c1', 'item-1', sequence: 1));

    final found = await db.findChapterByUrlKey(
      'item-1',
      'http://localhost:8099/chapter/1',
    );
    expect(found?.id, 'c1');

    final missing = await db.findChapterByUrlKey(
      'item-1',
      'http://localhost:8099/nope',
    );
    expect(missing, isNull);
  });

  test(
    'resetInFlightChapters demotes interrupted captures, never promotes',
    () async {
      await db.upsertLibraryItem(item('item-1'));
      await db.upsertChapter(chapter('c1', 'item-1', sequence: 1));
      await db.upsertChapter(
        chapter('c2', 'item-1', sequence: 2, status: 'capturing'),
      );

      final reset = await db.resetInFlightChapters();
      expect(reset, 1);

      final interrupted = await db.chapterById('c2');
      expect(interrupted!.captureStatus, 'failed');
      expect(interrupted.captureError, contains('interrupted'));

      // The already-complete chapter is untouched.
      final done = await db.chapterById('c1');
      expect(done!.captureStatus, 'complete');
    },
  );

  test('markChapterContentMissing keeps the row but drops the path', () async {
    await db.upsertLibraryItem(item('item-1'));
    await db.upsertChapter(chapter('c1', 'item-1', sequence: 1));

    await db.markChapterContentMissing('c1');

    final row = await db.chapterById('c1');
    expect(row, isNotNull, reason: 'history must survive missing files');
    expect(row!.contentPath, isNull);
    expect(row.captureStatus, 'failed');
  });

  test('watchAllChapters emits when a chapter commits', () async {
    await db.upsertLibraryItem(item('item-1'));

    final emissions = <int>[];
    final sub = db.watchAllChapters().listen((rows) {
      emissions.add(rows.length);
    });

    await db.upsertChapter(chapter('c1', 'item-1', sequence: 1));
    await pumpEventQueue();
    await db.upsertChapter(chapter('c2', 'item-1', sequence: 2));
    await pumpEventQueue();
    await sub.cancel();

    expect(emissions.last, 2);
  });

  group('capture jobs', () {
    CaptureJob job(String id, String state, {int completed = 0}) => CaptureJob(
      rangeMode: 'fixedCount',
      id: id,
      startUrl: 'http://localhost:8099/chapter/1',
      currentUrl: 'http://localhost:8099/chapter/2',
      requestedChapters: 3,
      completedChapters: completed,
      state: state,
      visitedUrls: 'http://localhost:8099/chapter/1',
      createdAt: DateTime(2026, 7, 25),
      updatedAt: DateTime(2026, 7, 25),
    );

    test('an interrupted job is resumable, a finished one is not', () async {
      await db.upsertJob(job('j1', 'complete', completed: 3));
      expect(await db.findResumableJob(), isNull);

      await db.upsertJob(job('j2', 'downloading', completed: 1));
      final resumable = await db.findResumableJob();
      expect(resumable?.id, 'j2');
      expect(resumable?.completedChapters, 1);
      expect(resumable?.visitedUrls, contains('chapter/1'));
    });

    test('cancelled and failed jobs are not offered for resume', () async {
      await db.upsertJob(job('j-cancelled', 'cancelled'));
      await db.upsertJob(job('j-failed', 'failed'));
      expect(await db.findResumableJob(), isNull);
    });

    test('deleting a job removes it from the resume list', () async {
      await db.upsertJob(job('j1', 'scrolling'));
      expect(await db.findResumableJob(), isNotNull);
      await db.deleteJob('j1');
      expect(await db.findResumableJob(), isNull);
    });
  });
}

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/features/chapter_actions.dart';
import 'package:web_reader/library/series_repository.dart';
import 'package:web_reader/reading/reading_position.dart';
import 'package:web_reader/reading/reading_repository.dart';
import 'package:web_reader/storage/cleanup.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

/// A chapter's source URL is durable metadata: it is what "Open on website"
/// and "Capture again" both stand on, and it must outlive the files.
void main() {
  late AppDatabase db;
  late Directory root;
  late FileStore store;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_srcurl');
    store = FileStore(root);
  });
  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  const url = 'https://x.example/manga/foo/12';

  Future<void> seedSeries() => db.upsertLibraryItem(
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

  /// A chapter as capture leaves it: files on disk, source URL recorded.
  Future<void> seedCaptured({String sourceUrl = url}) async {
    final dir = Directory('${root.path}/library/series-1/chapters/c1')
      ..createSync(recursive: true);
    File('${dir.path}/001.png').writeAsBytesSync(List.filled(64, 7));
    await db.upsertChapter(
      Chapter(
        id: 'c1',
        libraryItemId: 'series-1',
        title: 'Foo Chapter 12',
        sourceUrl: sourceUrl,
        urlKey: sourceUrl,
        captureStatus: 'complete',
        contentPath: 'library/series-1/chapters/c1',
        capturedAt: DateTime(2026, 7, 20),
        detectedImageCount: 1,
        storedImageCount: 1,
        sequence: 12,
        byteSize: 64,
        chapterNumber: 12,
        chapterLabel: 'Chapter 12',
        readStatus: 'unread',
        progressFraction: 0,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
      ),
    );
  }

  test('a captured chapter stores the page it came from', () async {
    await seedSeries();
    await seedCaptured();

    final chapter = (await db.chapterById('c1'))!;
    expect(chapter.sourceUrl, url);
    expect(hasUsableSourceUrl(chapter), isTrue);
  });

  test('a discovered remote chapter stores its URL too', () async {
    await seedSeries();
    // What the update checker writes: metadata only, no files, but the
    // address is the whole point of the row.
    await db.upsertChapter(
      Chapter(
        id: 'c2',
        libraryItemId: 'series-1',
        title: 'Foo Chapter 13',
        sourceUrl: 'https://x.example/manga/foo/13',
        urlKey: 'https://x.example/manga/foo/13',
        captureStatus: 'knownRemote',
        detectedImageCount: 0,
        storedImageCount: 0,
        sequence: 13,
        byteSize: 0,
        chapterNumber: 13,
        chapterLabel: 'Chapter 13',
        readStatus: 'unread',
        progressFraction: 0,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
        discoveredAt: DateTime(2026, 7, 26),
        discoveryBasis: 'chapterList',
      ),
    );

    final chapter = (await db.chapterById('c2'))!;
    expect(chapter.contentPath, isNull, reason: 'metadata only');
    expect(chapter.sourceUrl, 'https://x.example/manga/foo/13');
    expect(hasUsableSourceUrl(chapter), isTrue);
    expect(isReadableOffline(chapter), isFalse);
  });

  test('removing offline files keeps every piece of metadata', () async {
    await seedSeries();
    await seedCaptured();
    // Give it a reading history and a discovery trail worth losing.
    final reading = ReadingRepository(db);
    await reading.saveProgress(
      'c1',
      const ReadingPosition(fraction: 0.6, imageIndex: 1, offsetInImage: 0.2),
      completed: true,
    );
    await db.writeChapterReading(
      'c1',
      const ChaptersCompanion(
        discoveryBasis: Value('chapterList'),
        discoveryConfidence: Value('high'),
      ),
    );

    final before = (await db.chapterById('c1'))!;
    await CleanupService(db: db, fileStore: store).removeOfflineNow(['c1']);
    final after = (await db.chapterById('c1'))!;

    expect(after.contentPath, isNull, reason: 'the files are the only loss');
    expect(after.offlineRemovedAt, isNotNull);

    expect(after.sourceUrl, url);
    expect(after.urlKey, before.urlKey);
    expect(after.chapterLabel, 'Chapter 12');
    expect(after.chapterNumber, 12);
    expect(after.libraryItemId, 'series-1');
    expect(after.readStatus, 'completed');
    expect(after.progressFraction, 1);
    expect(after.progressImageIndex, 1);
    expect(after.completedAt, before.completedAt);
    expect(after.discoveryBasis, before.discoveryBasis);
    expect(after.discoveryConfidence, before.discoveryConfidence);
  });

  test('a removed chapter stays listed, as a known chapter', () async {
    await seedSeries();
    await seedCaptured();
    await CleanupService(db: db, fileStore: store).removeOfflineNow(['c1']);

    final chapters = await db.chaptersForItem('series-1');
    expect(chapters, hasLength(1), reason: 'still in the series list');
    expect(isReadableOffline(chapters.single), isFalse);
    expect(hasUsableSourceUrl(chapters.single), isTrue);
  });

  test('re-downloading keeps the same source identity', () async {
    await seedSeries();
    await seedCaptured();
    await CleanupService(db: db, fileStore: store).removeOfflineNow(['c1']);

    // The engine re-commits the same row, refreshing capture fields only.
    final removed = (await db.chapterById('c1'))!;
    await db.upsertChapter(
      removed.copyWith(
        captureStatus: 'complete',
        contentPath: const Value('library/series-1/chapters/c1'),
        byteSize: 128,
        storedImageCount: 1,
        capturedAt: Value(DateTime(2026, 8, 1)),
      ),
    );
    await db.clearOfflineRemovedMark('c1');

    final after = (await db.chapterById('c1'))!;
    expect(after.sourceUrl, url, reason: 'same chapter, same address');
    expect(after.urlKey, removed.urlKey);
    expect(after.offlineRemovedAt, isNull);
    expect(after.readStatus, 'unread');
  });

  group('missing source URLs', () {
    test('a blank URL is not usable, and is never navigated to', () async {
      await seedSeries();
      await seedCaptured(sourceUrl: '');
      expect(hasUsableSourceUrl((await db.chapterById('c1'))!), isFalse);
    });

    test('a URL with no scheme or host is not usable either', () async {
      await seedSeries();
      await seedCaptured(sourceUrl: '/manga/foo/12');
      expect(hasUsableSourceUrl((await db.chapterById('c1'))!), isFalse);
    });

    test('the repair restores it from the stored url key', () async {
      await seedSeries();
      await seedCaptured();
      // What an older build could leave behind: the row, minus its address.
      await db.writeChapterSource('c1', '');
      expect(hasUsableSourceUrl((await db.chapterById('c1'))!), isFalse);

      final fixed = await SeriesRepository(db).repairChapterSourceUrls();
      expect(fixed, 1);
      expect((await db.chapterById('c1'))!.sourceUrl, url);

      expect(
        await SeriesRepository(db).repairChapterSourceUrls(),
        0,
        reason: 'idempotent',
      );
    });

    test('nothing is invented when there is nothing to repair from', () async {
      await seedSeries();
      // Neither an address nor a key: the row simply cannot say where it came
      // from, and guessing is worse than admitting it.
      await db.upsertChapter(
        Chapter(
          id: 'c9',
          libraryItemId: 'series-1',
          title: 'Orphan',
          sourceUrl: '',
          urlKey: '',
          captureStatus: 'complete',
          contentPath: 'library/series-1/chapters/c9',
          detectedImageCount: 1,
          storedImageCount: 1,
          sequence: 9,
          byteSize: 1,
          readStatus: 'unread',
          progressFraction: 0,
          progressImageIndex: 0,
          progressOffsetInImage: 0,
        ),
      );

      expect(await SeriesRepository(db).repairChapterSourceUrls(), 0);
      expect((await db.chapterById('c9'))!.sourceUrl, '');
    });
  });
}

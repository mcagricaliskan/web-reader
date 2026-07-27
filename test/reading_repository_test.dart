import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/reading/reading_position.dart';
import 'package:web_reader/reading/reading_repository.dart';
import 'package:web_reader/storage/database.dart';

void main() {
  late AppDatabase db;
  late ReadingRepository reading;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reading = ReadingRepository(db);
  });
  tearDown(() => db.close());

  Future<void> seed({int chapters = 3, String status = 'complete'}) async {
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
    for (var n = 1; n <= chapters; n++) {
      await db.upsertChapter(
        Chapter(
          id: 'c$n',
          libraryItemId: 'series-1',
          title: 'Fixture Series Chapter $n',
          sourceUrl: 'https://x.example/manga/foo/$n',
          urlKey: 'https://x.example/manga/foo/$n',
          captureStatus: status,
          contentPath: 'library/series-1/chapters/c$n',
          capturedAt: DateTime(2026, 7, 20),
          detectedImageCount: 6,
          storedImageCount: 6,
          sequence: n,
          byteSize: 1024,
          chapterNumber: n.toDouble(),
          chapterLabel: 'Chapter $n',
          readStatus: 'unread',
          progressFraction: 0,
          progressImageIndex: 0,
          progressOffsetInImage: 0,
        ),
      );
    }
  }

  group('opening a chapter', () {
    test('records that it was opened but does not mark it read', () async {
      await seed();
      await reading.markOpened('c1');

      final chapter = await db.chapterById('c1');
      expect(chapter!.readStatus, ReadStatus.inProgress.name);
      expect(chapter.firstOpenedAt, isNotNull);
      expect(chapter.lastReadAt, isNotNull);
      expect(
        chapter.completedAt,
        isNull,
        reason: 'glancing at a chapter is not finishing it',
      );
    });

    test('reopening a completed chapter leaves it completed', () async {
      await seed();
      await reading.markRead('c1');
      await reading.markOpened('c1');

      final chapter = await db.chapterById('c1');
      expect(chapter!.readStatus, ReadStatus.completed.name);
    });

    test('updates the series pointers', () async {
      await seed();
      await reading.markOpened('c2');

      final series = (await db.libraryItemById('series-1'))!;
      expect(series.lastOpenedChapterId, 'c2');
      expect(series.lastReadAt, isNotNull);
    });
  });

  group('saving progress', () {
    test('stores the anchor and the fraction together', () async {
      await seed();
      await reading.saveProgress(
        'c1',
        const ReadingPosition(
          fraction: 0.42,
          imageIndex: 3,
          offsetInImage: 0.25,
        ),
      );

      final chapter = await db.chapterById('c1');
      expect(chapter!.progressFraction, closeTo(0.42, 0.001));
      expect(chapter.progressImageIndex, 3);
      expect(chapter.progressOffsetInImage, closeTo(0.25, 0.001));
      expect(chapter.readStatus, ReadStatus.inProgress.name);
      expect(chapter.progressUpdatedAt, isNotNull);
    });

    test('completes when told to, and records when', () async {
      await seed();
      await reading.saveProgress(
        'c1',
        const ReadingPosition(fraction: 0.98, imageIndex: 5),
        completed: true,
      );

      final chapter = await db.chapterById('c1');
      expect(chapter!.readStatus, ReadStatus.completed.name);
      expect(chapter.completedAt, isNotNull);
    });

    test(
      'a completed chapter keeps its completion when scrolled again',
      () async {
        await seed();
        await reading.markRead('c1');
        final firstCompletion = (await db.chapterById('c1'))!.completedAt;

        await reading.saveProgress(
          'c1',
          const ReadingPosition(fraction: 0.2, imageIndex: 1),
        );

        final chapter = await db.chapterById('c1');
        expect(chapter!.readStatus, ReadStatus.completed.name);
        expect(chapter.completedAt, firstCompletion);
        expect(
          chapter.progressImageIndex,
          1,
          reason: 'the anchor still tracks where they actually are',
        );
        expect(
          chapter.progressFraction,
          1,
          reason: 'a finished chapter reads 100%, wherever the scroll is',
        );
      },
    );

    test('progress survives being read back after a reopen', () async {
      await seed();
      await reading.saveProgress(
        'c1',
        const ReadingPosition(fraction: 0.5, imageIndex: 2, offsetInImage: 0.5),
      );

      // What a restart looks like: a fresh repository over the same rows.
      final reloaded = ReadingRepository(db);
      final position = reloaded.positionOf((await db.chapterById('c1'))!);

      expect(position.fraction, closeTo(0.5, 0.001));
      expect(position.imageIndex, 2);
      expect(position.offsetInImage, closeTo(0.5, 0.001));
    });
  });

  group('mark read and unread', () {
    test('mark read completes it and fills the bar', () async {
      await seed();
      await reading.markRead('c1');

      final chapter = await db.chapterById('c1');
      expect(chapter!.readStatus, ReadStatus.completed.name);
      expect(chapter.progressFraction, 1.0);
      expect(chapter.completedAt, isNotNull);
    });

    test('mark unread keeps the position so it can be resumed', () async {
      await seed();
      await reading.saveProgress(
        'c1',
        const ReadingPosition(fraction: 0.6, imageIndex: 3, offsetInImage: 0.4),
        completed: true,
      );
      await reading.markUnread('c1');

      final chapter = await db.chapterById('c1');
      expect(chapter!.readStatus, ReadStatus.unread.name);
      expect(chapter.completedAt, isNull);
      expect(
        chapter.progressImageIndex,
        3,
        reason: 'unread means unfinished, not never-visited',
      );
      expect(chapter.progressOffsetInImage, closeTo(0.4, 0.001));
      expect(
        chapter.progressFraction,
        0,
        reason: 'completion had forced the bar to 100%; unread empties it '
            'again rather than leaving a full bar on an unread chapter',
      );
    });

    test('marking unread moves the series pointer back', () async {
      await seed();
      await reading.markRead('c1');
      expect(
        (await db.libraryItemById('series-1'))!.lastCompletedChapterId,
        'c1',
      );

      await reading.markUnread('c1');
      expect(
        (await db.libraryItemById('series-1'))!.lastCompletedChapterId,
        isNull,
      );
    });
  });

  group('series reading state', () {
    test(
      'an untouched series has a next chapter but nothing in progress',
      () async {
        await seed();
        final state = computeSeriesReadingState(
          await db.chaptersForItem('series-1'),
        );

        expect(state.currentChapter, isNull);
        expect(state.nextUnread!.id, 'c1');
        expect(state.continueChapter!.id, 'c1');
        expect(state.everOpened, isFalse);
      },
    );

    test('a partly read chapter is the one to continue', () async {
      await seed();
      await reading.saveProgress('c1', const ReadingPosition(fraction: 0.5));

      final state = computeSeriesReadingState(
        await db.chaptersForItem('series-1'),
      );
      expect(state.currentChapter!.id, 'c1');
      expect(state.continueChapter!.id, 'c1');
    });

    test('completing one advances to the next unread', () async {
      await seed();
      await reading.markRead('c1');

      final state = computeSeriesReadingState(
        await db.chaptersForItem('series-1'),
      );
      expect(state.currentChapter, isNull);
      expect(state.continueChapter!.id, 'c2');
      expect(state.lastCompleted!.id, 'c1');
    });

    test('completing everything leaves nothing to continue', () async {
      await seed();
      for (final id in ['c1', 'c2', 'c3']) {
        await reading.markRead(id);
      }

      final state = computeSeriesReadingState(
        await db.chaptersForItem('series-1'),
      );
      expect(state.allCompleted, isTrue);
      expect(state.continueChapter, isNull);
      expect(state.unreadCount, 0);
      expect(
        state.lastReadAt,
        isNotNull,
        reason: 'it still belongs in Recently Read',
      );
    });

    test(
      'marking an earlier chapter unread makes it continuable again',
      () async {
        await seed();
        for (final id in ['c1', 'c2', 'c3']) {
          await reading.markRead(id);
        }
        await reading.markUnread('c2');

        final state = computeSeriesReadingState(
          await db.chaptersForItem('series-1'),
        );
        expect(state.allCompleted, isFalse);
        expect(state.continueChapter!.id, 'c2');
      },
    );

    test('a chapter that is not stored locally is never offered', () async {
      await seed(chapters: 2, status: 'failed');
      final state = computeSeriesReadingState(
        await db.chaptersForItem('series-1'),
      );
      expect(
        state.continueChapter,
        isNull,
        reason: 'the reader cannot open something that was never saved',
      );
      expect(state.chapters, isEmpty);
    });

    test('a partial capture is still readable and still counts', () async {
      await seed(chapters: 1, status: 'partial');
      final state = computeSeriesReadingState(
        await db.chaptersForItem('series-1'),
      );
      expect(state.continueChapter!.id, 'c1');
    });
  });

  group('capture must not disturb reading', () {
    test(
      'repairSeriesReadingState rebuilds pointers from the chapters',
      () async {
        await seed();
        await reading.markRead('c1');
        await reading.saveProgress('c2', const ReadingPosition(fraction: 0.3));

        // Corrupt the denormalised pointers, as a bad migration might.
        await db.writeSeriesReading(
          'series-1',
          const LibraryItemsCompanion(
            lastOpenedChapterId: Value('nonsense'),
            lastCompletedChapterId: Value('nonsense'),
          ),
        );

        await reading.repairSeriesReadingState();

        final series = (await db.libraryItemById('series-1'))!;
        expect(series.lastCompletedChapterId, 'c1');
        expect(series.lastOpenedChapterId, 'c2');
      },
    );
  });

  group('write serialization (lifecycle safety)', () {
    // The reader flushes from four places — debounce, dwell completion,
    // lifecycle change, dispose — without awaiting each other. Every write
    // here is read-modify-write, so ordering is the whole game: a stale
    // in-flight save landing late must not overwrite a newer state.

    test('a stale unawaited save cannot undo a completion', () async {
      await seed();

      // Fired together, no awaits in between: the completion write and a
      // plain progress write that (unserialized) could read "not completed"
      // before the first write lands and then clobber it.
      final f1 = reading.saveProgress(
        'c1',
        const ReadingPosition(fraction: 0.99, imageIndex: 5),
        completed: true,
      );
      final f2 = reading.saveProgress(
        'c1',
        const ReadingPosition(fraction: 0.98, imageIndex: 5),
      );
      await Future.wait([f1, f2]);

      final chapter = (await db.chapterById('c1'))!;
      expect(chapter.readStatus, 'completed');
      expect(chapter.completedAt, isNotNull);
      expect(
        chapter.progressImageIndex,
        5,
        reason: 'the later position still wins',
      );
      expect(
        chapter.progressFraction,
        1,
        reason: 'the completion sticks, and completed means 100%',
      );
    });

    test('interleaved writes resolve in call order', () async {
      await seed();

      // markRead then markUnread then a progress save, all in flight at once.
      // Call order is the user's intent; the final state must reflect it.
      final futures = [
        reading.markRead('c1'),
        reading.markUnread('c1'),
        reading.saveProgress(
          'c1',
          const ReadingPosition(fraction: 0.4, imageIndex: 2),
        ),
      ];
      await Future.wait(futures);

      final chapter = (await db.chapterById('c1'))!;
      expect(chapter.readStatus, 'inProgress');
      expect(chapter.completedAt, isNull, reason: 'markUnread cleared it');
      expect(chapter.progressFraction, closeTo(0.4, 0.001));
      expect(chapter.progressImageIndex, 2);
    });

    test('a failed write does not wedge the queue', () async {
      await seed();
      // A write against a nonexistent chapter resolves harmlessly…
      await reading.saveProgress('ghost', const ReadingPosition(fraction: 1));
      // …and the queue still processes what follows.
      await reading.markRead('c1');
      expect((await db.chapterById('c1'))!.readStatus, 'completed');
    });
  });
}

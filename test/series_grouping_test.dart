import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/library/series_repository.dart';
import 'package:web_reader/storage/database.dart';

void main() {
  late AppDatabase db;
  late SeriesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SeriesRepository(db);
  });
  tearDown(() => db.close());

  const uzaySeries = 'https://uzay.example/manga/efsanevi-buyu-imparatoru';
  String uzayChapter(int n) => '$uzaySeries/$n-bolum-oku';

  Future<void> addChapter({
    required String itemId,
    required String id,
    required String url,
    required String title,
    int sequence = 1,
    String status = 'complete',
    int stored = 6,
    int detected = 6,
    DateTime? capturedAt,
    String? contentPath,
  }) => db.upsertChapter(
    Chapter(
      id: id,
      libraryItemId: itemId,
      title: title,
      sourceUrl: url,
      urlKey: url,
      captureStatus: status,
      contentPath: contentPath ?? 'library/$itemId/chapters/$id',
      capturedAt: capturedAt ?? DateTime(2026, 7, 20),
      detectedImageCount: detected,
      storedImageCount: stored,
      sequence: sequence,
      byteSize: 1024,
      readStatus: 'unread',
      progressFraction: 0,
      progressImageIndex: 0,
      progressOffsetInImage: 0,
    ),
  );

  Future<List<SeriesGroupRow>> groupsWithCounts() async {
    final items = await db.watchLibraryItems().first;
    final chapters = await db.allChapters();
    return [
      for (final i in items)
        SeriesGroupRow(
          i,
          chapters.where((c) => c.libraryItemId == i.id).toList(),
        ),
    ]..removeWhere((g) => g.chapters.isEmpty);
  }

  group('grouping new captures', () {
    test('three chapters of one series land in one group', () async {
      for (var n = 883; n <= 885; n++) {
        final group = await repo.resolveGroup(
          chapterUrl: uzayChapter(n),
          pageTitle: 'Efsanevi Büyü İmparatoru $n. Bölüm - Oku',
        );
        await addChapter(
          itemId: group.id,
          id: 'c$n',
          url: uzayChapter(n),
          title: 'Efsanevi Büyü İmparatoru $n. Bölüm - Oku',
          sequence: n - 882,
        );
      }

      final groups = await groupsWithCounts();
      expect(groups, hasLength(1));
      expect(groups.single.chapters, hasLength(3));
      expect(displayNameFor(groups.single.item), 'Efsanevi Büyü İmparatoru');
    });

    test('a different series on the same host is a different group', () async {
      final a = await repo.resolveGroup(
        chapterUrl: uzayChapter(883),
        pageTitle: 'Efsanevi Büyü İmparatoru 883. Bölüm',
      );
      final b = await repo.resolveGroup(
        chapterUrl: 'https://uzay.example/manga/another-series/1-bolum-oku',
        pageTitle: 'Another Series 1. Bölüm',
      );

      expect(a.id, isNot(b.id));
      expect(a.host, b.host);
    });

    test('a low-confidence page never joins an existing group', () async {
      final a = await repo.resolveGroup(chapterUrl: 'https://flat.example/');
      final b = await repo.resolveGroup(chapterUrl: 'https://flat.example/');

      expect(a.id, isNot(b.id));
      expect(a.identityConfidence, 'low');
    });
  });

  group('renaming', () {
    test('a rename changes only the displayed name', () async {
      final group = await repo.resolveGroup(
        chapterUrl: uzayChapter(883),
        pageTitle: 'Efsanevi Büyü İmparatoru 883. Bölüm - Oku',
      );
      await addChapter(
        itemId: group.id,
        id: 'c1',
        url: uzayChapter(883),
        title: 'Efsanevi Büyü İmparatoru 883. Bölüm - Oku',
      );

      await repo.rename(group.id, 'My Favourite Series');

      final renamed = (await db.libraryItemById(group.id))!;
      expect(displayNameFor(renamed), 'My Favourite Series');
      expect(
        renamed.title,
        'Efsanevi Büyü İmparatoru',
        reason: 'the detected title is kept underneath',
      );
      expect(renamed.seriesKey, group.seriesKey, reason: 'identity unchanged');
      expect(renamed.sourceUrl, group.sourceUrl);

      // Files are addressed by chapter id, so a rename cannot move them.
      final chapter = await db.chapterById('c1');
      expect(chapter!.contentPath, 'library/${group.id}/chapters/c1');
    });

    test('a later capture rejoins the renamed group', () async {
      final group = await repo.resolveGroup(
        chapterUrl: uzayChapter(883),
        pageTitle: 'Efsanevi Büyü İmparatoru 883. Bölüm',
      );
      await repo.rename(group.id, 'My Favourite Series');

      final next = await repo.resolveGroup(
        chapterUrl: uzayChapter(884),
        pageTitle: 'Efsanevi Büyü İmparatoru 884. Bölüm',
      );

      expect(next.id, group.id, reason: 'renaming must not fork the group');
      expect(displayNameFor(next), 'My Favourite Series');
    });

    test('clearing the rename falls back to the detected title', () async {
      final group = await repo.resolveGroup(
        chapterUrl: uzayChapter(883),
        pageTitle: 'Efsanevi Büyü İmparatoru 883. Bölüm',
      );
      await repo.rename(group.id, 'Temporary');
      await repo.rename(group.id, null);

      final reset = (await db.libraryItemById(group.id))!;
      expect(displayNameFor(reset), 'Efsanevi Büyü İmparatoru');
    });

    test('the edited name survives a database reopen', () async {
      // Same file, new connection: what a restart looks like.
      final file = NativeDatabase.memory();
      final first = AppDatabase.forTesting(file);
      final repo1 = SeriesRepository(first);
      final group = await repo1.resolveGroup(
        chapterUrl: uzayChapter(883),
        pageTitle: 'Efsanevi Büyü İmparatoru 883. Bölüm',
      );
      await repo1.rename(group.id, 'Kept After Restart');
      final reloaded = (await first.libraryItemById(group.id))!;
      expect(reloaded.userTitle, 'Kept After Restart');
      await first.close();
    });
  });

  group('backfilling captures made before grouping existed', () {
    /// The old model: one row per host+first-path-segment, so every series on
    /// a site collapsed into a single shelf.
    Future<void> seedLegacyData() async {
      await db.upsertLibraryItem(
        LibraryItem(
          lifecycle: 'active',
          id: 'legacy',
          // The old code titled the group after whichever chapter came first.
          title: 'Efsanevi Büyü İmparatoru 883. Bölüm - Türkçe Manga Oku |',
          sourceUrl: 'https://uzay.example/manga',
          host: 'uzay.example',
          createdAt: DateTime(2026, 7, 1),
        ),
      );
      for (var n = 883; n <= 885; n++) {
        await addChapter(
          itemId: 'legacy',
          id: 'c$n',
          url: uzayChapter(n),
          title: 'Efsanevi Büyü İmparatoru $n. Bölüm - Türkçe Manga Oku |',
          sequence: n - 882,
          capturedAt: DateTime(2026, 7, n - 880),
        );
      }
      // A second, unrelated series that the old model had lumped in.
      await addChapter(
        itemId: 'legacy',
        id: 'other1',
        url: 'https://uzay.example/manga/baska-seri/1-bolum-oku',
        title: 'Baska Seri 1. Bölüm - Türkçe Manga Oku |',
        sequence: 4,
      );
    }

    test('splits a legacy catch-all row into real series', () async {
      await seedLegacyData();
      final report = await repo.backfillExistingCaptures();

      expect(report.chaptersRegrouped, 4);
      final groups = await groupsWithCounts();
      expect(groups, hasLength(2));

      final byName = {for (final g in groups) displayNameFor(g.item): g};
      expect(byName.keys, containsAll(['Efsanevi Büyü İmparatoru']));
      expect(byName['Efsanevi Büyü İmparatoru']!.chapters, hasLength(3));
    });

    test('loses no chapter, file path or capture state', () async {
      await seedLegacyData();
      final before = await db.allChapters();
      await repo.backfillExistingCaptures();
      final after = await db.allChapters();

      expect(after, hasLength(before.length));
      for (final old in before) {
        final now = after.firstWhere((c) => c.id == old.id);
        expect(now.contentPath, old.contentPath, reason: 'files never move');
        expect(now.captureStatus, old.captureStatus);
        expect(now.storedImageCount, old.storedImageCount);
        expect(now.sourceUrl, old.sourceUrl);
        expect(now.capturedAt, old.capturedAt);
      }
    });

    test('derives the series name from the chapter titles', () async {
      await seedLegacyData();
      await repo.backfillExistingCaptures();

      final groups = await groupsWithCounts();
      final names = groups.map((g) => displayNameFor(g.item)).toList();
      expect(names, contains('Efsanevi Büyü İmparatoru'));
      for (final name in names) {
        expect(
          name,
          isNot(contains('Bölüm')),
          reason: 'a group must not be named after one of its chapters',
        );
      }
    });

    test('fills in chapter ordering while regrouping', () async {
      await seedLegacyData();
      await repo.backfillExistingCaptures();

      final chapters = await db.allChapters();
      final c884 = chapters.firstWhere((c) => c.id == 'c884');
      expect(c884.chapterNumber, 884);
      expect(c884.chapterLabel, '884. Bölüm');
    });

    test('is safe to run twice', () async {
      await seedLegacyData();
      final first = await repo.backfillExistingCaptures();
      final second = await repo.backfillExistingCaptures();

      expect(first.chaptersRegrouped, 4);
      expect(second.chaptersRegrouped, 0, reason: 'nothing left to do');
      expect(await groupsWithCounts(), hasLength(2));
    });

    test('drops only empty groups', () async {
      await seedLegacyData();
      await repo.backfillExistingCaptures();

      final items = await db.watchLibraryItems().first;
      for (final item in items) {
        final owned = (await db.allChapters())
            .where((c) => c.libraryItemId == item.id)
            .length;
        expect(owned, greaterThan(0));
      }
    });

    test('preserves a name the user had already set', () async {
      await seedLegacyData();
      await db.renameLibraryItem('legacy', 'User Chosen Name');
      await repo.backfillExistingCaptures();

      final items = await db.watchLibraryItems().first;
      final kept = items.where((i) => i.userTitle == 'User Chosen Name');
      expect(
        kept,
        isNotEmpty,
        reason: 'a rename must survive regrouping of the row it was set on',
      );
    });
  });

  group('capture reuses the right group afterwards', () {
    test('a new chapter joins the backfilled group, not a new one', () async {
      await db.upsertLibraryItem(
        LibraryItem(
          lifecycle: 'active',
          id: 'legacy',
          title: 'Efsanevi Büyü İmparatoru 883. Bölüm - Oku',
          sourceUrl: 'https://uzay.example/manga',
          host: 'uzay.example',
          createdAt: DateTime(2026, 7, 1),
        ),
      );
      await addChapter(
        itemId: 'legacy',
        id: 'c883',
        url: uzayChapter(883),
        title: 'Efsanevi Büyü İmparatoru 883. Bölüm - Oku',
      );
      await repo.backfillExistingCaptures();

      final group = await repo.resolveGroup(
        chapterUrl: uzayChapter(884),
        pageTitle: 'Efsanevi Büyü İmparatoru 884. Bölüm - Oku',
      );
      await addChapter(
        itemId: group.id,
        id: 'c884',
        url: uzayChapter(884),
        title: 'Efsanevi Büyü İmparatoru 884. Bölüm - Oku',
        sequence: 2,
      );

      final groups = await groupsWithCounts();
      expect(groups, hasLength(1));
      expect(groups.single.chapters, hasLength(2));
    });
  });
}

/// Local stand-in so this test does not depend on the widget layer.
class SeriesGroupRow {
  SeriesGroupRow(this.item, this.chapters);
  final LibraryItem item;
  final List<Chapter> chapters;
}

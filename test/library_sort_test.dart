import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/features/library_screen.dart';
import 'package:web_reader/library/library_sort.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/database.dart';

/// M13 backend: the persisted sort, the pure ordering, and the narrow
/// per-series stream that keeps one chapter's change from rippling through
/// every series.
void main() {
  LibraryItem item(String id, String title, {DateTime? lastReadAt}) =>
      LibraryItem(
        lifecycle: 'active',
        id: id,
        title: title,
        sourceUrl: 'https://x.example/manga/$id',
        host: 'x.example',
        seriesKey: '/manga/$id',
        createdAt: DateTime(2026, 7, 1),
        lastReadAt: lastReadAt,
      );

  Chapter chapter(String id, String itemId) => Chapter(
    id: id,
    libraryItemId: itemId,
    title: 'ch',
    sourceUrl: 'https://x.example/manga/$itemId/$id',
    urlKey: 'https://x.example/manga/$itemId/$id',
    captureStatus: 'complete',
    contentPath: 'library/$itemId/chapters/$id',
    detectedImageCount: 1,
    storedImageCount: 1,
    sequence: 1,
    byteSize: 1,
    readStatus: 'unread',
    progressFraction: 0,
    progressImageIndex: 0,
    progressOffsetInImage: 0,
  );

  SeriesGroup seriesOf(LibraryItem i) =>
      SeriesGroup(item: i, chapters: [chapter('c-${i.id}', i.id)]);

  group('sortSeriesGroups (pure)', () {
    test('lastRead: recently read first, never-read after, ties by name', () {
      final groups = [
        seriesOf(item('b', 'Beta')), // never read
        seriesOf(item('a', 'Alpha', lastReadAt: DateTime(2026, 7, 20))),
        seriesOf(item('z', 'Zeta', lastReadAt: DateTime(2026, 7, 26))),
        seriesOf(item('c', 'Aardvark')), // never read
      ];

      final sorted = sortSeriesGroups(groups, LibrarySort.lastRead);

      expect(sorted.map((g) => g.item.id).toList(), [
        'z', // most recently read
        'a',
        'c', // never read, then alphabetical
        'b',
      ]);
    });

    test('name: case-insensitive natural order', () {
      final groups = [
        seriesOf(item('1', 'zeta')),
        seriesOf(item('2', 'Alpha')),
        seriesOf(item('3', 'chapter 10 series')),
        seriesOf(item('4', 'chapter 2 series')),
      ];

      final sorted = sortSeriesGroups(groups, LibrarySort.name);

      expect(sorted.map((g) => g.item.title).toList(), [
        'Alpha',
        'chapter 2 series',
        'chapter 10 series',
        'zeta',
      ]);
    });

    test('unknown stored value falls back to the default sort', () {
      expect(librarySortFromName('nonsense'), LibrarySort.lastRead);
      expect(librarySortFromName(null), LibrarySort.lastRead);
      expect(librarySortFromName('name'), LibrarySort.name);
    });
  });

  group('settings persistence', () {
    test('the sort survives closing and reopening the database', () async {
      final dir = Directory.systemTemp.createTempSync('webread_settings');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'settings_test.sqlite'));

      var db = AppDatabase.forTesting(NativeDatabase(file));
      expect(await db.getSetting(kLibrarySortSettingKey), isNull);
      await db.setSetting(kLibrarySortSettingKey, LibrarySort.name.name);
      await db.close();

      // "Restart": a brand-new handle over the same file.
      db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      expect(
        librarySortFromName(await db.getSetting(kLibrarySortSettingKey)),
        LibrarySort.name,
      );
    });

    test('watchSetting emits the change', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final emissions = <String?>[];
      final sub = db.watchSetting(kLibrarySortSettingKey).listen(emissions.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.setSetting(kLibrarySortSettingKey, 'name');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions, [null, 'name']);
    });
  });

  group('per-series stream narrowing', () {
    test(
      "a progress write for series A does not re-emit series B's chapters",
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.upsertLibraryItem(item('a', 'Alpha'));
        await db.upsertLibraryItem(item('b', 'Beta'));
        await db.upsertChapter(chapter('ca', 'a'));
        await db.upsertChapter(chapter('cb', 'b'));

        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        var aEmissions = 0;
        var bEmissions = 0;
        container.listen(seriesChaptersProvider('a'), (_, next) {
          if (next.hasValue) aEmissions++;
        }, fireImmediately: true);
        container.listen(seriesChaptersProvider('b'), (_, next) {
          if (next.hasValue) bEmissions++;
        }, fireImmediately: true);

        // Let both streams deliver their first value.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final aBefore = aEmissions, bBefore = bEmissions;
        expect(aBefore, greaterThan(0));
        expect(bBefore, greaterThan(0));

        // A reading-progress write to series A's chapter. Drift invalidates
        // per table, so B's underlying stream fires too — the distinct()
        // must swallow it.
        await db.writeChapterReading(
          'ca',
          ChaptersCompanion(
            progressFraction: const Value(0.5),
            progressUpdatedAt: Value(DateTime(2026, 7, 27)),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(
          aEmissions,
          greaterThan(aBefore),
          reason: "series A's own data changed — it must emit",
        );
        expect(
          bEmissions,
          bBefore,
          reason:
              "series B's data is unchanged — the distinct stream must not "
              'emit, so per-series widgets do not rebuild',
        );
      },
    );
  });
}

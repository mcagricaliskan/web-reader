import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/features/series_detail_screen.dart';
import 'package:web_reader/library/series_identity.dart';
import 'package:web_reader/storage/database.dart';

/// Episode ordering: newest first by default, flippable, and derived from the
/// parsed chapter number rather than from whatever order the site listed them.
void main() {
  var seq = 0;

  Chapter chapter({
    required String id,
    double? number,
    String? label,
    DateTime? capturedAt,
  }) => Chapter(
    id: id,
    libraryItemId: 'series-1',
    title: label ?? id,
    sourceUrl: 'https://x.example/manga/foo/$id',
    urlKey: 'https://x.example/manga/foo/$id',
    captureStatus: 'complete',
    contentPath: 'library/series-1/chapters/$id',
    capturedAt: capturedAt ?? DateTime(2026, 7, 20),
    detectedImageCount: 1,
    storedImageCount: 1,
    sequence: ++seq,
    byteSize: 1,
    chapterNumber: number,
    chapterLabel: label,
    readStatus: 'unread',
    progressFraction: 0,
    progressImageIndex: 0,
    progressOffsetInImage: 0,
  );

  setUp(() => seq = 0);

  List<String> ids(List<Chapter> list) => list.map((c) => c.id).toList();

  test('the default is newest first', () {
    // Fed in the order a site might list them — which is not an ordering.
    final list = [
      chapter(id: 'b', number: 385),
      chapter(id: 'c', number: 386),
      chapter(id: 'a', number: 384),
    ];

    expect(ids(sortChapters(list, ChapterSort.newestFirst)), ['c', 'b', 'a']);
    expect(chapterSortFromName(null), ChapterSort.newestFirst);
  });

  test('ascending is reading order', () {
    final list = [
      chapter(id: 'c', number: 386),
      chapter(id: 'a', number: 384),
      chapter(id: 'b', number: 385),
    ];
    expect(ids(sortChapters(list, ChapterSort.oldestFirst)), ['a', 'b', 'c']);
  });

  test('decimals sit between their neighbours, both ways', () {
    final list = [
      chapter(id: 'x386', number: 386),
      chapter(id: 'x385', number: 385),
      chapter(id: 'x385h', number: 385.5),
    ];

    expect(ids(sortChapters(list, ChapterSort.oldestFirst)), [
      'x385',
      'x385h',
      'x386',
    ]);
    expect(ids(sortChapters(list, ChapterSort.newestFirst)), [
      'x386',
      'x385h',
      'x385',
    ]);
  });

  test('unnumbered entries keep a stable place, not a random one', () {
    // No number to compare: capture sequence decides, and the two directions
    // are exact mirrors so an Extra keeps the same neighbours.
    final list = [
      chapter(id: 'n1', number: 1),
      chapter(id: 'extra', label: 'Extra'),
      chapter(id: 'n2', number: 2),
      chapter(id: 'prologue', label: 'Prologue'),
    ];

    final up = ids(sortChapters(list, ChapterSort.oldestFirst));
    final down = ids(sortChapters(list, ChapterSort.newestFirst));
    expect(up, ['n1', 'n2', 'extra', 'prologue'], reason: 'numbered first');
    expect(down, up.reversed.toList(), reason: 'one ordering, mirrored');
  });

  test('sorting is stable across repeated calls', () {
    final list = [
      chapter(id: 'a', label: 'Extra'),
      chapter(id: 'b', label: 'Special'),
    ];
    expect(
      ids(sortChapters(list, ChapterSort.newestFirst)),
      ids(sortChapters([...list.reversed], ChapterSort.newestFirst)),
    );
  });

  group('the preference persists', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('nothing stored means newest first', () async {
      expect(
        chapterSortFromName(await db.setting(kChapterSortKey)),
        ChapterSort.newestFirst,
      );
    });

    test('a choice survives a reload', () async {
      await db.setSetting(kChapterSortKey, ChapterSort.oldestFirst.name);
      expect(
        chapterSortFromName(await db.setting(kChapterSortKey)),
        ChapterSort.oldestFirst,
      );

      await db.setSetting(kChapterSortKey, ChapterSort.newestFirst.name);
      expect(
        chapterSortFromName(await db.setting(kChapterSortKey)),
        ChapterSort.newestFirst,
      );
    });

    test('an unrecognised stored value falls back to the default', () async {
      await db.setSetting(kChapterSortKey, 'sideways');
      expect(
        chapterSortFromName(await db.setting(kChapterSortKey)),
        ChapterSort.newestFirst,
      );
    });
  });

  group('display labels', () {
    test('a number becomes the product label', () {
      expect(
        chapterDisplayLabel(number: 487, rawLabel: '487. Bölüm'),
        'Chapter 487',
      );
      expect(
        chapterDisplayLabel(number: 487.5, rawLabel: 'Chapter 487.5'),
        'Chapter 487.5',
      );
    });

    test('no number falls back to the raw label, never an invented one', () {
      expect(chapterDisplayLabel(rawLabel: 'Prologue'), 'Prologue');
      expect(chapterDisplayLabel(rawLabel: 'Extra'), 'Extra');
      expect(
        chapterDisplayLabel(rawLabel: '  ', title: 'Side Story'),
        'Side Story',
      );
      expect(chapterDisplayLabel(), 'Chapter');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/library/series_identity.dart';

void main() {
  group('series title from a chapter page title', () {
    test('strips a Turkish chapter marker and the site tagline', () {
      expect(
        seriesTitleFromPageTitle(
          'Efsanevi Büyü İmparatoru 883. Bölüm - Türkçe Manga Oku |',
        ),
        'Efsanevi Büyü İmparatoru',
      );
    });

    test('strips an English chapter marker and the site name', () {
      expect(
        seriesTitleFromPageTitle(
          "Genius Archer's Streaming Chapter 101 - Read Online | Asura Scans",
        ),
        "Genius Archer's Streaming",
      );
    });

    test('strips a German chapter marker', () {
      expect(
        seriesTitleFromPageTitle('Der Held Kapitel 42 | LesenOnline'),
        'Der Held',
      );
    });

    test('leaves a title with no chapter marker alone', () {
      expect(seriesTitleFromPageTitle('Some Series'), 'Some Series');
    });

    test('handles empty and null input', () {
      expect(seriesTitleFromPageTitle(null), isNull);
      expect(seriesTitleFromPageTitle('   '), isNull);
    });
  });

  group('chapter numbers', () {
    test('reads a number next to a chapter word, in any of the languages', () {
      expect(parseChapterNumber(title: 'Foo Chapter 101'), 101);
      expect(parseChapterNumber(title: 'Foo 883. Bölüm'), 883);
      expect(parseChapterNumber(title: 'Der Held Kapitel 42'), 42);
    });

    test('supports decimal chapters', () {
      expect(parseChapterNumber(title: 'Foo Chapter 12.5'), 12.5);
    });

    test('falls back to the URL when the title has no number', () {
      expect(
        parseChapterNumber(
          title: 'Some Series',
          url: 'https://x.com/manga/foo/884-bolum-oku',
        ),
        884,
      );
    });

    test('returns null for a non-numeric identifier', () {
      // "Extra" and "Prologue" are real chapter names; they must not be
      // coerced to 0, which would drag them to the front of the list.
      expect(
        parseChapterNumber(
          title: 'Foo — Extra',
          url: 'https://x.com/foo/extra',
        ),
        isNull,
      );
    });
  });

  group('chapter labels', () {
    test('keeps the marker the site used', () {
      expect(
        chapterLabelFrom(title: 'Efsanevi Büyü İmparatoru 883. Bölüm - Oku'),
        '883. Bölüm',
      );
      expect(
        chapterLabelFrom(title: "Genius Archer's Streaming Chapter 101 - Read"),
        'Chapter 101',
      );
    });

    test('falls back to the number, then to the URL segment', () {
      expect(chapterLabelFrom(title: 'Untitled', number: 7), 'Chapter 7');
      expect(
        chapterLabelFrom(title: '', url: 'https://x.com/foo/prologue'),
        'prologue',
      );
    });
  });

  group('series identity', () {
    test('three chapters of one series resolve to one key', () {
      final ids = [
        'https://uzay.example/manga/efsanevi-buyu-imparatoru/883-bolum-oku',
        'https://uzay.example/manga/efsanevi-buyu-imparatoru/884-bolum-oku',
        'https://uzay.example/manga/efsanevi-buyu-imparatoru/885-bolum-oku',
      ].map((u) => resolveSeriesIdentity(chapterUrl: u)).toList();

      expect(ids.map((i) => i.seriesKey).toSet(), hasLength(1));
      expect(ids.first.seriesKey, '/manga/efsanevi-buyu-imparatoru');
      expect(ids.first.confidence, SeriesConfidence.high);
    });

    test('two series on the same host stay apart', () {
      final a = resolveSeriesIdentity(
        chapterUrl: 'https://uzay.example/manga/series-a/1-bolum-oku',
      );
      final b = resolveSeriesIdentity(
        chapterUrl: 'https://uzay.example/manga/series-b/1-bolum-oku',
      );

      expect(a.host, b.host);
      expect(
        a.seriesKey,
        isNot(b.seriesKey),
        reason: 'same host must not mean same series',
      );
    });

    test('the two real layouts each get their own key', () {
      final uzay = resolveSeriesIdentity(
        chapterUrl:
            'https://uzaymanga.com/manga/efsanevi-buyu-imparatoru/883-bolum-oku',
      );
      final asura = resolveSeriesIdentity(
        chapterUrl:
            'https://asurascans.com/comics/genius-archers-streaming-f886a8af/chapter/101',
      );

      expect(uzay.seriesKey, '/manga/efsanevi-buyu-imparatoru');
      expect(asura.seriesKey, '/comics/genius-archers-streaming-f886a8af');
    });

    test('a link back to the series index wins, and names the series', () {
      final identity = resolveSeriesIdentity(
        chapterUrl: 'https://x.example/manga/slug-abc/883-bolum-oku',
        pageTitle: 'Slug ABC 883. Bölüm - Oku',
        hints: const SeriesHints(
          prefixLinks: [
            PageRef(
              href: 'https://x.example/manga/slug-abc',
              path: '/manga/slug-abc',
              text: 'Efsanevi Büyü İmparatoru',
            ),
            PageRef(
              href: 'https://x.example/manga',
              path: '/manga',
              text: 'All manga',
            ),
          ],
        ),
      );

      expect(identity.basis, 'series link');
      expect(identity.seriesKey, '/manga/slug-abc');
      expect(identity.detectedTitle, 'Efsanevi Büyü İmparatoru');
      expect(identity.seriesUrl, 'https://x.example/manga/slug-abc');
    });

    test('og:title is preferred over the page title for the name', () {
      final identity = resolveSeriesIdentity(
        chapterUrl: 'https://x.example/manga/foo/12',
        pageTitle: 'Foo Chapter 12 - Read free | SiteName',
        hints: const SeriesHints(ogTitle: 'Foo: The Real Title Chapter 12'),
      );
      expect(identity.detectedTitle, 'Foo: The Real Title');
    });

    test('a flat URL falls back to the title, keyed per series', () {
      final a = resolveSeriesIdentity(
        chapterUrl: 'https://x.example/',
        pageTitle: 'Series One Chapter 3',
      );
      final b = resolveSeriesIdentity(
        chapterUrl: 'https://x.example/',
        pageTitle: 'Series Two Chapter 3',
      );

      expect(a.confidence, SeriesConfidence.medium);
      expect(a.seriesKey, isNot(b.seriesKey));
      expect(a.canMerge, isTrue);
    });

    test('nothing to go on is low confidence and must not merge', () {
      final identity = resolveSeriesIdentity(chapterUrl: 'https://x.example/');
      expect(identity.confidence, SeriesConfidence.low);
      expect(
        identity.canMerge,
        isFalse,
        reason: 'an extra group is recoverable; a wrong merge is not',
      );
    });
  });

  group('chapter ordering', () {
    ({double? number, int sequence, DateTime? capturedAt}) ch(
      double? number,
      int sequence, [
      DateTime? at,
    ]) => (number: number, sequence: sequence, capturedAt: at);

    test('parsed number wins over capture sequence', () {
      final list = [ch(885, 1), ch(883, 2), ch(884, 3)]
        ..sort(compareChaptersForReading);
      expect(list.map((c) => c.number), [883, 884, 885]);
    });

    test('decimal chapters slot between integers', () {
      final list = [ch(13, 1), ch(12.5, 2), ch(12, 3)]
        ..sort(compareChaptersForReading);
      expect(list.map((c) => c.number), [12, 12.5, 13]);
    });

    test('unnumbered chapters sort after numbered ones, by sequence', () {
      final list = [ch(null, 2), ch(5, 9), ch(null, 1)]
        ..sort(compareChaptersForReading);
      expect(list.first.number, 5);
      expect(list[1].sequence, 1);
      expect(list[2].sequence, 2);
    });

    test('capture time breaks a full tie', () {
      final early = DateTime(2026, 1, 1);
      final late = DateTime(2026, 6, 1);
      final list = [ch(null, 0, late), ch(null, 0, early)]
        ..sort(compareChaptersForReading);
      expect(list.first.capturedAt, early);
    });
  });
}

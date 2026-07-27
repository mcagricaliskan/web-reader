import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/capture/site_rule.dart';

void main() {
  group('seriesFingerprint', () {
    test('strips a numeric chapter segment', () {
      expect(
        seriesFingerprint('https://x.com/comics/genius-archers/chapter/101'),
        '/comics/genius-archers',
      );
    });

    test('strips a Turkish chapter slug', () {
      expect(
        seriesFingerprint('https://x.com/manga/efsanevi-buyu/883-bolum-oku'),
        '/manga/efsanevi-buyu',
      );
    });

    test('strips a German chapter slug', () {
      expect(
        seriesFingerprint('https://x.com/manga/held/kapitel-42'),
        '/manga/held',
      );
    });

    test('consecutive chapters of one series share a fingerprint', () {
      expect(
        seriesFingerprint('https://x.com/manga/foo/883-bolum-oku'),
        seriesFingerprint('https://x.com/manga/foo/884-bolum-oku'),
      );
    });

    test('different series never share a fingerprint', () {
      expect(
        seriesFingerprint('https://x.com/manga/foo/1'),
        isNot(seriesFingerprint('https://x.com/manga/bar/1')),
      );
    });
  });

  group('hrefPatternFrom', () {
    test('generalises the chapter number', () {
      final pattern = hrefPatternFrom('https://x.com/manga/foo/883-bolum-oku');
      expect(RegExp(pattern!).hasMatch('/manga/foo/883-bolum-oku'), isTrue);
      expect(RegExp(pattern).hasMatch('/manga/foo/884-bolum-oku'), isTrue);
      expect(RegExp(pattern).hasMatch('/manga/bar/884-bolum-oku'), isFalse);
    });

    test('returns null when there is no number to generalise', () {
      expect(hrefPatternFrom('https://x.com/manga/foo/latest'), isNull);
    });
  });

  group('DomLocator', () {
    test('round-trips through JSON', () {
      const locator = DomLocator(
        tag: 'a',
        rel: 'next',
        cssSelector: 'a.next-chapter',
        containerSelector: 'nav',
        linkText: 'Sonraki Bölüm',
        hrefPattern: r'^/manga/foo/(\d+)$',
      );
      final restored = DomLocator.decode(locator.encode());

      expect(restored.rel, 'next');
      expect(restored.cssSelector, 'a.next-chapter');
      expect(restored.linkText, 'Sonraki Bölüm');
      expect(restored.hrefPattern, r'^/manga/foo/(\d+)$');
    });

    test('counts independent signals and flags a weak locator', () {
      const weak = DomLocator(tag: 'a', linkText: 'next');
      expect(weak.signalCount, 1);
      expect(weak.isWeak, isTrue);

      const strong = DomLocator(
        tag: 'a',
        rel: 'next',
        cssSelector: 'a.nav-next',
        hrefPattern: r'^/c/(\d+)$',
      );
      expect(strong.signalCount, 3);
      expect(strong.isWeak, isFalse);
    });
  });

  group('rule scoping', () {
    SiteRule rule({
      required RuleScope scope,
      String? seriesPath,
      String host = 'x.com',
      RuleKind kind = RuleKind.nextLink,
      DateTime? created,
    }) => SiteRule(
      id: '$scope-$seriesPath-$kind',
      host: host,
      seriesPath: seriesPath,
      scope: scope,
      kind: kind,
      locator: const DomLocator(rel: 'next'),
      createdAt: created ?? DateTime(2026, 1, 1),
    );

    test('a series rule matches only its own series', () {
      final r = rule(scope: RuleScope.series, seriesPath: '/manga/foo');

      expect(
        r.matches(
          'https://x.com/manga/foo/884-bolum-oku',
          kindName: 'nextLink',
        ),
        isTrue,
      );
      expect(
        r.matches(
          'https://x.com/manga/bar/884-bolum-oku',
          kindName: 'nextLink',
        ),
        isFalse,
        reason: 'a rule learned on one series must not leak to another',
      );
    });

    test('a host rule matches any series on that host, and no other host', () {
      final r = rule(scope: RuleScope.host);

      expect(
        r.matches('https://x.com/manga/anything/1', kindName: 'nextLink'),
        isTrue,
      );
      expect(
        r.matches('https://other.com/manga/foo/1', kindName: 'nextLink'),
        isFalse,
      );
    });

    test('a path-pattern rule matches the same URL shape', () {
      final shape = pathShape('/manga/foo/883-bolum-oku');
      final r = rule(scope: RuleScope.pathPattern, seriesPath: shape);

      expect(
        r.matches('https://x.com/manga/bar/12-bolum-oku', kindName: 'nextLink'),
        isTrue,
      );
      expect(
        r.matches('https://x.com/novel/bar/12', kindName: 'nextLink'),
        isFalse,
      );
    });

    test('kind is part of matching — a reader rule is not a next rule', () {
      final r = rule(scope: RuleScope.host, kind: RuleKind.readerArea);
      expect(r.matches('https://x.com/a/1', kindName: 'readerArea'), isTrue);
      expect(r.matches('https://x.com/a/1', kindName: 'nextLink'), isFalse);
    });

    test('the narrowest matching rule wins', () {
      final rules = [
        rule(scope: RuleScope.host),
        rule(
          scope: RuleScope.pathPattern,
          seriesPath: pathShape('/manga/foo/1'),
        ),
        rule(scope: RuleScope.series, seriesPath: '/manga/foo'),
      ];

      final best = bestMatchingRule(
        rules,
        'https://x.com/manga/foo/884-bolum-oku',
        kind: RuleKind.nextLink,
      );
      expect(best!.scope, RuleScope.series);
    });

    test('ties break toward the most recently used rule', () {
      final older = SiteRule(
        id: 'older',
        host: 'x.com',
        seriesPath: '/manga/foo',
        scope: RuleScope.series,
        kind: RuleKind.nextLink,
        locator: const DomLocator(rel: 'next'),
        createdAt: DateTime(2026, 1, 1),
        lastUsedAt: DateTime(2026, 1, 2),
      );
      final newer = SiteRule(
        id: 'newer',
        host: 'x.com',
        seriesPath: '/manga/foo',
        scope: RuleScope.series,
        kind: RuleKind.nextLink,
        locator: const DomLocator(rel: 'next'),
        createdAt: DateTime(2026, 1, 1),
        lastUsedAt: DateTime(2026, 6, 1),
      );

      final best = bestMatchingRule(
        [older, newer],
        'https://x.com/manga/foo/1',
        kind: RuleKind.nextLink,
      );
      expect(best!.id, 'newer');
    });

    test('no rule matches an unrelated host', () {
      final best = bestMatchingRule(
        [rule(scope: RuleScope.host)],
        'https://elsewhere.com/manga/foo/1',
        kind: RuleKind.nextLink,
      );
      expect(best, isNull);
    });
  });
}

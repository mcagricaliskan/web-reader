import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/rule_repository.dart';
import 'package:web_reader/capture/site_rule.dart';
import 'package:web_reader/storage/database.dart';

void main() {
  late AppDatabase db;
  late RuleRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = RuleRepository(db);
  });
  tearDown(() => db.close());

  /// What the JS picker reports for a Turkish "Sonraki Bölüm" control.
  const turkishNextButton = SelectedElement(
    mode: 'link',
    tag: 'a',
    text: 'Sonraki Bölüm',
    href: 'https://uzay.example/manga/efsanevi-buyu/884-bolum-oku',
    rel: 'next',
    classes: 'nav-next chapter-nav',
    selector: 'a.nav-next',
    containerSelector: 'nav',
  );

  const germanNextButton = SelectedElement(
    mode: 'link',
    tag: 'a',
    text: 'Nächstes Kapitel',
    href: 'https://lesen.example/manga/held/kapitel-43',
    classes: 'weiter-link',
    selector: 'a.weiter-link',
  );

  const readerContainer = SelectedElement(
    mode: 'reader',
    tag: 'div',
    classes: 'reading-content',
    selector: 'div.reading-content',
    imageCount: 12,
    minImageEdge: 800,
    imageSelector: 'img',
  );

  group('saving and reusing a next-button rule', () {
    test(
      'a saved rule is found again for the next chapter of that series',
      () async {
        const source = 'https://uzay.example/manga/efsanevi-buyu/883-bolum-oku';
        final created = await repo.createNextLinkRule(
          element: turkishNextButton,
          sourceUrl: source,
        );

        expect(created.kind, RuleKind.nextLink);
        expect(created.scope, RuleScope.series);
        expect(created.seriesPath, '/manga/efsanevi-buyu');
        expect(created.locator.rel, 'next');
        expect(created.locator.linkText, 'Sonraki Bölüm');
        expect(created.locator.cssSelector, 'a.nav-next');
        expect(created.locator.hrefPattern, isNotNull);
        expect(
          created.locator.isWeak,
          isFalse,
          reason: 'rel + selector + text + pattern is not a one-signal rule',
        );

        // The very next chapter of the same series reuses it.
        final found = await repo.findFor(
          'https://uzay.example/manga/efsanevi-buyu/884-bolum-oku',
          RuleKind.nextLink,
        );
        expect(found, isNotNull);
        expect(found!.id, created.id);
      },
    );

    test(
      'the stored href pattern generalises across chapter numbers',
      () async {
        final rule = await repo.createNextLinkRule(
          element: turkishNextButton,
          sourceUrl: 'https://uzay.example/manga/efsanevi-buyu/883-bolum-oku',
        );
        final pattern = RegExp(rule.locator.hrefPattern!);

        expect(pattern.hasMatch('/manga/efsanevi-buyu/885-bolum-oku'), isTrue);
        expect(
          pattern.hasMatch('/manga/another-series/885-bolum-oku'),
          isFalse,
        );
      },
    );

    test('a rule survives a round-trip through the database intact', () async {
      final created = await repo.createNextLinkRule(
        element: germanNextButton,
        sourceUrl: 'https://lesen.example/manga/held/kapitel-42',
      );

      final reloaded = (await repo.all()).single;
      expect(reloaded.id, created.id);
      expect(reloaded.host, 'lesen.example');
      expect(reloaded.seriesPath, '/manga/held');
      expect(reloaded.locator.linkText, 'Nächstes Kapitel');
      expect(reloaded.locator.cssSelector, 'a.weiter-link');
    });
  });

  group('rules do not leak between series', () {
    test('a series rule is not offered for an unrelated series', () async {
      await repo.createNextLinkRule(
        element: turkishNextButton,
        sourceUrl: 'https://uzay.example/manga/efsanevi-buyu/883-bolum-oku',
      );

      final other = await repo.findFor(
        'https://uzay.example/manga/completely-different/5-bolum-oku',
        RuleKind.nextLink,
      );
      expect(
        other,
        isNull,
        reason: 'a rule learned on one series must not drive another',
      );
    });

    test(
      'a host-scoped rule is offered across series, by explicit choice',
      () async {
        await repo.createNextLinkRule(
          element: turkishNextButton,
          sourceUrl: 'https://uzay.example/manga/efsanevi-buyu/883-bolum-oku',
          scope: RuleScope.host,
        );

        final other = await repo.findFor(
          'https://uzay.example/manga/completely-different/5-bolum-oku',
          RuleKind.nextLink,
        );
        expect(other, isNotNull);
        expect(other!.scope, RuleScope.host);
      },
    );

    test('a rule never applies to a different host', () async {
      await repo.createNextLinkRule(
        element: turkishNextButton,
        sourceUrl: 'https://uzay.example/manga/foo/1',
        scope: RuleScope.host,
      );
      expect(
        await repo.findFor(
          'https://asura.example/manga/foo/1',
          RuleKind.nextLink,
        ),
        isNull,
      );
    });

    test('a next-link rule is not used as a reader-area rule', () async {
      await repo.createNextLinkRule(
        element: turkishNextButton,
        sourceUrl: 'https://uzay.example/manga/foo/1',
        scope: RuleScope.host,
      );
      expect(
        await repo.findFor(
          'https://uzay.example/manga/foo/1',
          RuleKind.readerArea,
        ),
        isNull,
      );
    });
  });

  group('reader-area rules', () {
    test('derives a container, image selector and size floor', () async {
      final rule = await repo.createReaderAreaRule(
        element: readerContainer,
        sourceUrl: 'https://asura.example/comics/genius/chapter/101',
      );

      expect(rule.kind, RuleKind.readerArea);
      expect(rule.locator.containerSelector, 'div.reading-content');
      expect(rule.locator.imageSelector, 'img');
      expect(rule.locator.minImageEdge, 640, reason: '80% of the 800px floor');
      expect(rule.seriesPath, '/comics/genius');
    });

    test(
      'falls back to a sane floor when the container reports nothing',
      () async {
        final rule = await repo.createReaderAreaRule(
          element: const SelectedElement(
            mode: 'reader',
            tag: 'div',
            selector: 'div.reader',
          ),
          sourceUrl: 'https://x.example/c/1',
        );
        expect(rule.locator.minImageEdge, 300);
      },
    );
  });

  group('invalidating a broken rule', () {
    test('failures are recorded without destroying the rule', () async {
      final rule = await repo.createNextLinkRule(
        element: turkishNextButton,
        sourceUrl: 'https://uzay.example/manga/foo/1',
      );

      await repo.recordUse(rule.id, success: false);
      await repo.recordUse(rule.id, success: false);
      var reloaded = (await repo.all()).single;
      expect(reloaded.failureCount, 2);
      expect(reloaded.successCount, 0);
      expect(reloaded.lastUsedAt, isNull);

      await repo.recordUse(rule.id, success: true);
      reloaded = (await repo.all()).single;
      expect(reloaded.successCount, 1);
      expect(reloaded.lastUsedAt, isNotNull);
    });

    test('deleting a rule stops it being offered', () async {
      final rule = await repo.createNextLinkRule(
        element: turkishNextButton,
        sourceUrl: 'https://uzay.example/manga/foo/1',
      );
      expect(
        await repo.findFor(
          'https://uzay.example/manga/foo/2',
          RuleKind.nextLink,
        ),
        isNotNull,
      );

      await repo.delete(rule.id);
      expect(
        await repo.findFor(
          'https://uzay.example/manga/foo/2',
          RuleKind.nextLink,
        ),
        isNull,
      );
      expect(await repo.all(), isEmpty);
    });

    test('a replacement rule wins over the one it replaced', () async {
      const url = 'https://uzay.example/manga/foo/1';
      final old = await repo.createNextLinkRule(
        element: turkishNextButton,
        sourceUrl: url,
      );
      await repo.recordUse(old.id, success: true);

      final replacement = await repo.createNextLinkRule(
        element: germanNextButton,
        sourceUrl: url,
      );
      await repo.recordUse(replacement.id, success: true);

      final found = await repo.findFor(url, RuleKind.nextLink);
      expect(found!.id, replacement.id);
    });
  });
}

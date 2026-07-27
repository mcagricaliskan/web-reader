import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/browser/page_data.dart';
import 'package:web_reader/capture/next_page.dart';
import 'package:web_reader/core/url_utils.dart';

PageProbe probe({
  String url = 'https://x.com/chapter/1',
  String? headNext,
  List<PageLink> links = const [],
}) => PageProbe(
  url: url,
  title: 'Chapter 1',
  headNextHref: headNext,
  links: links,
);

void main() {
  group('strategy ordering', () {
    test('link[rel=next] outranks a labelled control', () {
      final result = resolveNextPage(
        probe(
          headNext: 'https://x.com/chapter/2',
          links: const [
            PageLink(href: 'https://x.com/chapter/99', text: 'Next chapter'),
          ],
        ),
        currentUrl: 'https://x.com/chapter/1',
        visitedNormalized: {},
      );

      expect(result.chosen!.href, 'https://x.com/chapter/2');
      expect(result.chosen!.strategy, NextStrategy.headRelNext);
    });

    test('a[rel=next] outranks link text', () {
      final result = resolveNextPage(
        probe(
          links: const [
            PageLink(href: 'https://x.com/chapter/50', text: 'Continue'),
            PageLink(href: 'https://x.com/chapter/2', rel: 'next', text: '→'),
          ],
        ),
        currentUrl: 'https://x.com/chapter/1',
        visitedNormalized: {},
      );

      expect(result.chosen!.strategy, NextStrategy.anchorRelNext);
      expect(result.chosen!.href, 'https://x.com/chapter/2');
    });

    test('a site override outranks everything', () {
      final result = resolveNextPage(
        probe(headNext: 'https://x.com/wrong'),
        currentUrl: 'https://x.com/chapter/1',
        visitedNormalized: {},
        ruleHref: 'https://x.com/right',
      );
      expect(result.chosen!.strategy, NextStrategy.savedRule);
      expect(result.chosen!.href, 'https://x.com/right');
    });
  });

  group('text matching', () {
    test('matches common next labels across languages', () {
      for (final label in [
        'Next',
        'Next Chapter',
        'Next episode',
        'Sonraki Bölüm',
        'Siguiente',
        '다음화',
      ]) {
        final result = resolveNextPage(
          probe(
            links: [PageLink(href: 'https://x.com/chapter/2', text: label)],
          ),
          currentUrl: 'https://x.com/chapter/1',
          visitedNormalized: {},
        );
        expect(result.hasNext, isTrue, reason: label);
      }
    });

    test('matches aria-label and title when the text is an icon', () {
      final result = resolveNextPage(
        probe(
          links: const [
            PageLink(
              href: 'https://x.com/chapter/2',
              text: '›',
              ariaLabel: 'Next chapter',
            ),
          ],
        ),
        currentUrl: 'https://x.com/chapter/1',
        visitedNormalized: {},
      );
      expect(result.hasNext, isTrue);
      expect(result.chosen!.evidence, contains('aria-label'));
    });

    test('ignores deny-listed near-misses', () {
      final result = resolveNextPage(
        probe(
          links: const [
            PageLink(href: 'https://x.com/series/2', text: 'Next series'),
            PageLink(href: 'https://x.com/comments?p=2', text: 'Next comments'),
          ],
        ),
        currentUrl: 'https://x.com/chapter/1',
        visitedNormalized: {},
      );
      expect(result.hasNext, isFalse);
    });

    test('ignores a long paragraph that merely contains the word', () {
      final result = resolveNextPage(
        probe(
          links: const [
            PageLink(
              href: 'https://x.com/blog',
              text: 'Read what happens next in our weekly newsletter roundup',
            ),
          ],
        ),
        currentUrl: 'https://x.com/chapter/1',
        visitedNormalized: {},
      );
      expect(result.hasNext, isFalse);
    });
  });

  group('validation inside the chain', () {
    test('skips a visited candidate and takes the next viable one', () {
      final result = resolveNextPage(
        probe(
          headNext: 'https://x.com/chapter/1', // already visited
          links: const [
            PageLink(href: 'https://x.com/chapter/2', text: 'Next'),
          ],
        ),
        currentUrl: 'https://x.com/chapter/9',
        visitedNormalized: {'https://x.com/chapter/1'},
      );

      expect(result.chosen!.href, 'https://x.com/chapter/2');
    });

    test('reports no next when every candidate is rejected', () {
      final result = resolveNextPage(
        probe(
          links: const [PageLink(href: 'https://other.com/c/2', text: 'Next')],
        ),
        currentUrl: 'https://x.com/chapter/1',
        visitedNormalized: {},
      );

      expect(result.hasNext, isFalse);
      expect(result.rejection, NextUrlRejection.differentHost);
      expect(result.considered, hasLength(1));
    });

    test('no candidates at all is end-of-chain, not an error', () {
      final result = resolveNextPage(
        probe(
          links: const [PageLink(href: 'https://x.com/', text: 'Home')],
        ),
        currentUrl: 'https://x.com/chapter/3',
        visitedNormalized: {},
      );
      expect(result.hasNext, isFalse);
      expect(result.considered, isEmpty);
      expect(result.rejection, isNull);
    });

    test(
      'the chosen href is returned normalised, ready for the visited set',
      () {
        final result = resolveNextPage(
          probe(
            links: const [
              PageLink(
                href: 'https://x.com/chapter/2?utm_source=rss#top',
                rel: 'next',
              ),
            ],
          ),
          currentUrl: 'https://x.com/chapter/1',
          visitedNormalized: {},
        );
        expect(result.chosen!.href, 'https://x.com/chapter/2');
      },
    );
  });
}

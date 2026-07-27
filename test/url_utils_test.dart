import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/core/url_utils.dart';

void main() {
  group('normalizeUrl', () {
    test('lowercases scheme and host, drops the default port', () {
      expect(
        normalizeUrl('HTTPS://Example.COM:443/Chapter/1'),
        'https://example.com/Chapter/1',
      );
    });

    test('drops the fragment and tracking params, sorts the rest', () {
      expect(
        normalizeUrl('https://x.com/c/1?utm_source=rss&b=2&a=1#comments'),
        'https://x.com/c/1?a=1&b=2',
      );
    });

    test('collapses duplicate slashes and strips a trailing slash', () {
      expect(normalizeUrl('https://x.com//a//b/'), 'https://x.com/a/b');
      expect(normalizeUrl('https://x.com/'), 'https://x.com/');
    });

    test('keeps www and the scheme — they can be distinct origins', () {
      expect(
        normalizeUrl('https://www.x.com/a'),
        isNot(normalizeUrl('https://x.com/a')),
      );
      expect(
        normalizeUrl('http://x.com/a'),
        isNot(normalizeUrl('https://x.com/a')),
      );
    });
  });

  group('resolveUrl', () {
    test('resolves relative hrefs against the page URL', () {
      expect(
        resolveUrl('https://x.com/series/foo/chapter-1', '../chapter-2'),
        'https://x.com/series/chapter-2',
      );
      expect(resolveUrl('https://x.com/a/b', '/c/d'), 'https://x.com/c/d');
    });
  });

  group('validateNextUrl — loop and scope prevention', () {
    const current = 'https://x.com/chapter/1';

    test('accepts a same-host forward link', () {
      final check = validateNextUrl(
        candidate: '/chapter/2',
        currentUrl: current,
        visited: {normalizeUrl(current)},
      );
      expect(check.isAccepted, isTrue);
      expect(check.normalized, 'https://x.com/chapter/2');
    });

    test('rejects the current URL', () {
      final check = validateNextUrl(
        candidate: current,
        currentUrl: current,
        visited: {},
      );
      expect(check.rejection, NextUrlRejection.sameAsCurrent);
    });

    test('rejects a URL differing only by fragment as the current page', () {
      final check = validateNextUrl(
        candidate: '$current#end',
        currentUrl: current,
        visited: {},
      );
      expect(check.rejection, NextUrlRejection.sameAsCurrent);
    });

    test('rejects an already-visited URL — this is the loop guard', () {
      final check = validateNextUrl(
        candidate: 'https://x.com/chapter/1',
        currentUrl: 'https://x.com/chapter/2',
        visited: {'https://x.com/chapter/1'},
      );
      expect(check.rejection, NextUrlRejection.alreadyVisited);
    });

    test('rejects a different host unless explicitly allowed', () {
      final check = validateNextUrl(
        candidate: 'https://other.com/chapter/2',
        currentUrl: current,
        visited: {},
      );
      expect(check.rejection, NextUrlRejection.differentHost);
      expect(check.crossHost, isTrue);

      final allowed = validateNextUrl(
        candidate: 'https://other.com/chapter/2',
        currentUrl: current,
        visited: {},
        allowCrossHost: true,
      );
      expect(allowed.isAccepted, isTrue);
    });

    test('rejects non-http schemes', () {
      for (final candidate in [
        'javascript:void(0)',
        'mailto:a@b.com',
        'ftp://x.com/f',
      ]) {
        final check = validateNextUrl(
          candidate: candidate,
          currentUrl: current,
          visited: {},
        );
        expect(check.isAccepted, isFalse, reason: candidate);
      }
    });

    test('rejects auth-shaped destinations', () {
      for (final candidate in ['/login', '/account/signin', '/register']) {
        final check = validateNextUrl(
          candidate: candidate,
          currentUrl: current,
          visited: {},
        );
        expect(check.rejection, NextUrlRejection.denyListed, reason: candidate);
      }
    });
  });
}

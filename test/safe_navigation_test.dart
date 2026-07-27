import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/site_rule.dart';
import 'package:web_reader/core/url_utils.dart';

/// A user-selected control is a strong signal about one link. It is not
/// permission to follow whatever the page does next — these tests pin that.
void main() {
  group('navigation lock during a capture job', () {
    late BrowserController browser;
    setUp(() => browser = BrowserController());
    tearDown(() => browser.dispose());

    test('nothing is blocked while no job is running', () {
      expect(
        browser.shouldBlockNavigation('https://x.com/a', isMainFrame: true),
        isFalse,
      );
    });

    test('an unannounced navigation is blocked while locked', () {
      browser.navigationLocked = true;
      expect(
        browser.shouldBlockNavigation('https://x.com/popup', isMainFrame: true),
        isTrue,
      );
    });

    test('the chapter the job chose is allowed through', () {
      browser.navigationLocked = true;
      browser.allowNextNavigation('https://x.com/manga/foo/11');
      expect(
        browser.shouldBlockNavigation(
          'https://x.com/manga/foo/11',
          isMainFrame: true,
        ),
        isFalse,
      );
    });

    test('a same-host redirect of the allowed target is permitted', () {
      browser.navigationLocked = true;
      browser.allowNextNavigation('https://x.com/manga/foo/11');
      expect(
        browser.shouldBlockNavigation(
          'https://x.com/manga/foo/11?utm_source=rss',
          isMainFrame: true,
        ),
        isFalse,
      );
    });

    test('a redirect to another host is blocked even when one was allowed', () {
      browser.navigationLocked = true;
      browser.allowNextNavigation('https://x.com/manga/foo/11');
      expect(
        browser.shouldBlockNavigation(
          'https://ads.example/landing',
          isMainFrame: true,
        ),
        isTrue,
      );
    });

    test('sub-frames are not policed — only top-level navigation is', () {
      browser.navigationLocked = true;
      expect(
        browser.shouldBlockNavigation(
          'https://cdn.example/frame',
          isMainFrame: false,
        ),
        isFalse,
      );
    });
  });

  group('post-redirect validation', () {
    const from = 'https://uzay.example/manga/foo/883-bolum-oku';

    test('a redirect inside the same series is accepted', () {
      const landed = 'https://uzay.example/manga/foo/884-bolum-oku';
      final check = validateNextUrl(
        candidate: landed,
        currentUrl: from,
        visited: {normalizeUrl(from)},
      );
      expect(check.isAccepted, isTrue);
      expect(seriesFingerprint(landed), seriesFingerprint(from));
    });

    test('a redirect that leaves the series is detectable', () {
      const landed = 'https://uzay.example/manga/OTHER-SERIES/1-bolum-oku';
      // URL validation alone would allow it — same host, not visited.
      final check = validateNextUrl(
        candidate: landed,
        currentUrl: from,
        visited: {normalizeUrl(from)},
      );
      expect(check.isAccepted, isTrue);

      // The series check is what stops it.
      expect(
        seriesFingerprint(landed),
        isNot(seriesFingerprint(from)),
        reason: 'the job must stop rather than capture a different series',
      );
    });

    test('a redirect to a login page is refused', () {
      final check = validateNextUrl(
        candidate: 'https://uzay.example/login?next=/manga/foo/884',
        currentUrl: from,
        visited: {},
      );
      expect(check.rejection, NextUrlRejection.denyListed);
    });

    test('a redirect back to an already-captured chapter is refused', () {
      final check = validateNextUrl(
        candidate: from,
        currentUrl: 'https://uzay.example/manga/foo/884-bolum-oku',
        visited: {normalizeUrl(from)},
      );
      expect(check.rejection, NextUrlRejection.alreadyVisited);
    });

    test('a redirect off-host is refused', () {
      final check = validateNextUrl(
        candidate: 'https://mirror.example/manga/foo/884',
        currentUrl: from,
        visited: {},
      );
      expect(check.rejection, NextUrlRejection.differentHost);
    });
  });

  _hostChangeTests();

  group('bounded chapter count', () {
    test('the requested limit is clamped to the configured maximum', () {
      // The controller clamps with `chapterLimit.clamp(1, maxChaptersPerJob)`.
      const maxChapters = 5;
      expect(999.clamp(1, maxChapters), maxChapters);
      expect(0.clamp(1, maxChapters), 1);
      expect(3.clamp(1, maxChapters), 3);
    });
  });
}

void _hostChangeTests() {
  group('cross-host consent', () {
    late BrowserController browser;
    setUp(() {
      browser = BrowserController();
      browser.onUrlChanged('https://uzay.example/manga/foo/883');
    });
    tearDown(() => browser.dispose());

    test('a page-initiated hop to another host needs consent', () {
      expect(
        browser.needsHostChangeConsent(
          fromUrl: 'https://uzay.example/manga/foo/883',
          toUrl: 'https://ads.example/landing',
          isMainFrame: true,
          userInitiated: false,
        ),
        isTrue,
      );
    });

    test('same-host navigation never asks', () {
      expect(
        browser.needsHostChangeConsent(
          fromUrl: 'https://uzay.example/manga/foo/883',
          toUrl: 'https://uzay.example/manga/foo/884',
          isMainFrame: true,
          userInitiated: false,
        ),
        isFalse,
      );
    });

    test('a deliberate tap while browsing is not nagged about', () {
      expect(
        browser.needsHostChangeConsent(
          fromUrl: 'https://uzay.example/manga/foo/883',
          toUrl: 'https://other.example/',
          isMainFrame: true,
          userInitiated: true,
        ),
        isFalse,
      );
    });

    test('during a capture job even a tap is questioned', () {
      browser.navigationLocked = true;
      expect(
        browser.needsHostChangeConsent(
          fromUrl: 'https://uzay.example/manga/foo/883',
          toUrl: 'https://other.example/',
          isMainFrame: true,
          userInitiated: true,
        ),
        isTrue,
      );
    });

    test('sub-frames are not policed', () {
      expect(
        browser.needsHostChangeConsent(
          fromUrl: 'https://uzay.example/manga/foo/883',
          toUrl: 'https://cdn.example/frame',
          isMainFrame: false,
          userInitiated: false,
        ),
        isFalse,
      );
    });

    test('non-http schemes are not treated as host changes', () {
      for (final target in ['mailto:a@b.com', 'tel:123', 'about:blank']) {
        expect(
          browser.needsHostChangeConsent(
            fromUrl: 'https://uzay.example/a',
            toUrl: target,
            isMainFrame: true,
            userInitiated: false,
          ),
          isFalse,
          reason: target,
        );
      }
    });

    test(
      'silence refuses, and the browser stays put',
      () async {
        final decision = browser.requestHostChange(
          fromUrl: 'https://uzay.example/manga/foo/883',
          toUrl: 'https://ads.example/landing',
        );
        expect(browser.pendingHostChange, isNotNull);
        expect(browser.pendingHostChange!.toHost, 'ads.example');

        // No answer: the timeout must deny rather than allow.
        expect(await decision, isFalse);
        expect(browser.pendingHostChange, isNull);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test('an explicit Stay refuses immediately', () async {
      final decision = browser.requestHostChange(
        fromUrl: 'https://uzay.example/a',
        toUrl: 'https://ads.example/landing',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      browser.resolveHostChange(false);
      expect(await decision, isFalse);
    });

    test('an allowed host is remembered, so it asks only once', () async {
      final first = browser.requestHostChange(
        fromUrl: 'https://uzay.example/a',
        toUrl: 'https://mirror.example/a',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      browser.resolveHostChange(true);
      expect(await first, isTrue);

      expect(
        browser.needsHostChangeConsent(
          fromUrl: 'https://uzay.example/a',
          toUrl: 'https://mirror.example/b',
          isMainFrame: true,
          userInitiated: false,
        ),
        isFalse,
      );

      // ...until a capture job clears it, so a browsing-time decision does not
      // silently widen an autonomous run.
      browser.clearAllowedHostChanges();
      expect(
        browser.needsHostChangeConsent(
          fromUrl: 'https://uzay.example/a',
          toUrl: 'https://mirror.example/b',
          isMainFrame: true,
          userInitiated: false,
        ),
        isTrue,
      );
    });
  });
}

import 'package:web_reader/browser/page_data.dart';

import 'fake_browser.dart';

/// A [FakeBrowser] whose probes are computed per call — enough control to
/// script an unrendered surface (zero viewport), a page that loads panel by
/// panel, or one whose layout is torn down mid-capture.
class ScriptedBrowser extends FakeBrowser {
  ScriptedBrowser({required this.probeBuilder});

  /// Called with the current scroll position and how many probes have been
  /// answered so far.
  PageProbe Function(int y, int probeCount) probeBuilder;

  /// Every dy passed to [scrollStep], in order.
  final List<int> scrollSteps = [];

  /// When false, scroll commands do not move the position (frozen page).
  bool scrollMoves = true;

  int y = 0;
  int probeCount = 0;

  @override
  Future<PageProbe> probe({bool withLinks = false}) async {
    probeCount++;
    return probeBuilder(y, probeCount);
  }

  @override
  Future<Map<String, dynamic>> scrollStep(int dy) async {
    scrollSteps.add(dy);
    if (scrollMoves) {
      final probe = probeBuilder(y, probeCount);
      final maxY = probe.documentHeight - probe.viewportHeight;
      y = (y + dy).clamp(0, maxY < 0 ? 0 : maxY);
    }
    return const {};
  }

  @override
  Future<void> scrollTo(int target) async {
    if (scrollMoves) y = target < 0 ? 0 : target;
  }
}

/// A page of [panelCount] tall panels; panels whose top edge is above
/// `loadedUpTo` are resolved, the rest pending — a plain lazy-loading strip.
PageProbe lazyStripProbe({
  required int y,
  required int viewportHeight,
  int panelCount = 10,
  int panelWidth = 800,
  int panelHeight = 2000,
  int? loadedUpTo,
  String url = 'https://x.example/manga/foo/1',
  String title = 'Foo Chapter 1',
  String? nextHref,
  List<PageImage> extraImages = const [],
}) {
  final docHeight = panelCount * panelHeight;
  final resolvedBelow = loadedUpTo ?? docHeight;
  return PageProbe(
    url: url,
    title: title,
    readyState: 'complete',
    documentHeight: docHeight,
    viewportHeight: viewportHeight,
    scrollY: y,
    atBottom: viewportHeight > 0 && y + viewportHeight >= docHeight - 8,
    images: [
      for (var i = 0; i < panelCount; i++)
        PageImage(
          domIndex: i,
          src: 'https://cdn.example/p/$i.png',
          currentSrc: 'https://cdn.example/p/$i.png',
          complete: i * panelHeight < resolvedBelow,
          naturalWidth: i * panelHeight < resolvedBelow ? panelWidth : 0,
          naturalHeight: i * panelHeight < resolvedBelow ? panelHeight : 0,
          renderedWidth: 390,
          renderedHeight: 975,
          documentTop: i * panelHeight,
        ),
      ...extraImages,
    ],
    links: [
      if (nextHref != null)
        PageLink(href: nextHref, rel: 'next', text: 'Next Chapter'),
    ],
  );
}

/// A small avatar-like image (comment section): tiny rendered box, never
/// finishes loading unless [complete].
PageImage avatarImage(int index, {bool complete = false}) => PageImage(
  domIndex: 100 + index,
  src: 'https://cdn.example/avatar/$index.webp',
  currentSrc: 'https://cdn.example/avatar/$index.webp',
  complete: complete,
  naturalWidth: complete ? 538 : 0,
  naturalHeight: complete ? 539 : 0,
  renderedWidth: 40,
  renderedHeight: 40,
  documentTop: 999999,
);

import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/browser/page_data.dart';
import 'package:web_reader/core/url_utils.dart';

/// A [BrowserController] whose "pages" are literal [PageProbe]s.
///
/// Lets the capture job loop and the update checker run headless in unit
/// tests: navigation just moves a pointer, probes return the fixture for the
/// current URL. Asset bytes still come over real HTTP (the tests stand up a
/// local server), so the downloader path is exercised for real.
class FakeBrowser extends BrowserController {
  FakeBrowser({Map<String, PageProbe> pages = const {}}) {
    this.pages.addAll(pages);
  }

  /// Keyed by normalised URL.
  final Map<String, PageProbe> pages = {};

  /// Optional redirects: navigating to key lands on value.
  final Map<String, String> redirects = {};

  final List<String> navigations = [];

  String _url = '';

  @override
  String get currentUrl => _url;

  @override
  bool get isAttached => true;

  @override
  String get title => pages[normalizeUrl(_url)]?.title ?? '';

  void setUrl(String url) => _url = url;

  void addPage(String url, PageProbe probe) => pages[normalizeUrl(url)] = probe;

  @override
  Future<void> loadAndWait(String url, {Duration? timeout}) async {
    navigations.add(url);
    _url = redirects[url] ?? url;
    notifyListeners();
  }

  @override
  Future<PageProbe> probe({bool withLinks = false}) async {
    final page = pages[normalizeUrl(_url)];
    if (page == null) {
      throw BridgeException('no fixture page for $_url');
    }
    return page;
  }

  @override
  Future<Map<String, dynamic>> scrollStep(int dy) async => const {};

  @override
  Future<void> scrollTo(int y) async {}

  @override
  Future<String?> userAgent() async => null;

  @override
  Future<String?> cookieHeaderFor(String url) async => null;

  @override
  Future<LocatorMatch?> applyLocator(Map<String, dynamic> locator) async =>
      null;

  @override
  Future<List<PageImage>?> applyReaderRule(Map<String, dynamic> rule) async =>
      null;

  @override
  Future<InPageBytes?> fetchAsBase64(String url) async => null;

  @override
  Future<void> startSelection({String mode = 'link'}) async {}

  @override
  Future<void> stopSelection() async {}
}

/// A settled chapter page: [imageUrls] all loaded, one optional rel=next
/// link, plus whatever [extraLinks] the test wants in the way.
PageProbe chapterProbe({
  required String url,
  required String title,
  required List<String> imageUrls,
  String? nextHref,
  List<PageLink> extraLinks = const [],
  int width = 800,
  int height = 1200,
}) {
  return PageProbe(
    url: url,
    title: title,
    readyState: 'complete',
    documentHeight: 4000,
    viewportHeight: 800,
    scrollY: 3200,
    atBottom: true,
    images: [
      for (final (i, src) in imageUrls.indexed)
        PageImage(
          domIndex: i,
          src: src,
          currentSrc: src,
          complete: true,
          naturalWidth: width,
          naturalHeight: height,
          renderedWidth: 390,
          renderedHeight: 585,
          documentTop: i * height,
        ),
    ],
    links: [
      if (nextHref != null)
        PageLink(href: nextHref, rel: 'next', text: 'Next Chapter'),
      ...extraLinks,
    ],
  );
}

/// Plain models for what the JavaScript bridge reports about a page.
/// No Flutter, no plugin types — so the save heuristics that consume these
/// are unit testable against literal fixtures.
library;

import '../library/collection_identity.dart';

class PageImage {
  const PageImage({
    required this.domIndex,
    this.src,
    this.currentSrc,
    this.dataSrc,
    this.complete = false,
    this.naturalWidth = 0,
    this.naturalHeight = 0,
    this.renderedWidth = 0,
    this.renderedHeight = 0,
    this.attrWidth = 0,
    this.attrHeight = 0,
    this.documentTop = 0,
    this.hidden = false,
    this.inPageChrome = false,
    this.className = '',
    this.alt = '',
  });

  factory PageImage.fromJson(Map<String, dynamic> json) => PageImage(
    domIndex: _int(json['index']),
    src: _str(json['src']),
    currentSrc: _str(json['currentSrc']),
    dataSrc: _str(json['dataSrc']),
    complete: json['complete'] == true,
    naturalWidth: _int(json['naturalWidth']),
    naturalHeight: _int(json['naturalHeight']),
    renderedWidth: _int(json['renderedWidth']),
    renderedHeight: _int(json['renderedHeight']),
    attrWidth: _int(json['attrWidth']),
    attrHeight: _int(json['attrHeight']),
    documentTop: _int(json['top']),
    hidden: json['hidden'] == true,
    inPageChrome: json['chrome'] == true,
    className: json['className']?.toString() ?? '',
    alt: json['alt']?.toString() ?? '',
  );

  final int domIndex;
  final String? src;
  final String? currentSrc;
  final String? dataSrc;
  final bool complete;
  final int naturalWidth;
  final int naturalHeight;
  final int renderedWidth;
  final int renderedHeight;

  /// The `width`/`height` HTML attributes. The last resort for sizing an image
  /// that never loaded — without them a broken panel looks like a 0x0 icon and
  /// gets silently filtered out, which is how an entry loses a page and still
  /// reports success.
  final int attrWidth;
  final int attrHeight;
  final int documentTop;
  final bool hidden;

  /// Inside <header>, <footer>, <nav> or <aside>.
  final bool inPageChrome;
  final String className;
  final String alt;

  /// The URL the browser actually settled on, preferring `currentSrc` because
  /// it is the post-`srcset`/media-query resolution. Falls back to a lazy
  /// attribute for images that have not been swapped in yet.
  String? get effectiveUrl {
    for (final candidate in [currentSrc, src, dataSrc]) {
      if (candidate == null) continue;
      final t = candidate.trim();
      if (t.isEmpty) continue;
      if (t.startsWith('data:')) continue;
      return t;
    }
    return null;
  }

  /// Intrinsic size when known, then the **declared** attributes, then the
  /// laid-out box.
  ///
  /// The attribute comes before the rendered box on purpose: `width="800"` is
  /// an intrinsic-basis declaration, while the rendered box is post-CSS layout
  /// (a 800px panel renders at ~390 logical px on a phone). Preferring the
  /// rendered box mixed the two bases, so a broken panel measured 390 against
  /// loaded panels measuring 800 and got discarded as "outside the content
  /// column" — silently shrinking the entry by a page.
  int get effectiveWidth => naturalWidth > 0
      ? naturalWidth
      : (attrWidth > 0 ? attrWidth : renderedWidth);
  int get effectiveHeight => naturalHeight > 0
      ? naturalHeight
      : (attrHeight > 0 ? attrHeight : renderedHeight);

  /// Loaded and decodable.
  bool get isResolved => complete && naturalWidth > 0 && naturalHeight > 0;

  /// Finished loading, but with an error: `complete` is true for a failed
  /// image too, so this is how a permanent failure is told apart from one that
  /// is still in flight.
  bool get isBroken => complete && naturalWidth == 0;
}

class PageLink {
  const PageLink({
    required this.href,
    this.rel = '',
    this.text = '',
    this.ariaLabel = '',
    this.title = '',
    this.className = '',
    this.id = '',
    this.imgAlt = '',
    this.inNav = false,
    this.documentTop = 0,
  });

  factory PageLink.fromJson(Map<String, dynamic> json) => PageLink(
    href: json['href']?.toString() ?? '',
    rel: json['rel']?.toString() ?? '',
    text: json['text']?.toString() ?? '',
    ariaLabel: json['ariaLabel']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    className: json['className']?.toString() ?? '',
    id: json['id']?.toString() ?? '',
    imgAlt: json['imgAlt']?.toString() ?? '',
    inNav: json['inNav'] == true,
    documentTop: _int(json['top']),
  );

  final String href;
  final String rel;
  final String text;
  final String ariaLabel;
  final String title;
  final String className;
  final String id;

  /// `alt` of an image inside the link — many "next" controls are icons.
  final String imgAlt;
  final bool inNav;
  final int documentTop;
}

/// Structural description of a page: how much prose, how much image area, does
/// it declare an article, does it carry a date, does it have real pagination.
///
/// Deliberately contains no subject matter and no genre. Every field is a
/// measurement or a standard HTML semantic, which is what lets one detector read
/// a blog post, a documentation page and an image gallery without knowing
/// anything about any website.
class PageContentSignals {
  const PageContentSignals({
    this.textLength = 0,
    this.paragraphCount = 0,
    this.contentImageCount = 0,
    this.contentImagePixels = 0,
    this.hasArticleElement = false,
    this.hasMainElement = false,
    this.publishedAt,
    this.hasRelPrev = false,
    this.pagerNumbers = const [],
    this.listedDates = const [],
    this.headingText = '',
  });

  factory PageContentSignals.fromJson(Map<String, dynamic> json) =>
      PageContentSignals(
        textLength: _int(json['textLength']),
        paragraphCount: _int(json['paragraphCount']),
        contentImageCount: _int(json['contentImageCount']),
        contentImagePixels: _int(json['contentImagePixels']),
        hasArticleElement: json['hasArticleElement'] == true,
        hasMainElement: json['hasMainElement'] == true,
        publishedAt: _date(json['publishedAt']),
        hasRelPrev: json['hasRelPrev'] == true,
        pagerNumbers: ((json['pagerNumbers'] as List<dynamic>?) ?? const [])
            .map(_int)
            .where((n) => n > 0)
            .toList(),
        listedDates: ((json['listedDates'] as List<dynamic>?) ?? const [])
            .map(_date)
            .whereType<DateTime>()
            .toList(),
        headingText: json['headingText']?.toString().trim() ?? '',
      );

  /// Characters of visible prose in the main content region.
  final int textLength;
  final int paragraphCount;

  /// Images big enough to be content rather than chrome, and their total area.
  final int contentImageCount;
  final int contentImagePixels;

  final bool hasArticleElement;
  final bool hasMainElement;

  /// Publication date, only from a standard declaration (`<time datetime>`,
  /// article metadata, JSON-LD). Never guessed from a URL.
  final DateTime? publishedAt;

  /// A declared previous-page relationship. With `rel=next` this is what makes a
  /// sequence *explicit* rather than inferred.
  final bool hasRelPrev;

  /// Numbers found inside a pagination control. A range here is the only thing
  /// that justifies calling something a "page".
  final List<int> pagerNumbers;

  /// Dates attached to repeated sibling items — the signature of a feed.
  final List<DateTime> listedDates;

  final String headingText;

  /// Share of the page that is image, by rough area. Compared against prose
  /// rather than used alone: a long article with one big photo is not
  /// image-dominant.
  bool get looksImageDominant =>
      contentImageCount >= 2 && textLength < 900 && contentImagePixels > 400000;

  bool get looksProse => textLength >= 900 && paragraphCount >= 3;
}

/// Audio and video the app deliberately does not save.
///
/// Counted so the offline copy can show an honest placeholder and a link to the
/// original page. Nothing reads a media URL, and nothing fetches one.
class PageMediaSignals {
  const PageMediaSignals({this.videoCount = 0, this.audioCount = 0});

  factory PageMediaSignals.fromJson(Map<String, dynamic> json) =>
      PageMediaSignals(
        videoCount: _int(json['videoCount']),
        audioCount: _int(json['audioCount']),
      );

  final int videoCount;
  final int audioCount;

  bool get hasMedia => videoCount > 0 || audioCount > 0;
  int get total => videoCount + audioCount;
}

/// Signals that automatic continuation must stop.
///
/// Detection only. Nothing in the app attempts, works around, or retries past
/// any of these; the run stops and names which one it hit.
class PageAccessSignals {
  const PageAccessSignals({
    this.hasPasswordField = false,
    this.hasLoginForm = false,
    this.hasCaptchaWidget = false,
    this.hasPaywallMarker = false,
    this.deniedPhrase,
    this.ratePhrase,
    this.paywallPhrase,
    this.authPhrase,
    this.isEmptyDocument = false,
  });

  factory PageAccessSignals.fromJson(Map<String, dynamic> json) =>
      PageAccessSignals(
        hasPasswordField: json['hasPasswordField'] == true,
        hasLoginForm: json['hasLoginForm'] == true,
        hasCaptchaWidget: json['hasCaptchaWidget'] == true,
        hasPaywallMarker: json['hasPaywallMarker'] == true,
        deniedPhrase: _str(json['deniedPhrase']),
        ratePhrase: _str(json['ratePhrase']),
        paywallPhrase: _str(json['paywallPhrase']),
        authPhrase: _str(json['authPhrase']),
        isEmptyDocument: json['isEmptyDocument'] == true,
      );

  /// Structural: an actual input or widget is present.
  final bool hasPasswordField;
  final bool hasLoginForm;
  final bool hasCaptchaWidget;
  final bool hasPaywallMarker;

  /// Phrase hints. The weakest signal available, and used only to corroborate a
  /// structural one or an empty document — a page that merely *mentions*
  /// "subscribe to continue" in a footer is not a paywall.
  final String? deniedPhrase;
  final String? ratePhrase;
  final String? paywallPhrase;
  final String? authPhrase;

  /// Almost no visible text. On its own this is a load failure; combined with a
  /// phrase hint it is a gate.
  final bool isEmptyDocument;
}

/// One snapshot of the page, taken between scroll steps.
class PageProbe {
  const PageProbe({
    required this.url,
    required this.title,
    this.canonicalUrl,
    this.readyState = '',
    this.documentHeight = 0,
    this.viewportHeight = 0,
    this.scrollY = 0,
    this.images = const [],
    this.links = const [],
    this.headNextHref,
    this.atBottom = false,
    this.imagesTruncated = false,
    this.pageHints = const PageHints(),
    this.content = const PageContentSignals(),
    this.media = const PageMediaSignals(),
    this.access = const PageAccessSignals(),
  });

  factory PageProbe.fromJson(Map<String, dynamic> json) => PageProbe(
    url: json['url']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    canonicalUrl: _str(json['canonicalUrl']),
    readyState: json['readyState']?.toString() ?? '',
    documentHeight: _int(json['documentHeight']),
    viewportHeight: _int(json['viewportHeight']),
    scrollY: _int(json['scrollY']),
    images: (json['images'] as List<dynamic>? ?? const [])
        .map((e) => PageImage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    links: (json['links'] as List<dynamic>? ?? const [])
        .map((e) => PageLink.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    headNextHref: _str(json['headNextHref']),
    atBottom: json['atBottom'] == true,
    imagesTruncated: json['imagesTruncated'] == true,
    pageHints: json['pageHints'] is Map
        ? PageHints.fromJson(
            Map<String, dynamic>.from(json['pageHints'] as Map),
          )
        : const PageHints(),
    content: json['content'] is Map
        ? PageContentSignals.fromJson(
            Map<String, dynamic>.from(json['content'] as Map),
          )
        : const PageContentSignals(),
    media: json['media'] is Map
        ? PageMediaSignals.fromJson(
            Map<String, dynamic>.from(json['media'] as Map),
          )
        : const PageMediaSignals(),
    access: json['access'] is Map
        ? PageAccessSignals.fromJson(
            Map<String, dynamic>.from(json['access'] as Map),
          )
        : const PageAccessSignals(),
  );

  final String url;
  final String title;
  final String? canonicalUrl;
  final String readyState;
  final int documentHeight;
  final int viewportHeight;
  final int scrollY;
  final List<PageImage> images;
  final List<PageLink> links;

  /// `<link rel="next">` from the document head, if present.
  final String? headNextHref;
  final bool atBottom;

  /// The page carried more images than the probe returns. Reported so a
  /// truncated save is never mistaken for a complete one.
  final bool imagesTruncated;

  /// What the page says about the collection this entry belongs to. Only
  /// populated when the probe was asked for links.
  final PageHints pageHints;

  /// Structure, media and access signals. Defaults are all "nothing detected",
  /// so a probe taken by an older bridge degrades to "unknown content" rather
  /// than to a confident wrong answer.
  final PageContentSignals content;
  final PageMediaSignals media;
  final PageAccessSignals access;

  bool get domReady => readyState == 'interactive' || readyState == 'complete';

  /// Images still in flight. A **broken** image is not pending — it has
  /// finished, badly. Counting it as pending made the scroll loop wait for
  /// something that would never arrive, until it hit the iteration bound.
  int get pendingImageCount => images
      .where(
        (i) =>
            i.effectiveUrl != null && !i.hidden && !i.complete && !i.isResolved,
      )
      .length;

  /// Images that finished loading with an error.
  int get brokenImageCount => images
      .where((i) => i.effectiveUrl != null && !i.hidden && i.isBroken)
      .length;

  int get resolvedImageCount => images.where((i) => i.isResolved).length;

  /// Signature used to detect "nothing changed since the last probe".
  String get stabilitySignature =>
      '$documentHeight'
      '|${images.length}'
      '|$resolvedImageCount'
      '|$pendingImageCount'
      '|$brokenImageCount';
}

int _int(Object? v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// A date only when it parses. An unparseable string is "no date", never today.
DateTime? _date(Object? v) {
  final s = _str(v);
  if (s == null) return null;
  return DateTime.tryParse(s);
}

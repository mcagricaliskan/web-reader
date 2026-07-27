/// Plain models for what the JavaScript bridge reports about a page.
/// No Flutter, no plugin types — so the capture heuristics that consume these
/// are unit testable against literal fixtures.
library;

import '../library/series_identity.dart';

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
  /// gets silently filtered out, which is how a chapter loses a page and still
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
  /// column" — silently shrinking the chapter by a page.
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
    this.seriesHints = const SeriesHints(),
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
    seriesHints: json['seriesHints'] is Map
        ? SeriesHints.fromJson(
            Map<String, dynamic>.from(json['seriesHints'] as Map),
          )
        : const SeriesHints(),
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
  /// truncated capture is never mistaken for a complete one.
  final bool imagesTruncated;

  /// What the page says about the series this chapter belongs to. Only
  /// populated when the probe was asked for links.
  final SeriesHints seriesHints;

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

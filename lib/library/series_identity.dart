import '../capture/site_rule.dart' show seriesFingerprint;

/// How a chapter is attributed to a series, and how a series is titled.
///
/// Pure Dart, no I/O — the grouping decision is the part most likely to be
/// wrong on a new site, so it is unit tested directly against literal page
/// data rather than only through a live capture.

/// How much the identity can be trusted. Low confidence never merges into an
/// existing group: a wrong merge mixes two series in one shelf, which is much
/// harder to notice and undo than an extra group.
enum SeriesConfidence { high, medium, low }

class SeriesIdentity {
  const SeriesIdentity({
    required this.host,
    required this.seriesKey,
    required this.confidence,
    this.detectedTitle,
    this.seriesUrl,
    this.basis = '',
  });

  final String host;

  /// The matching key, unique per series within a host. Stored on the group.
  final String seriesKey;
  final SeriesConfidence confidence;
  final String? detectedTitle;

  /// A stable URL for the series index page, when the page linked to one.
  final String? seriesUrl;

  /// Which signal produced the key, for the log.
  final String basis;

  bool get canMerge => confidence != SeriesConfidence.low;
}

/// Signals a chapter page offers about the series it belongs to.
class SeriesHints {
  const SeriesHints({
    this.ogTitle,
    this.ogSiteName,
    this.h1,
    this.breadcrumbs = const [],
    this.prefixLinks = const [],
  });

  factory SeriesHints.fromJson(Map<String, dynamic> json) => SeriesHints(
    ogTitle: _str(json['ogTitle']),
    ogSiteName: _str(json['ogSiteName']),
    h1: _str(json['h1']),
    breadcrumbs: _links(json['breadcrumbs']),
    prefixLinks: _links(json['prefixLinks']),
  );

  final String? ogTitle;
  final String? ogSiteName;
  final String? h1;

  /// Breadcrumb trail, outermost first.
  final List<PageRef> breadcrumbs;

  /// Same-host links whose path is a strict prefix of the chapter's path —
  /// i.e. links back "up" to the series index. The strongest single signal a
  /// chapter page gives about which series it belongs to.
  final List<PageRef> prefixLinks;

  static List<PageRef> _links(Object? raw) =>
      (raw as List<dynamic>? ?? const [])
          .map((e) => PageRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
}

class PageRef {
  const PageRef({required this.href, this.path = '', this.text = ''});

  factory PageRef.fromJson(Map<String, dynamic> json) => PageRef(
    href: json['href']?.toString() ?? '',
    path: json['path']?.toString() ?? '',
    text: json['text']?.toString() ?? '',
  );

  final String href;
  final String path;
  final String text;
}

/// Words that mark a chapter within a title, across the languages seen so far.
/// Hints, not a dictionary: a title with none of these still groups correctly
/// via the URL fingerprint, which is the primary signal.
const _chapterWordPattern =
    r'(?:chapter|chap|ch|bölüm|bolum|episode|epis|ep|kapitel|'
    r'cap[ií]tulo|capitulo|part|volume|vol)';

final _trailingChapterWordThenNumber = RegExp(
  r'[\s\-–—:,\.]*' +
      _chapterWordPattern +
      r'\s*[\.\-–—:#]?\s*[\d]+(?:[.,]\d+)?\s*$',
  caseSensitive: false,
  unicode: true,
);

final _trailingNumberThenChapterWord = RegExp(
  r'[\s\-–—:,]*[\d]+(?:[.,]\d+)?\s*\.?\s*' + _chapterWordPattern + r'\s*$',
  caseSensitive: false,
  unicode: true,
);

final _titleSeparators = RegExp(r'\s+[\|·•»–—]\s+|\s+-\s+|\s*::\s*');

/// Turn a chapter page's title into the series title.
///
/// `"Efsanevi Büyü İmparatoru 883. Bölüm - Türkçe Manga Oku |"` becomes
/// `"Efsanevi Büyü İmparatoru"`; `"Genius Archer's Streaming Chapter 101 -
/// Read Online | Asura Scans"` becomes `"Genius Archer's Streaming"`.
String? seriesTitleFromPageTitle(String? pageTitle) {
  if (pageTitle == null) return null;
  var text = pageTitle.trim();
  if (text.isEmpty) return null;

  // Site name and tagline usually follow a separator; the content title leads.
  final head = text.split(_titleSeparators).first.trim();
  if (head.isNotEmpty) text = head;

  text = stripChapterMarker(text);
  text = text.replaceAll(RegExp(r'^[\s\-–—:|,\.]+|[\s\-–—:|,\.]+$'), '').trim();
  return text.isEmpty ? null : text;
}

/// Remove a trailing "Chapter 12" / "883. Bölüm" style marker.
String stripChapterMarker(String title) {
  var out = title.trim();
  for (var i = 0; i < 2; i++) {
    final before = out;
    out = out.replaceFirst(_trailingChapterWordThenNumber, '');
    out = out.replaceFirst(_trailingNumberThenChapterWord, '');
    out = out.replaceAll(RegExp(r'[\s\-–—:,\.]+$'), '');
    if (out == before) break;
  }
  return out.trim();
}

/// The chapter's own number, when it has one.
///
/// Handles decimals (`12.5`) and reads the URL when the title is unhelpful.
/// Returns null for identifiers that are not numeric at all (`"Extra"`,
/// `"Prologue"`), which the ordering falls back on capture sequence for.
double? parseChapterNumber({String? title, String? url}) {
  for (final source in [title, url]) {
    if (source == null || source.trim().isEmpty) continue;

    // Prefer a number sitting next to a chapter word.
    final near = RegExp(
      _chapterWordPattern + r'\s*[\.\-–—:#]?\s*(\d+(?:[.,]\d+)?)',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(source);
    if (near != null) {
      final n = double.tryParse(near.group(1)!.replaceAll(',', '.'));
      if (n != null) return n;
    }

    final before = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*\.?\s*' + _chapterWordPattern,
      caseSensitive: false,
      unicode: true,
    ).firstMatch(source);
    if (before != null) {
      final n = double.tryParse(before.group(1)!.replaceAll(',', '.'));
      if (n != null) return n;
    }
  }

  // Fall back to the last number in the URL's final segment.
  if (url != null) {
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments != null && segments.isNotEmpty) {
      final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(segments.last);
      if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', '.'));
    }
  }
  return null;
}

/// A short human label for a chapter — `"Bölüm 883"`, `"Chapter 101"` — or the
/// cleaned title when no marker is present.
String chapterLabelFrom({String? title, String? url, double? number}) {
  if (title != null && title.trim().isNotEmpty) {
    final head = title.split(_titleSeparators).first.trim();
    final marker = RegExp(
      '$_chapterWordPattern'
      r'\s*[\.\-–—:#]?\s*\d+(?:[.,]\d+)?'
      r'|\d+(?:[.,]\d+)?\s*\.?\s*'
      '$_chapterWordPattern',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(head);
    if (marker != null) return marker.group(0)!.trim();
  }
  if (number != null) {
    final asInt = number == number.roundToDouble();
    return 'Chapter ${asInt ? number.round() : number}';
  }
  final segments = Uri.tryParse(
    url ?? '',
  )?.pathSegments.where((s) => s.isNotEmpty);
  if (segments != null && segments.isNotEmpty) return segments.last;
  return title?.trim() ?? 'Chapter';
}

/// Work out which series a chapter belongs to, and what to call it.
///
/// Order of preference, strongest first:
///   1. a same-host link back to the series index (gives key *and* title)
///   2. the series-path fingerprint of the chapter URL
///   3. the page title, when the URL carries no usable path
///   4. the host, which never merges (low confidence)
SeriesIdentity resolveSeriesIdentity({
  required String chapterUrl,
  String? pageTitle,
  SeriesHints hints = const SeriesHints(),
}) {
  final uri = Uri.tryParse(chapterUrl);
  final host = uri?.host.toLowerCase() ?? '';
  final fingerprint = seriesFingerprint(chapterUrl);

  final titleFromPage = seriesTitleFromPageTitle(pageTitle);
  final titleFromOg = seriesTitleFromPageTitle(hints.ogTitle);
  final titleFromH1 = seriesTitleFromPageTitle(hints.h1);

  // 1. A link up to the series index. Its path is the series, and its text is
  //    almost always the series name as the site writes it.
  final seriesLink = _bestSeriesLink(hints, fingerprint);
  if (seriesLink != null) {
    final linkTitle = seriesTitleFromPageTitle(seriesLink.text);
    return SeriesIdentity(
      host: host,
      seriesKey: _normalisePath(seriesLink.path),
      confidence: SeriesConfidence.high,
      detectedTitle: _firstNonEmpty([
        linkTitle,
        titleFromOg,
        titleFromH1,
        titleFromPage,
      ]),
      seriesUrl: seriesLink.href,
      basis: 'series link',
    );
  }

  // 2. The URL's own series path.
  if (fingerprint.isNotEmpty && fingerprint != '/') {
    return SeriesIdentity(
      host: host,
      seriesKey: _normalisePath(fingerprint),
      confidence: SeriesConfidence.high,
      detectedTitle: _firstNonEmpty([titleFromOg, titleFromH1, titleFromPage]),
      seriesUrl: host.isEmpty
          ? null
          : '${uri?.scheme ?? 'https'}://$host$fingerprint',
      basis: 'url fingerprint',
    );
  }

  // 3. No usable path: fall back to the title, keyed by a slug so two
  //    different series on a flat host stay apart.
  final title = _firstNonEmpty([titleFromOg, titleFromH1, titleFromPage]);
  if (title != null) {
    return SeriesIdentity(
      host: host,
      seriesKey: 'title:${_slug(title)}',
      confidence: SeriesConfidence.medium,
      detectedTitle: title,
      basis: 'page title',
    );
  }

  // 4. Nothing to go on. Group by host but refuse to merge — an extra group is
  //    recoverable, a wrong merge is not.
  return SeriesIdentity(
    host: host,
    seriesKey: 'host:$host',
    confidence: SeriesConfidence.low,
    detectedTitle: hints.ogSiteName ?? (host.isEmpty ? null : host),
    basis: 'host fallback',
  );
}

/// Of the links pointing "up" from this chapter, the one that looks like the
/// series index: the longest path that is still a strict prefix, preferring an
/// exact match on the URL fingerprint.
PageRef? _bestSeriesLink(SeriesHints hints, String fingerprint) {
  final candidates = <PageRef>[
    ...hints.prefixLinks,
    ...hints.breadcrumbs,
  ].where((l) => l.path.isNotEmpty && l.path != '/').toList();
  if (candidates.isEmpty) return null;

  final target = _normalisePath(fingerprint);
  for (final link in candidates) {
    if (_normalisePath(link.path) == target && link.text.trim().isNotEmpty) {
      return link;
    }
  }
  return null;
}

String _normalisePath(String path) {
  var p = path.trim();
  if (!p.startsWith('/')) p = '/$p';
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p.toLowerCase();
}

String _slug(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String? _firstNonEmpty(List<String?> values) {
  for (final v in values) {
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Reading order for a series' chapters.
///
/// Parsed number first, then the order they were captured in, then time.
/// Chapters with no number (`"Extra"`, `"Prologue"`) sort after numbered ones
/// rather than being forced to 0, which would drag them to the front.
int compareChaptersForReading(
  ({double? number, int sequence, DateTime? capturedAt}) a,
  ({double? number, int sequence, DateTime? capturedAt}) b,
) {
  if (a.number != null && b.number != null) {
    final byNumber = a.number!.compareTo(b.number!);
    if (byNumber != 0) return byNumber;
  } else if (a.number != null) {
    return -1;
  } else if (b.number != null) {
    return 1;
  }

  final bySequence = a.sequence.compareTo(b.sequence);
  if (bySequence != 0) return bySequence;

  final at = a.capturedAt;
  final bt = b.capturedAt;
  if (at != null && bt != null) return at.compareTo(bt);
  return 0;
}

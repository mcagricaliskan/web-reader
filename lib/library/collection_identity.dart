import '../save/page_hint.dart' show collectionFingerprint;

/// How an entry is attributed to a collection, and how a collection is titled.
///
/// Pure Dart, no I/O — the grouping decision is the part most likely to be
/// wrong on a new site, so it is unit tested directly against literal page
/// data rather than only through a live save.

/// How much the identity can be trusted. Low confidence never merges into an
/// existing group: a wrong merge mixes two collection in one shelf, which is much
/// harder to notice and undo than an extra group.
enum IdentityConfidence { high, medium, low }

class CollectionIdentity {
  const CollectionIdentity({
    required this.host,
    required this.collectionKey,
    required this.confidence,
    this.detectedTitle,
    this.collectionIndexUrl,
    this.basis = '',
  });

  final String host;

  /// The matching key, unique per collection within a host. Stored on the group.
  final String collectionKey;
  final IdentityConfidence confidence;
  final String? detectedTitle;

  /// A stable URL for the collection index page, when the page linked to one.
  final String? collectionIndexUrl;

  /// Which signal produced the key, for the log.
  final String basis;

  bool get canMerge => confidence != IdentityConfidence.low;
}

/// Signals an entry page offers about the collection it belongs to.
class PageHints {
  const PageHints({
    this.ogTitle,
    this.ogSiteName,
    this.h1,
    this.breadcrumbs = const [],
    this.prefixLinks = const [],
  });

  factory PageHints.fromJson(Map<String, dynamic> json) => PageHints(
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

  /// Same-host links whose path is a strict prefix of the entry's path —
  /// i.e. links back "up" to the collection index. The strongest single signal a
  /// entry page gives about which collection it belongs to.
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

/// Words that mark an entry within a title, across the languages seen so far.
/// Hints, not a dictionary: a title with none of these still groups correctly
/// via the URL fingerprint, which is the primary signal.
const _entryWordPattern =
    r'(?:entry|chap|ch|bölüm|bolum|entry|epis|ep|kapitel|'
    r'cap[ií]tulo|capitulo|part|volume|vol)';

final _trailingEntryWordThenNumber = RegExp(
  r'[\s\-–—:,\.]*' +
      _entryWordPattern +
      r'\s*[\.\-–—:#]?\s*[\d]+(?:[.,]\d+)?\s*$',
  caseSensitive: false,
  unicode: true,
);

final _trailingNumberThenEntryWord = RegExp(
  r'[\s\-–—:,]*[\d]+(?:[.,]\d+)?\s*\.?\s*' + _entryWordPattern + r'\s*$',
  caseSensitive: false,
  unicode: true,
);

final _titleSeparators = RegExp(r'\s+[\|·•»–—]\s+|\s+-\s+|\s*::\s*');

/// Turn an entry page's title into the collection title.
///
/// `"The Long Guide 12. Part - Read Online |"` becomes `"The Long Guide"`;
/// `"Setup Notes Part 3 - Example Docs"` becomes `"Setup Notes"`.
String? collectionTitleFromPageTitle(String? pageTitle) {
  if (pageTitle == null) return null;
  var text = pageTitle.trim();
  if (text.isEmpty) return null;

  // Site name and tagline usually follow a separator; the content title leads.
  final head = text.split(_titleSeparators).first.trim();
  if (head.isNotEmpty) text = head;

  text = stripEntryMarker(text);
  text = text.replaceAll(RegExp(r'^[\s\-–—:|,\.]+|[\s\-–—:|,\.]+$'), '').trim();
  return text.isEmpty ? null : text;
}

/// Remove a trailing "Entry 12" / "883. Bölüm" style marker.
String stripEntryMarker(String title) {
  var out = title.trim();
  for (var i = 0; i < 2; i++) {
    final before = out;
    out = out.replaceFirst(_trailingEntryWordThenNumber, '');
    out = out.replaceFirst(_trailingNumberThenEntryWord, '');
    out = out.replaceAll(RegExp(r'[\s\-–—:,\.]+$'), '');
    if (out == before) break;
  }
  return out.trim();
}

/// The entry's own number, when it has one.
///
/// Handles decimals (`12.5`) and reads the URL when the title is unhelpful.
/// Returns null for identifiers that are not numeric at all (`"Extra"`,
/// `"Prologue"`), which the ordering falls back on save sequence for.
double? parseEntryNumber({
  String? title,
  String? url,
  List<String?> extra = const [],
}) {
  // Text sources, best first: the link/page title the site wrote, then the
  // page's own headings and metadata, then its breadcrumb trail. A number
  // sitting next to an entry word beats a number that merely appears.
  for (final source in [title, ...extra]) {
    final n = _numberInText(source);
    if (n != null) return n;
  }
  return _numberInUrl(url);
}

/// An entry number in prose: `Entry 487`, `487. Bölüm`, `Bölüm 487,5`.
double? _numberInText(String? source) {
  if (source == null || source.trim().isEmpty) return null;

  // Number after an entry word.
  final near = RegExp(
    '$_entryWordPattern'
    r'\s*[\.\-–—:#]?\s*(\d+(?:[.,]\d+)?)',
    caseSensitive: false,
    unicode: true,
  ).firstMatch(source);
  if (near != null) {
    final n = double.tryParse(near.group(1)!.replaceAll(',', '.'));
    if (n != null) return n;
  }

  // Number before it — `487. Bölüm`, `487 화`.
  final before = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*\.?\s*'
    '$_entryWordPattern',
    caseSensitive: false,
    unicode: true,
  ).firstMatch(source);
  if (before != null) {
    final n = double.tryParse(before.group(1)!.replaceAll(',', '.'));
    if (n != null) return n;
  }
  return null;
}

/// An entry number in a URL path.
///
/// Separate from the prose rules because URLs spell decimals with a
/// separator — `/entry-385-5/` is entry 385.5 — and because `/` is a
/// legitimate gap between the word and the number (`/entry/137`). Neither
/// reading is safe to apply to prose, where "Entry 487 - 5 pages" is a
/// sentence and not a decimal.
double? _numberInUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final uri = Uri.tryParse(url);
  final path = uri?.path ?? url;

  double? build(RegExpMatch m, int whole, int frac) {
    final head = m.group(whole);
    if (head == null) return null;
    final tail = m.group(frac);
    return double.tryParse(tail == null ? head : '$head.$tail');
  }

  // Word then number, with an optional decimal tail: `/entry-385-5`,
  // `/entry/137`, `/bolum_12`.
  final after = RegExp(
    '$_entryWordPattern'
    r'[\s._\-/]*(\d+)(?:[-_.](\d{1,2}))?(?!\d)',
    caseSensitive: false,
    unicode: true,
  ).firstMatch(path);
  if (after != null) {
    final n = build(after, 1, 2);
    if (n != null) return n;
  }

  // Number then word: `/883-part`, `/487-5-bolum`.
  final beforeWord = RegExp(
    r'(\d+)(?:[-_.](\d{1,2}))?[\s._\-/]*'
    '$_entryWordPattern',
    caseSensitive: false,
    unicode: true,
  ).firstMatch(path);
  if (beforeWord != null) {
    final n = build(beforeWord, 1, 2);
    if (n != null) return n;
  }

  // Last resort: a bare number in the final path segment. No decimal
  // splitting here — without an entry word, `/12-3/` is as likely to be a
  // date or a volume as a decimal entry, and guessing wrong reorders a
  // whole collection.
  final segments = uri?.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments != null && segments.isNotEmpty) {
    final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(segments.last);
    if (m != null) return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }
  return null;
}

/// The **raw** marker as the source wrote it — `"Part 3"`, `"Section 4"`
/// — or the cleaned title when the page carries no marker.
///
/// Deliberately not the display label. This is what the site called the
/// entry, kept verbatim so the details sheet can show it and so a future
/// entry-name field has something to build on. What the list prints comes
/// from [entryDisplayLabel] instead.
String? sourceMarkerFrom({String? title, String? url, double? number}) {
  if (title != null && title.trim().isNotEmpty) {
    final head = title.split(_titleSeparators).first.trim();
    final marker = RegExp(
      '$_entryWordPattern'
      r'\s*[\.\-–—:#]?\s*\d+(?:[.,]\d+)?'
      r'|\d+(?:[.,]\d+)?\s*\.?\s*'
      '$_entryWordPattern',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(head);
    if (marker != null) return marker.group(0)!.trim();
  }
  if (number != null) {
    final asInt = number == number.roundToDouble();
    return asInt ? '${number.round()}' : '$number';
  }
  final segments = Uri.tryParse(
    url ?? '',
  )?.pathSegments.where((s) => s.isNotEmpty);
  if (segments != null && segments.isNotEmpty) return segments.last;
  return title?.trim();
}

/// Work out which collection an entry belongs to, and what to call it.
///
/// Order of preference, strongest first:
///   1. a same-host link back to the collection index (gives key *and* title)
///   2. the collection-path fingerprint of the entry URL
///   3. the page title, when the URL carries no usable path
///   4. the host, which never merges (low confidence)
CollectionIdentity resolveCollectionIdentity({
  required String entryUrl,
  String? pageTitle,
  PageHints hints = const PageHints(),
}) {
  final uri = Uri.tryParse(entryUrl);
  final host = uri?.host.toLowerCase() ?? '';
  final fingerprint = collectionFingerprint(entryUrl);

  final titleFromPage = collectionTitleFromPageTitle(pageTitle);
  final titleFromOg = collectionTitleFromPageTitle(hints.ogTitle);
  final titleFromH1 = collectionTitleFromPageTitle(hints.h1);

  // 1. A link up to the collection index. Its path is the collection, and its text is
  //    almost always the collection name as the site writes it.
  final collectionLink = _bestCollectionLink(hints, fingerprint);
  if (collectionLink != null) {
    final linkTitle = collectionTitleFromPageTitle(collectionLink.text);
    return CollectionIdentity(
      host: host,
      collectionKey: _normalisePath(collectionLink.path),
      confidence: IdentityConfidence.high,
      detectedTitle: _firstNonEmpty([
        linkTitle,
        titleFromOg,
        titleFromH1,
        titleFromPage,
      ]),
      collectionIndexUrl: collectionLink.href,
      basis: 'collection link',
    );
  }

  // 2. The URL's own collection path.
  if (fingerprint.isNotEmpty && fingerprint != '/') {
    return CollectionIdentity(
      host: host,
      collectionKey: _normalisePath(fingerprint),
      confidence: IdentityConfidence.high,
      detectedTitle: _firstNonEmpty([titleFromOg, titleFromH1, titleFromPage]),
      collectionIndexUrl: host.isEmpty
          ? null
          : '${uri?.scheme ?? 'https'}://$host$fingerprint',
      basis: 'url fingerprint',
    );
  }

  // 3. No usable path: fall back to the title, keyed by a slug so two
  //    different collection on a flat host stay apart.
  final title = _firstNonEmpty([titleFromOg, titleFromH1, titleFromPage]);
  if (title != null) {
    return CollectionIdentity(
      host: host,
      collectionKey: 'title:${_slug(title)}',
      confidence: IdentityConfidence.medium,
      detectedTitle: title,
      basis: 'page title',
    );
  }

  // 4. Nothing to go on. Group by host but refuse to merge — an extra group is
  //    recoverable, a wrong merge is not.
  return CollectionIdentity(
    host: host,
    collectionKey: 'host:$host',
    confidence: IdentityConfidence.low,
    detectedTitle: hints.ogSiteName ?? (host.isEmpty ? null : host),
    basis: 'host fallback',
  );
}

/// Of the links pointing "up" from this entry, the one that looks like the
/// collection index: the longest path that is still a strict prefix, preferring an
/// exact match on the URL fingerprint.
PageRef? _bestCollectionLink(PageHints hints, String fingerprint) {
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

/// Reading order for a collection's entries.
///
/// Parsed number first, then the order they were saved in, then time.
/// Entries with no number (`"Extra"`, `"Prologue"`) sort after numbered ones
/// rather than being forced to 0, which would drag them to the front.
int compareEntriesForReading(
  ({double? number, int entryOrder, DateTime? savedAt}) a,
  ({double? number, int entryOrder, DateTime? savedAt}) b,
) {
  if (a.number != null && b.number != null) {
    final byNumber = a.number!.compareTo(b.number!);
    if (byNumber != 0) return byNumber;
  } else if (a.number != null) {
    return -1;
  } else if (b.number != null) {
    return 1;
  }

  final byEntryOrder = a.entryOrder.compareTo(b.entryOrder);
  if (byEntryOrder != 0) return byEntryOrder;

  final at = a.savedAt;
  final bt = b.savedAt;
  if (at != null && bt != null) return at.compareTo(bt);
  return 0;
}

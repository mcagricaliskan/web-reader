import 'dart:convert';

/// User-assisted rules: what the user pointed at when automatic detection was
/// not confident enough, stored locally and reused.
///
/// Everything here is pure Dart so the scoping and matching logic can be tested
/// without a WebView.

enum RuleKind { nextLink, readerArea }

RuleKind ruleKindFromName(String? name) => RuleKind.values.firstWhere(
  (k) => k.name == name,
  orElse: () => RuleKind.nextLink,
);

/// How widely a rule applies. Narrowest wins when several match.
enum RuleScope {
  /// Host + the exact series path. The default and the safest.
  series,

  /// Host + a path shape (e.g. `/manga/*/`), for sites with one layout.
  pathPattern,

  /// Whole host. Only when the user opts in.
  host,
}

RuleScope ruleScopeFromName(String? name) => RuleScope.values.firstWhere(
  (s) => s.name == name,
  orElse: () => RuleScope.series,
);

extension RuleScopeInfo on RuleScope {
  /// Lower is narrower, and narrower wins.
  int get specificity => switch (this) {
    RuleScope.series => 0,
    RuleScope.pathPattern => 1,
    RuleScope.host => 2,
  };

  String get label => switch (this) {
    RuleScope.series => 'this series',
    RuleScope.pathPattern => 'this path pattern',
    RuleScope.host => 'the whole site',
  };
}

/// A deliberately redundant description of an element.
///
/// No single fragile selector: a bag of independent signals, each of which can
/// be scored at apply time. A page that changes its class names still matches
/// on `rel`, link text, or href shape. Long `nth-child` chains and generated
/// ids are excluded on purpose — they look precise and break on the next
/// deploy.
class DomLocator {
  const DomLocator({
    this.tag,
    this.rel,
    this.cssSelector,
    this.containerSelector,
    this.linkText,
    this.ariaLabel,
    this.titleAttr,
    this.imgAlt,
    this.hrefPattern,
    this.imageSelector,
    this.excludeSelectors = const [],
    this.minImageEdge,
  });

  factory DomLocator.fromJson(Map<String, dynamic> json) => DomLocator(
    tag: json['tag'] as String?,
    rel: json['rel'] as String?,
    cssSelector: json['cssSelector'] as String?,
    containerSelector: json['containerSelector'] as String?,
    linkText: json['linkText'] as String?,
    ariaLabel: json['ariaLabel'] as String?,
    titleAttr: json['titleAttr'] as String?,
    imgAlt: json['imgAlt'] as String?,
    hrefPattern: json['hrefPattern'] as String?,
    imageSelector: json['imageSelector'] as String?,
    excludeSelectors: (json['excludeSelectors'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    minImageEdge: (json['minImageEdge'] as num?)?.toInt(),
  );

  factory DomLocator.decode(String jsonText) =>
      DomLocator.fromJson(jsonDecode(jsonText) as Map<String, dynamic>);

  final String? tag;
  final String? rel;

  /// A conservative CSS selector, when one could be built from stable parts.
  /// Null rather than a generated-id or deep-nth-child chain.
  final String? cssSelector;
  final String? containerSelector;
  final String? linkText;
  final String? ariaLabel;
  final String? titleAttr;
  final String? imgAlt;

  /// The example destination's path with digit runs generalised, e.g.
  /// `^/manga/some-series/(\d+)-bolum-oku$`. Strong and layout-independent.
  final String? hrefPattern;

  // Reader-area rules only.
  final String? imageSelector;
  final List<String> excludeSelectors;
  final int? minImageEdge;

  /// How many independent signals this locator carries. One signal is a weak
  /// rule and is reported as such rather than dressed up as a stable one.
  int get signalCount => [
    rel,
    cssSelector,
    containerSelector,
    linkText,
    ariaLabel,
    titleAttr,
    imgAlt,
    hrefPattern,
    imageSelector,
  ].where((s) => s != null && s.trim().isNotEmpty).length;

  bool get isWeak => signalCount < 2;

  Map<String, dynamic> toJson() => {
    if (tag != null) 'tag': tag,
    if (rel != null) 'rel': rel,
    if (cssSelector != null) 'cssSelector': cssSelector,
    if (containerSelector != null) 'containerSelector': containerSelector,
    if (linkText != null) 'linkText': linkText,
    if (ariaLabel != null) 'ariaLabel': ariaLabel,
    if (titleAttr != null) 'titleAttr': titleAttr,
    if (imgAlt != null) 'imgAlt': imgAlt,
    if (hrefPattern != null) 'hrefPattern': hrefPattern,
    if (imageSelector != null) 'imageSelector': imageSelector,
    if (excludeSelectors.isNotEmpty) 'excludeSelectors': excludeSelectors,
    if (minImageEdge != null) 'minImageEdge': minImageEdge,
  };

  String encode() => jsonEncode(toJson());
}

/// A saved rule. Local-first: no account, no sync, no server.
class SiteRule {
  const SiteRule({
    required this.id,
    required this.host,
    required this.scope,
    required this.kind,
    required this.locator,
    required this.createdAt,
    this.seriesPath,
    this.exampleSourceUrl,
    this.exampleTargetUrl,
    this.sameHostOnly = true,
    this.lastUsedAt,
    this.successCount = 0,
    this.failureCount = 0,
  });

  final String id;
  final String host;

  /// Series fingerprint (see [seriesFingerprint]). Null for host-wide rules.
  final String? seriesPath;
  final RuleScope scope;
  final RuleKind kind;
  final DomLocator locator;
  final String? exampleSourceUrl;
  final String? exampleTargetUrl;
  final bool sameHostOnly;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final int successCount;
  final int failureCount;

  /// Does this rule apply to [url]?
  bool matches(String url, {required String kindName}) {
    if (kind.name != kindName) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.host.toLowerCase() != host.toLowerCase()) return false;

    return switch (scope) {
      RuleScope.host => true,
      RuleScope.series =>
        seriesPath != null && seriesFingerprint(url) == seriesPath,
      RuleScope.pathPattern =>
        seriesPath != null && pathShape(uri.path) == seriesPath,
    };
  }
}

/// Identify the series a chapter URL belongs to.
///
/// Drops trailing segments that look like a chapter (a number, or a known
/// chapter word) so that
/// `/manga/some-series/883-bolum-oku` and `/manga/some-series/884-bolum-oku`
/// share the fingerprint `/manga/some-series`.
///
/// This is what stops a rule learned on one series from being applied to an
/// unrelated one on the same host.
String seriesFingerprint(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;

  final segments = uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
  while (segments.isNotEmpty && _looksLikeChapterSegment(segments.last)) {
    segments.removeLast();
  }
  if (segments.isEmpty) return '/';
  return '/${segments.join('/')}';
}

final _chapterWords = RegExp(
  r'(chapter|chap|bolum|bölüm|episode|ep|kapitel|capitulo|capítulo|oku|read|part)',
  caseSensitive: false,
);

bool _looksLikeChapterSegment(String segment) {
  final s = segment.toLowerCase();
  if (RegExp(r'^\d+([._-]\d+)?$').hasMatch(s)) return true;
  if (_chapterWords.hasMatch(s) && RegExp(r'\d').hasMatch(s)) return true;
  if (_chapterWords.hasMatch(s) && s.length <= 12) return true;
  return false;
}

/// A coarser shape for `pathPattern` scope: digit runs and long slugs
/// generalised, so `/manga/a-series/12` and `/manga/b-series/40` share a shape.
String pathShape(String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  while (segments.isNotEmpty && _looksLikeChapterSegment(segments.last)) {
    segments.removeLast();
  }
  final generalised = segments
      .map(
        (s) => RegExp(r'^\d+$').hasMatch(s) ? '*' : (s.length > 24 ? '*' : s),
      )
      .toList();
  if (generalised.isNotEmpty) generalised[generalised.length - 1] = '*';
  return '/${generalised.join('/')}';
}

/// Turn an example destination URL into a reusable path regex:
/// `/manga/some-series/883-bolum-oku` -> `^/manga/some-series/(\d+)-bolum-oku$`
String? hrefPatternFrom(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.path.isEmpty) return null;
  final escaped = RegExp.escape(uri.path);
  final generalised = escaped.replaceAll(RegExp(r'\d+'), r'(\d+)');
  if (!generalised.contains(r'(\d+)')) return null;
  return '^$generalised\$';
}

/// Pick the rule that applies most narrowly. Ties break on most-recently-used,
/// so a rule the user just fixed wins over a stale one.
SiteRule? bestMatchingRule(
  List<SiteRule> rules,
  String url, {
  required RuleKind kind,
}) {
  final candidates =
      rules.where((r) => r.matches(url, kindName: kind.name)).toList()
        ..sort((a, b) {
          final bySpecificity = a.scope.specificity.compareTo(
            b.scope.specificity,
          );
          if (bySpecificity != 0) return bySpecificity;
          final aUsed = a.lastUsedAt ?? a.createdAt;
          final bUsed = b.lastUsedAt ?? b.createdAt;
          return bUsed.compareTo(aUsed);
        });
  return candidates.isEmpty ? null : candidates.first;
}

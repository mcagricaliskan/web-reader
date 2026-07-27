import 'package:uuid/uuid.dart';

import '../browser/browser_controller.dart';
import '../storage/database.dart';
import 'site_rule.dart';

const _uuid = Uuid();

/// Reads and writes user-created site rules, and turns a tapped element into
/// one.
class RuleRepository {
  RuleRepository(this.db);

  final AppDatabase db;

  Future<SiteRule?> findFor(String url, RuleKind kind) async {
    final host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) return null;
    final rows = await db.rulesForHost(host);
    return bestMatchingRule(rows.map(toModel).toList(), url, kind: kind);
  }

  Future<List<SiteRule>> all() async =>
      (await db.watchAllRules().first).map(toModel).toList();

  Future<void> delete(String id) => db.deleteRule(id);

  Future<void> recordUse(String id, {required bool success}) =>
      db.recordRuleUse(id, success: success);

  /// Build a rule from what the user tapped.
  ///
  /// Signals are collected redundantly: `rel`, a conservative selector, the
  /// nav container, the label, and the destination's path shape. If only one
  /// survives, the rule is stored anyway but reported as weak rather than
  /// dressed up as stable.
  Future<SiteRule> createNextLinkRule({
    required SelectedElement element,
    required String sourceUrl,
    RuleScope scope = RuleScope.series,
  }) async {
    final host = Uri.tryParse(sourceUrl)?.host ?? '';
    final locator = DomLocator(
      tag: element.tag,
      rel: element.rel.isEmpty ? null : element.rel,
      cssSelector: element.selector,
      containerSelector: element.containerSelector,
      linkText: element.text.isEmpty ? null : element.text,
      ariaLabel: element.ariaLabel.isEmpty ? null : element.ariaLabel,
      titleAttr: element.title.isEmpty ? null : element.title,
      imgAlt: element.imgAlt.isEmpty ? null : element.imgAlt,
      hrefPattern: element.href.isEmpty ? null : hrefPatternFrom(element.href),
    );

    final rule = SiteRule(
      id: _uuid.v4(),
      host: host,
      seriesPath: _scopeKey(scope, sourceUrl),
      scope: scope,
      kind: RuleKind.nextLink,
      locator: locator,
      exampleSourceUrl: sourceUrl,
      exampleTargetUrl: element.href.isEmpty ? null : element.href,
      createdAt: DateTime.now(),
    );
    await _replaceSameScope(rule);
    await db.upsertRule(_toRow(rule));
    return rule;
  }

  Future<SiteRule> createReaderAreaRule({
    required SelectedElement element,
    required String sourceUrl,
    List<String> excludeSelectors = const [],
    RuleScope scope = RuleScope.series,
  }) async {
    final host = Uri.tryParse(sourceUrl)?.host ?? '';
    final locator = DomLocator(
      tag: element.tag,
      containerSelector: element.selector ?? element.containerSelector,
      imageSelector: element.imageSelector ?? 'img',
      excludeSelectors: excludeSelectors,
      // A floor derived from what is actually in the container, never below a
      // size that would sweep icons back in.
      minImageEdge: element.minImageEdge > 0
          ? (element.minImageEdge * 0.8).round().clamp(100, 2000)
          : 300,
    );

    final rule = SiteRule(
      id: _uuid.v4(),
      host: host,
      seriesPath: _scopeKey(scope, sourceUrl),
      scope: scope,
      kind: RuleKind.readerArea,
      locator: locator,
      exampleSourceUrl: sourceUrl,
      createdAt: DateTime.now(),
    );
    await _replaceSameScope(rule);
    await db.upsertRule(_toRow(rule));
    return rule;
  }

  /// Teaching a rule for a scope that already has one *replaces* it. Letting
  /// them accumulate would leave the winner decided by a timestamp tie-break,
  /// and would quietly keep a rule the user just corrected.
  Future<void> _replaceSameScope(SiteRule incoming) async {
    final existing = await db.rulesForHost(incoming.host);
    for (final row in existing) {
      if (row.kind == incoming.kind.name &&
          row.scope == incoming.scope.name &&
          row.seriesPath == incoming.seriesPath) {
        await db.deleteRule(row.id);
      }
    }
  }

  static String? _scopeKey(RuleScope scope, String url) => switch (scope) {
    RuleScope.series => seriesFingerprint(url),
    RuleScope.pathPattern => pathShape(Uri.tryParse(url)?.path ?? ''),
    RuleScope.host => null,
  };

  static SiteRule toModel(SiteRuleRow row) => SiteRule(
    id: row.id,
    host: row.host,
    seriesPath: row.seriesPath,
    scope: ruleScopeFromName(row.scope),
    kind: ruleKindFromName(row.kind),
    locator: DomLocator.decode(row.locatorJson),
    exampleSourceUrl: row.exampleSourceUrl,
    exampleTargetUrl: row.exampleTargetUrl,
    sameHostOnly: row.sameHostOnly,
    createdAt: row.createdAt,
    lastUsedAt: row.lastUsedAt,
    successCount: row.successCount,
    failureCount: row.failureCount,
  );

  static SiteRuleRow _toRow(SiteRule rule) => SiteRuleRow(
    id: rule.id,
    host: rule.host,
    seriesPath: rule.seriesPath,
    scope: rule.scope.name,
    kind: rule.kind.name,
    locatorJson: rule.locator.encode(),
    exampleSourceUrl: rule.exampleSourceUrl,
    exampleTargetUrl: rule.exampleTargetUrl,
    sameHostOnly: rule.sameHostOnly,
    createdAt: rule.createdAt,
    lastUsedAt: rule.lastUsedAt,
    successCount: rule.successCount,
    failureCount: rule.failureCount,
  );
}

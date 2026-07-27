import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/rule_repository.dart';
import '../capture/site_rule.dart';
import '../providers.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';

/// Saved site rules: what the user taught the app, and how to forget it.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(siteRulesStreamProvider);
    final repo = RuleRepository(ref.watch(databaseProvider));

    return Scaffold(
      appBar: AppBar(title: const Text('Saved rules')),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.ads_click,
                      size: 30,
                      color: Color(0xFF9A948A),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No saved rules',
                      style: TextStyle(
                        fontSize: 16,
                        fontVariations: wght(600),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'When automatic detection is not confident, the capture '
                      'job asks you to point at the next-chapter button or the '
                      'reader area, and remembers what you picked here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: Color(0xFF5F5B54),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final rule in rules) _RuleCard(rule: rule, repo: repo),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  'Rules are matched most-specific first: series, then path '
                  'pattern, then site. Deleting a rule only means the app '
                  'asks you again next time.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF8C877E),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.repo});

  final SiteRule rule;
  final RuleRepository repo;

  @override
  Widget build(BuildContext context) {
    final loc = rule.locator;
    final signals = <String>[
      if (loc.rel != null) 'rel=${loc.rel}',
      if (loc.cssSelector != null) loc.cssSelector!,
      if (loc.containerSelector != null) 'in ${loc.containerSelector}',
      if (loc.linkText != null) '"${loc.linkText}"',
      if (loc.ariaLabel != null) 'aria="${loc.ariaLabel}"',
      if (loc.imgAlt != null) 'alt="${loc.imgAlt}"',
      if (loc.hrefPattern != null) 'href pattern',
      if (loc.imageSelector != null) 'img=${loc.imageSelector}',
    ];

    final scopeIcon = switch (rule.scope) {
      RuleScope.series => Icons.menu_book,
      RuleScope.pathPattern => Icons.bookmark,
      RuleScope.host => Icons.language,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E3DC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(scopeIcon, size: 21, color: const Color(0xFF5F5B54)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontVariations: wght(600),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${rule.kind == RuleKind.nextLink ? 'Next chapter' : 'Reader area'}'
                  ' · ${rule.scope.label}'
                  '${rule.seriesPath != null ? ' · ${rule.seriesPath}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF5F5B54),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  signals.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(size: 11, color: const Color(0xFF3E3A34)),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (rule.successCount > 0) 'used ${rule.successCount}×',
                    if (rule.failureCount > 0) 'failed ${rule.failureCount}×',
                    if (loc.isWeak) 'weak — only 1 signal',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 11,
                    color: loc.isWeak
                        ? const Color(0xFF8A5A1F)
                        : const Color(0xFF8C877E),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: const Color(0xFF5F5B54),
            tooltip: 'Forget this rule',
            onPressed: () => _confirmForget(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmForget(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget this rule?'),
        content: Text(
          'The next capture on ${rule.host} will fall back to automatic '
          'detection, and may ask you to select the control again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (confirmed == true) await repo.delete(rule.id);
  }
}

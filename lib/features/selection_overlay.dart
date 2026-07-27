import 'dart:async';

import 'package:flutter/material.dart';

import '../browser/browser_controller.dart';
import '../capture/next_page.dart';
import '../capture/selection_request.dart';
import '../capture/site_rule.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';

/// Shown when a capture job or an update check is holding for the user to
/// point at a control.
///
/// Follows the design's element-picker sheet: what the app found, what the
/// user picked, and how widely the rule should apply — as tappable cards, not
/// a segmented control.
class RuleSelectionOverlay extends StatefulWidget {
  const RuleSelectionOverlay({
    super.key,
    required this.job,
    required this.request,
  });

  final SelectionHost job;
  final SelectionRequest request;

  @override
  State<RuleSelectionOverlay> createState() => _RuleSelectionOverlayState();
}

class _RuleSelectionOverlayState extends State<RuleSelectionOverlay> {
  SelectedElement? _picked;
  RuleScope _scope = RuleScope.series;
  StreamSubscription<SelectedElement>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.job.browser.selections.listen((element) {
      if (mounted) setState(() => _picked = element);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get _isLink => widget.request.kind == RuleKind.nextLink;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return Material(
      color: const Color(0xFFFBFAF8),
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 420),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFDAD2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _isLink
                    ? 'Show the app the next-chapter control'
                    : 'Show the app where the panels are',
                style: serifStyle(size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                '${request.isRuleFailure ? 'A saved rule stopped working' : 'Automatic detection was not confident'}'
                ': ${request.reason}. '
                '${_isLink ? 'Tap the control that opens the next chapter — taps will not navigate while you are choosing.' : 'Tap the area that contains the chapter images — the app remembers it.'}',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFF5F5B54),
                ),
              ),

              if (request.errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7DDD8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEBC4BC)),
                  ),
                  child: Text(
                    request.errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFF4A140E),
                    ),
                  ),
                ),
              ],

              if (request.candidates.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3EF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE7E3DC)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE7E3DC)),
                          ),
                        ),
                        child: Text(
                          'WHAT THE APP FOUND',
                          style: TextStyle(
                            fontSize: 11.5,
                            letterSpacing: 0.58,
                            fontVariations: wght(600),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5F5B54),
                          ),
                        ),
                      ),
                      for (final c in request.candidates.take(4))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFEDEAE4)),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.help_outline,
                                size: 17,
                                color: Color(0xFF8A5A1F),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  c.href,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    fontSize: 11.5,
                                    color: Color(0xFF3E3A34),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                c.strategy.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8C877E),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              if (_picked == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3EF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDFDAD2)),
                  ),
                  child: const Text(
                    'Nothing selected yet — tap an element in the page above.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF5F5B54),
                    ),
                  ),
                )
              else
                _PickedDetails(element: _picked!, isLink: _isLink),

              const SizedBox(height: 16),
              Text(
                'USE THIS RULE FOR',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  fontVariations: wght(600),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5F5B54),
                ),
              ),
              const SizedBox(height: 8),
              for (final option in const [
                (
                  RuleScope.series,
                  Icons.menu_book,
                  'This series on this host',
                  'Recommended — safest scope',
                ),
                (
                  RuleScope.pathPattern,
                  Icons.bookmark,
                  'Series with this URL shape',
                  'Same path pattern on this site',
                ),
                (
                  RuleScope.host,
                  Icons.language,
                  'Everything on this site',
                  'Widest, may break on other layouts',
                ),
              ]) ...[
                _ScopeCard(
                  icon: option.$2,
                  label: option.$3,
                  sub: option.$4,
                  selected: _scope == option.$1,
                  onTap: () => setState(() => _scope = option.$1),
                ),
                const SizedBox(height: 7),
              ],

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _picked == null
                          ? null
                          : () => widget.job.submitSelection(
                              _picked!,
                              scope: _scope,
                            ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isLink ? 'Use this control' : 'Use this area',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: widget.job.retryAutomaticDetection,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Retry auto'),
                  ),
                ],
              ),
              Center(
                child: TextButton(
                  onPressed: widget.job.cancelSelection,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5F5B54),
                  ),
                  child: const Text('Cancel job'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFEAF1F4) : const Color(0xFFF5F3EF),
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFD2E2E8) : const Color(0xFFE7E3DC),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? const Color(0xFF35606F)
                  : const Color(0xFF5F5B54),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontVariations: wght(500),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF5F5B54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PickedDetails extends StatelessWidget {
  const _PickedDetails({required this.element, required this.isLink});

  final SelectedElement element;
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('tag', '<${element.tag}>'),
      if (element.text.isNotEmpty) ('text', element.text),
      if (isLink) ('url', element.href.isEmpty ? '(no href)' : element.href),
      if (element.rel.isNotEmpty) ('rel', element.rel),
      if (element.ariaLabel.isNotEmpty) ('aria-label', element.ariaLabel),
      if (element.title.isNotEmpty) ('title', element.title),
      if (element.imgAlt.isNotEmpty) ('img alt', element.imgAlt),
      if (element.classes.isNotEmpty) ('stable classes', element.classes),
      if (element.selector != null) ('selector', element.selector!),
      if (element.containerSelector != null)
        ('container', element.containerSelector!),
      if (!isLink) ('images inside', '${element.imageCount}'),
      if (!isLink && element.minImageEdge > 0)
        ('smallest edge', '${element.minImageEdge}px'),
    ];

    final signalCount = [
      element.rel,
      element.selector ?? '',
      element.containerSelector ?? '',
      element.text,
      element.ariaLabel,
      element.title,
      element.imgAlt,
    ].where((s) => s.trim().isNotEmpty).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD2E2E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOU PICKED',
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.58,
              fontVariations: wght(600),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF35606F),
            ),
          ),
          const SizedBox(height: 5),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 11,
                    color: Color(0xFF133845),
                  ),
                  children: [
                    TextSpan(
                      text: '$label  ',
                      style: const TextStyle(color: Color(0xFF3D6270)),
                    ),
                    TextSpan(
                      text: value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            signalCount < 2
                ? 'Only $signalCount stable signal — this rule may break '
                      'when the site changes.'
                : '$signalCount stable signals will be stored.',
            style: TextStyle(
              fontSize: 10.5,
              color: signalCount < 2
                  ? const Color(0xFF8E3B31)
                  : const Color(0xFF3D6270),
            ),
          ),
        ],
      ),
    );
  }
}

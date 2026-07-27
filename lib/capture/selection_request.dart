import 'package:flutter/foundation.dart' show Listenable;

import '../browser/browser_controller.dart';
import 'next_page.dart';
import 'site_rule.dart';

/// Anything that can hold a run while the user points at a page element.
///
/// Implemented by the capture job and by the update checker, so the one
/// selection overlay serves both — the user teaches a rule the same way
/// regardless of which process needed it.
abstract class SelectionHost implements Listenable {
  BrowserController get browser;
  SelectionRequest? get pendingSelection;
  Future<void> submitSelection(SelectedElement element, {RuleScope scope});
  Future<void> cancelSelection();
  Future<void> retryAutomaticDetection();
}

/// What the job is holding for, and why. Shown verbatim in the overlay so the
/// user knows what failed rather than being asked to tap something blindly.
class SelectionRequest {
  const SelectionRequest({
    required this.kind,
    required this.sourceUrl,
    required this.prompt,
    required this.reason,
    this.candidates = const [],
    this.errorMessage,
    this.isRuleFailure = false,
    this.failedRuleId,
  });

  final RuleKind kind;
  final String sourceUrl;
  final String prompt;

  /// Why automatic detection was not trusted.
  final String reason;

  /// What automatic detection did find, so the user can see the near-misses.
  final List<NextCandidate> candidates;

  /// Set when a submitted selection was refused (e.g. it left the host).
  final String? errorMessage;

  /// True when a previously saved rule stopped matching.
  final bool isRuleFailure;
  final String? failedRuleId;

  SelectionRequest withError(String message) => SelectionRequest(
    kind: kind,
    sourceUrl: sourceUrl,
    prompt: prompt,
    reason: reason,
    candidates: candidates,
    errorMessage: message,
    isRuleFailure: isRuleFailure,
    failedRuleId: failedRuleId,
  );
}

/// How a selection prompt ended.
class SelectionOutcome {
  const SelectionOutcome.rule(this.rule, this.element)
    : cancelled = false,
      retryAutomatic = false;

  const SelectionOutcome.cancelled()
    : rule = null,
      element = null,
      cancelled = true,
      retryAutomatic = false;

  const SelectionOutcome.retryAuto()
    : rule = null,
      element = null,
      cancelled = false,
      retryAutomatic = true;

  final SiteRule? rule;
  final SelectedElement? element;
  final bool cancelled;
  final bool retryAutomatic;

  bool get hasRule => rule != null;
}

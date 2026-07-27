import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:drift/drift.dart' show Value;

import '../browser/browser_controller.dart';
import '../browser/page_data.dart';
import '../capture/next_page.dart';
import '../capture/rule_repository.dart';
import '../capture/selection_request.dart';
import '../capture/site_rule.dart';
import '../core/url_utils.dart';
import '../storage/database.dart';
import 'series_identity.dart';

const _uuid = Uuid();

/// Where a check is, right now.
enum UpdateCheckState {
  idle,
  checking,
  upToDate,
  updatesAvailable,

  /// Detection was not confident and the user has not yet pointed at the
  /// control. The check is holding; the selection happens in the Browser tab.
  needsUserInput,
  failed,
  cancelled;

  bool get isTerminal =>
      this == upToDate ||
      this == updatesAvailable ||
      this == failed ||
      this == cancelled;
}

/// Bounds for one check. Everything here exists to make an unbounded crawl
/// structurally impossible.
class UpdateCheckConfig {
  const UpdateCheckConfig({
    this.maxPagesInspected = 12,
    this.maxNewChapters = 20,
    this.maxCheckDuration = const Duration(minutes: 3),
    this.navigationTimeout = const Duration(seconds: 25),
    this.cooldownBetweenPages = const Duration(milliseconds: 800),
  });

  final int maxPagesInspected;
  final int maxNewChapters;
  final Duration maxCheckDuration;
  final Duration navigationTimeout;
  final Duration cooldownBetweenPages;
}

const kDefaultUpdateCheckConfig = UpdateCheckConfig();

/// How one check ended.
class UpdateCheckOutcome {
  const UpdateCheckOutcome({
    required this.state,
    this.newChapters = 0,
    this.pagesInspected = 0,
    this.error,
    this.detail = '',
  });

  final UpdateCheckState state;
  final int newChapters;
  final int pagesInspected;
  final String? error;
  final String detail;
}

/// Foreground, user-triggered "has this series published anything since?".
///
/// Discovers chapter *metadata* only: a discovered chapter becomes a
/// `knownRemote` row with no local content, never a fake offline chapter.
/// Downloading stays a separate, explicit act.
///
/// Reuses the same machinery captures trust: safe-URL validation, the
/// saved-rule → generic next-detection chain, and the user-assisted fallback
/// when confidence is insufficient.
class UpdateChecker extends ChangeNotifier implements SelectionHost {
  UpdateChecker({
    required this.browser,
    required this.db,
    RuleRepository? rules,
    this.config = kDefaultUpdateCheckConfig,
  }) : rules = rules ?? RuleRepository(db);

  @override
  final BrowserController browser;
  final AppDatabase db;
  final RuleRepository rules;
  final UpdateCheckConfig config;

  UpdateCheckState _state = UpdateCheckState.idle;
  UpdateCheckState get state => _state;

  /// The series being checked, while one is.
  String? _activeItemId;
  String? get activeItemId => _activeItemId;

  String _message = '';
  String get message => _message;

  final List<String> _log = [];
  List<String> get log => List.unmodifiable(_log);

  bool _cancelRequested = false;
  bool get isRunning =>
      _state == UpdateCheckState.checking ||
      _state == UpdateCheckState.needsUserInput;

  SelectionRequest? _pendingSelection;
  @override
  SelectionRequest? get pendingSelection => _pendingSelection;
  Completer<SelectionOutcome>? _selectionCompleter;

  /// URLs walked or already known this check; what stops loops.
  final Set<String> _visited = {};

  void _addLog(String message) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    _log.insert(0, '$stamp  $message');
    if (_log.length > 200) _log.removeLast();
    _message = message;
    notifyListeners();
  }

  void cancel() {
    _cancelRequested = true;
    _addLog('cancel requested');
    // A held selection prompt ends with the check.
    _selectionCompleter?.complete(const SelectionOutcome.cancelled());
    _selectionCompleter = null;
    _pendingSelection = null;
    notifyListeners();
  }

  // --- SelectionHost --------------------------------------------------------

  @override
  Future<void> submitSelection(
    SelectedElement element, {
    RuleScope scope = RuleScope.series,
  }) async {
    final request = _pendingSelection;
    if (request == null) return;

    final check = validateNextUrl(
      candidate: element.href,
      currentUrl: request.sourceUrl,
      visited: _visited,
    );
    if (!check.isAccepted) {
      _pendingSelection = request.withError(
        'That link is not usable here (${check.rejection?.name}). '
        'Pick the control that opens the next chapter.',
      );
      notifyListeners();
      return;
    }

    // Save the rule exactly like the capture flow does, at the narrowest
    // scope the user chose — the whole point is that the next check (and the
    // next capture) does not have to ask again.
    final rule = await rules.createNextLinkRule(
      element: element,
      sourceUrl: request.sourceUrl,
      scope: scope,
    );
    _addLog(
      'saved next-link rule for ${rule.host}${rule.seriesPath ?? ""} '
      '(scope: ${rule.scope.label})',
    );

    await browser.stopSelection();
    _pendingSelection = null;
    _selectionCompleter?.complete(SelectionOutcome.rule(rule, element));
    _selectionCompleter = null;
    notifyListeners();
  }

  @override
  Future<void> cancelSelection() async {
    await browser.stopSelection();
    _pendingSelection = null;
    _selectionCompleter?.complete(const SelectionOutcome.cancelled());
    _selectionCompleter = null;
    _addLog('selection cancelled by user');
    notifyListeners();
  }

  @override
  Future<void> retryAutomaticDetection() async {
    await browser.stopSelection();
    _pendingSelection = null;
    _selectionCompleter?.complete(const SelectionOutcome.retryAuto());
    _selectionCompleter = null;
    notifyListeners();
  }

  Future<SelectionOutcome> _askUser(SelectionRequest request) async {
    _pendingSelection = request;
    _selectionCompleter = Completer<SelectionOutcome>();
    _state = UpdateCheckState.needsUserInput;
    _addLog(
      'not confident: ${request.reason} — select the control in the '
      'Browser tab',
    );
    await browser.startSelection(mode: 'link');
    return _selectionCompleter!.future;
  }

  // --- the check -------------------------------------------------------------

  Future<UpdateCheckOutcome> check(String libraryItemId) async {
    if (isRunning) {
      return const UpdateCheckOutcome(
        state: UpdateCheckState.failed,
        error: 'a check is already running',
      );
    }
    if (browser.automationOwner != null) {
      return UpdateCheckOutcome(
        state: UpdateCheckState.failed,
        error: 'cannot check while ${browser.automationOwner} is running',
      );
    }
    if (!browser.isAttached) {
      return const UpdateCheckOutcome(
        state: UpdateCheckState.failed,
        error: 'the browser is not ready yet — open the Browser tab once',
      );
    }

    final item = await db.libraryItemById(libraryItemId);
    if (item == null) {
      return const UpdateCheckOutcome(
        state: UpdateCheckState.failed,
        error: 'series no longer listed',
      );
    }

    final startedAt = DateTime.now();
    _activeItemId = libraryItemId;
    _cancelRequested = false;
    _visited.clear();
    _log.clear();
    _state = UpdateCheckState.checking;
    _addLog('checking "${item.title}" for new chapters');

    browser.automationOwner = 'an update check';
    browser.navigationLocked = true;
    browser.clearAllowedHostChanges();

    UpdateCheckOutcome outcome;
    try {
      outcome = await _run(item).timeout(
        config.maxCheckDuration,
        onTimeout: () {
          // Stop the underlying walk too — the timeout must end navigation,
          // not just stop waiting for it.
          _cancelRequested = true;
          return const UpdateCheckOutcome(
            state: UpdateCheckState.failed,
            error: 'check duration bound reached',
          );
        },
      );
    } catch (e) {
      outcome = UpdateCheckOutcome(
        state: UpdateCheckState.failed,
        error: e.toString(),
      );
    } finally {
      browser.navigationLocked = false;
      browser.automationOwner = null;
      _pendingSelection = null;
      _selectionCompleter = null;
    }

    // Persist the outcome — including failures. "It last failed, and why"
    // is series state the UI must be able to show after a restart.
    final succeeded =
        outcome.state == UpdateCheckState.upToDate ||
        outcome.state == UpdateCheckState.updatesAvailable;
    try {
      await db.writeSeriesCheck(
        libraryItemId,
        LibraryItemsCompanion(
          lastCheckAt: Value(startedAt),
          lastCheckSuccessAt: succeeded
              ? Value(DateTime.now())
              : const Value.absent(),
          lastCheckError: Value(outcome.error),
          lastCheckResult: Value(outcome.state.name),
        ),
      );
    } catch (_) {}

    _state = outcome.state;
    _activeItemId = null;
    _addLog(switch (outcome.state) {
      UpdateCheckState.upToDate => 'up to date — nothing new on the source',
      UpdateCheckState.updatesAvailable =>
        '${outcome.newChapters} new chapter(s) found '
            '(not downloaded — capture is a separate step)',
      UpdateCheckState.cancelled => 'check cancelled',
      _ => 'check failed: ${outcome.error}',
    });
    notifyListeners();
    return outcome;
  }

  Future<UpdateCheckOutcome> _run(LibraryItem item) async {
    final chapters = await db.chaptersForItem(item.id);
    if (chapters.isEmpty) {
      return const UpdateCheckOutcome(
        state: UpdateCheckState.failed,
        error: 'no known chapter to start from',
      );
    }

    for (final c in chapters) {
      _visited.add(c.urlKey);
    }

    double? latestNumber;
    for (final c in chapters) {
      final n = c.chapterNumber;
      if (n != null && (latestNumber == null || n > latestNumber)) {
        latestNumber = n;
      }
    }
    var maxSequence = 0;
    for (final c in chapters) {
      if (c.sequence > maxSequence) maxSequence = c.sequence;
    }

    var pages = 0;
    var found = 0;

    // --- strategy 1: the series page's chapter list ------------------------
    final seriesUrl = item.seriesUrl;
    final seriesKey = item.seriesKey;
    if (seriesUrl != null && seriesUrl.isNotEmpty && seriesKey != null) {
      if (_cancelRequested) {
        return const UpdateCheckOutcome(state: UpdateCheckState.cancelled);
      }
      _addLog('inspecting series page: $seriesUrl');
      final probe = await _navigateAndProbe(seriesUrl);
      pages++;
      if (probe != null) {
        final discovery = discoverFromChapterList(
          probe,
          seriesKey: seriesKey,
          latestKnownNumber: latestNumber,
          knownUrlKeys: _visited,
          maxNew: config.maxNewChapters,
        );
        if (discovery.listRecognised) {
          for (final found_ in discovery.newChapters) {
            maxSequence++;
            await _recordDiscovered(
              item: item,
              url: found_.url,
              title: found_.title,
              number: found_.number,
              sequence: maxSequence,
              basis: 'chapterList',
              confidence: 'high',
            );
            found++;
            _addLog('found: ${found_.title}');
          }
          return UpdateCheckOutcome(
            state: found > 0
                ? UpdateCheckState.updatesAvailable
                : UpdateCheckState.upToDate,
            newChapters: found,
            pagesInspected: pages,
            detail: 'chapter list on the series page',
          );
        }
        _addLog('no recognisable chapter list — walking the chapter chain');
      } else {
        _addLog('series page unreachable — walking the chapter chain');
      }
    }

    // --- strategy 2: follow next-chapter links from the latest known -------
    final ordered = [...chapters]
      ..sort(
        (a, b) => compareChaptersForReading(
          (
            number: a.chapterNumber,
            sequence: a.sequence,
            capturedAt: a.capturedAt,
          ),
          (
            number: b.chapterNumber,
            sequence: b.sequence,
            capturedAt: b.capturedAt,
          ),
        ),
      );
    final latest = ordered.last;
    _addLog('latest known: ${latest.chapterLabel ?? latest.title}');

    String? next;
    final storedNext = latest.nextSourceUrl;
    if (storedNext != null) {
      final check = validateNextUrl(
        candidate: storedNext,
        currentUrl: latest.sourceUrl,
        visited: _visited,
      );
      next = check.isAccepted ? check.normalized : null;
    }
    if (next == null) {
      // Only now open the latest chapter's own page to read its next link.
      if (_cancelRequested) {
        return UpdateCheckOutcome(
          state: UpdateCheckState.cancelled,
          newChapters: found,
        );
      }
      final probe = await _navigateAndProbe(latest.sourceUrl);
      pages++;
      if (probe == null) {
        return UpdateCheckOutcome(
          state: UpdateCheckState.failed,
          error: 'could not open the latest known chapter',
          pagesInspected: pages,
        );
      }
      final resolved = await _resolveNext(probe, latest.sourceUrl);
      if (resolved.cancelled) {
        return UpdateCheckOutcome(
          state: UpdateCheckState.cancelled,
          pagesInspected: pages,
        );
      }
      next = resolved.url;
    }

    while (next != null &&
        found < config.maxNewChapters &&
        pages < config.maxPagesInspected) {
      if (_cancelRequested) {
        return UpdateCheckOutcome(
          state: UpdateCheckState.cancelled,
          newChapters: found,
          pagesInspected: pages,
        );
      }

      // The chain may not leave the series: a "next" that jumps to another
      // series (or a login page — the validator already rejects those paths)
      // ends the check instead of being followed.
      if (seriesFingerprint(next) != seriesFingerprint(latest.sourceUrl)) {
        _addLog('next link leaves the series — stopping: $next');
        break;
      }

      final probe = await _navigateAndProbe(next);
      pages++;
      if (probe == null) {
        _addLog('page unreachable, stopping: $next');
        break;
      }

      final landed = browser.currentUrl.isEmpty ? next : browser.currentUrl;
      final landedKey = normalizeUrl(landed);
      if (_visited.contains(landedKey)) {
        _addLog('landed on an already known chapter — stopping');
        break;
      }
      if (seriesFingerprint(landed) != seriesFingerprint(next)) {
        _addLog('redirect left the series — stopping');
        break;
      }
      _visited.add(landedKey);

      final title = probe.title.trim().isEmpty
          ? (browser.title.isEmpty ? landed : browser.title)
          : probe.title;

      // Resolve this page's own next link before recording, so the row can
      // carry it — the next check continues the chain without a page load.
      final resolved = await _resolveNext(probe, landed);

      maxSequence++;
      await _recordDiscovered(
        item: item,
        url: landed,
        title: title,
        number: parseChapterNumber(title: title, url: landed),
        sequence: maxSequence,
        basis: 'nextChain',
        confidence: resolved.confidence ?? 'high',
        nextSourceUrl: resolved.url,
      );
      found++;
      _addLog('found: $title');

      if (resolved.cancelled) {
        return UpdateCheckOutcome(
          state: UpdateCheckState.cancelled,
          newChapters: found,
          pagesInspected: pages,
        );
      }
      next = resolved.url;
      if (next == null) _addLog('end of chain');
      await Future<void>.delayed(config.cooldownBetweenPages);
    }

    if (next != null && pages >= config.maxPagesInspected) {
      _addLog('page bound reached with more chapters possibly remaining');
    }
    if (next != null && found >= config.maxNewChapters) {
      _addLog('new-chapter bound reached; check again to continue');
    }

    return UpdateCheckOutcome(
      state: found > 0
          ? UpdateCheckState.updatesAvailable
          : UpdateCheckState.upToDate,
      newChapters: found,
      pagesInspected: pages,
      detail: 'chapter chain from the latest known chapter',
    );
  }

  /// Saved rule first, then the generic chain; ask the user only when
  /// detection is not confident, exactly like a capture would.
  Future<({String? url, String? confidence, bool cancelled})> _resolveNext(
    PageProbe probe,
    String currentUrl,
  ) async {
    String? ruleHref;
    final rule = await rules.findFor(currentUrl, RuleKind.nextLink);
    if (rule != null) {
      final match = await browser.applyLocator(rule.locator.toJson());
      if (match != null && match.isMatch) {
        ruleHref = match.href;
        await rules.recordUse(rule.id, success: true);
      } else {
        _addLog('saved next-link rule did not match here');
        await rules.recordUse(rule.id, success: false);
      }
    }

    var result = resolveNextPage(
      probe,
      currentUrl: currentUrl,
      visitedNormalized: _visited,
      ruleHref: ruleHref,
    );

    if (result.needsUserSelection && !_cancelRequested) {
      final outcome = await _askUser(
        SelectionRequest(
          kind: RuleKind.nextLink,
          sourceUrl: currentUrl,
          prompt: 'Select the next chapter button',
          reason: result.reason,
          candidates: result.considered,
        ),
      );
      _state = UpdateCheckState.checking;
      notifyListeners();

      if (outcome.cancelled) {
        return (url: null, confidence: null, cancelled: true);
      }
      if (outcome.retryAutomatic) {
        result = resolveNextPage(
          probe,
          currentUrl: currentUrl,
          visitedNormalized: _visited,
        );
      } else if (outcome.hasRule) {
        final match = await browser.applyLocator(
          outcome.rule!.locator.toJson(),
        );
        final href = match?.isMatch == true
            ? match!.href
            : (outcome.element?.href ?? '');
        final check = validateNextUrl(
          candidate: href,
          currentUrl: currentUrl,
          visited: _visited,
        );
        return (
          url: check.isAccepted ? check.normalized : null,
          confidence: 'high',
          cancelled: false,
        );
      }
    }

    return (
      url: result.hasNext ? result.chosen!.href : null,
      confidence:
          result.chosen?.confidence?.name ??
          result.chosen?.strategy.baseConfidence.name,
      cancelled: false,
    );
  }

  Future<PageProbe?> _navigateAndProbe(String url) async {
    try {
      browser.allowNextNavigation(url);
      await browser.loadAndWait(url, timeout: config.navigationTimeout);
      await Future<void>.delayed(config.cooldownBetweenPages);
      var probe = await browser.probe(withLinks: true);
      // Same protection as capture (the hidden-tab class of bug): a
      // zero-viewport WebView answers probes with unmeasurable layout. A
      // check reads links rather than geometry, but "measure nothing on an
      // unrendered surface" is one rule, not two.
      var warned = false;
      while (probe.viewportHeight <= 0 && !_cancelRequested) {
        if (!warned) {
          warned = true;
          _addLog(
            'browser surface is not rendered — open the Browser to continue '
            'the check',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        probe = await browser.probe(withLinks: true);
      }
      if (_cancelRequested) return null;
      return probe;
    } catch (e) {
      _addLog('navigation failed: $e');
      return null;
    }
  }

  Future<void> _recordDiscovered({
    required LibraryItem item,
    required String url,
    required String title,
    required double? number,
    required int sequence,
    required String basis,
    required String confidence,
    String? nextSourceUrl,
  }) async {
    final key = normalizeUrl(url);
    _visited.add(key);
    final existing = await db.findChapterByUrlKey(item.id, key);
    if (existing != null) return; // already known — never a duplicate row

    await db.upsertChapter(
      Chapter(
        id: _uuid.v4(),
        libraryItemId: item.id,
        title: title,
        sourceUrl: url,
        urlKey: key,
        // Known to exist on the source; holds nothing locally. Everything
        // that means "readable offline" keys off contentPath + status, so
        // this can never masquerade as an offline chapter.
        captureStatus: 'knownRemote',
        contentPath: null,
        capturedAt: null,
        detectedImageCount: 0,
        storedImageCount: 0,
        nextSourceUrl: nextSourceUrl,
        sequence: sequence,
        captureError: null,
        byteSize: 0,
        chapterNumber: number,
        chapterLabel: chapterLabelFrom(title: title, url: url, number: number),
        readStatus: 'unread',
        progressFraction: 0,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
        discoveredAt: DateTime.now(),
        discoveryBasis: basis,
        discoveryConfidence: confidence,
      ),
    );
  }
}

/// One chapter link found on a series page.
class DiscoveredChapter {
  const DiscoveredChapter({
    required this.url,
    required this.title,
    this.number,
  });

  final String url;
  final String title;
  final double? number;
}

class ChapterListDiscovery {
  const ChapterListDiscovery({
    required this.listRecognised,
    required this.newChapters,
    this.knownSeen = 0,
  });

  /// Whether the page plausibly showed this series' chapter list at all.
  /// False means "fall back to the chain walk", not "up to date".
  final bool listRecognised;
  final List<DiscoveredChapter> newChapters;
  final int knownSeen;
}

/// Read a series page's chapter list. Pure — unit tested against literal
/// probes.
///
/// A link counts as a chapter link when it stays on the same series path and
/// carries a parseable chapter number. New = a number above the latest known
/// (or an unknown URL when nothing is numbered — but never merged on a
/// guess: unnumbered unknown links are ignored rather than recorded, because
/// "new" cannot be established for them from a list alone).
ChapterListDiscovery discoverFromChapterList(
  PageProbe probe, {
  required String seriesKey,
  required double? latestKnownNumber,
  required Set<String> knownUrlKeys,
  int maxNew = 20,
}) {
  final base = probe.url;
  final seen = <String>{};
  final chapterLinks = <DiscoveredChapter>[];
  var knownSeen = 0;

  for (final link in probe.links) {
    final resolved = resolveUrl(base, link.href);
    if (resolved == null) continue;
    if (hostOf(resolved).toLowerCase() != hostOf(base).toLowerCase()) continue;
    if (seriesFingerprint(resolved) != seriesKey) continue;

    final key = normalizeUrl(resolved);
    if (!seen.add(key)) continue;

    final number = parseChapterNumber(title: link.text, url: resolved);
    if (number == null) continue;

    if (knownUrlKeys.contains(key)) {
      knownSeen++;
      continue;
    }
    chapterLinks.add(
      DiscoveredChapter(
        url: resolved,
        title: link.text.trim().isEmpty ? resolved : link.text.trim(),
        number: number,
      ),
    );
  }

  // Recognised = the page demonstrably lists this series' chapters: either
  // it shows chapters we already hold, or several numbered same-series
  // links. A page with neither tells us nothing and must not produce
  // "up to date".
  final recognised = knownSeen > 0 || (knownSeen + chapterLinks.length) >= 2;

  final fresh =
      chapterLinks
          .where(
            (c) =>
                latestKnownNumber == null ||
                (c.number ?? 0) > latestKnownNumber,
          )
          .toList()
        ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));

  return ChapterListDiscovery(
    listRecognised: recognised,
    newChapters: fresh.take(maxNew).toList(),
    knownSeen: knownSeen,
  );
}

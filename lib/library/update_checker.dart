import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:drift/drift.dart' show Value;

import '../browser/browser_controller.dart';
import '../browser/history_repository.dart' show NavigationSource;
import '../browser/page_data.dart';
import '../save/next_page.dart';
import '../save/page_hint_repository.dart';
import '../save/selection_request.dart';
import '../save/page_hint.dart';
import '../core/url_utils.dart';
import '../storage/database.dart';
import '../storage/manifest.dart';
import 'collection_identity.dart';
import 'content_shape.dart';

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
    this.maxNewEntries = 20,
    this.maxCheckDuration = const Duration(minutes: 3),
    this.navigationTimeout = const Duration(seconds: 25),
    this.cooldownBetweenPages = const Duration(milliseconds: 800),
  });

  final int maxPagesInspected;
  final int maxNewEntries;
  final Duration maxCheckDuration;
  final Duration navigationTimeout;
  final Duration cooldownBetweenPages;
}

const kDefaultUpdateCheckConfig = UpdateCheckConfig();

/// How one check ended.
class UpdateCheckOutcome {
  const UpdateCheckOutcome({
    required this.state,
    this.newEntries = 0,
    this.pagesInspected = 0,
    this.error,
    this.detail = '',
  });

  final UpdateCheckState state;
  final int newEntries;
  final int pagesInspected;
  final String? error;
  final String detail;
}

/// Foreground, user-triggered "has this collection published anything since?".
///
/// Discovers entry *metadata* only: a discovered entry becomes a
/// `knownRemote` row with no local content, never a fake offline entry.
/// Downloading stays a separate, explicit act.
///
/// Reuses the same machinery saves trust: safe-URL validation, the
/// saved-rule → generic next-detection chain, and the user-assisted fallback
/// when confidence is insufficient.
class UpdateChecker extends ChangeNotifier implements SelectionHost {
  UpdateChecker({
    required this.browser,
    required this.db,
    PageHintRepository? rules,
    this.config = kDefaultUpdateCheckConfig,
  }) : rules = rules ?? PageHintRepository(db);

  @override
  final BrowserController browser;
  final AppDatabase db;
  final PageHintRepository rules;
  final UpdateCheckConfig config;

  UpdateCheckState _state = UpdateCheckState.idle;
  UpdateCheckState get state => _state;

  /// The collection being checked, while one is.
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
    HintScope scope = HintScope.collection,
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
        'Pick the control that opens the next entry.',
      );
      notifyListeners();
      return;
    }

    // Save the rule exactly like the save flow does, at the narrowest
    // scope the user chose — the whole point is that the next check (and the
    // next save) does not have to ask again.
    final rule = await rules.createNextLinkHint(
      element: element,
      sourceUrl: request.sourceUrl,
      scope: scope,
    );
    _addLog(
      'saved next-link rule for ${rule.host}${rule.hintPath ?? ""} '
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

  Future<UpdateCheckOutcome> check(String collectionId) async {
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

    final item = await db.collectionById(collectionId);
    if (item == null) {
      return const UpdateCheckOutcome(
        state: UpdateCheckState.failed,
        error: 'collection no longer listed',
      );
    }

    final startedAt = DateTime.now();
    _activeItemId = collectionId;
    _cancelRequested = false;
    _visited.clear();
    _log.clear();
    _state = UpdateCheckState.checking;
    _addLog('checking "${item.title}" for new entries');

    browser.automationOwner = 'an update check';
    // Reading an entry list is the app asking the source a question, not a
    // page the user visited — excluded from browsing history (D53).
    browser.navigationSource = NavigationSource.updateCheck;
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
      browser.navigationSource = NavigationSource.manual;
      _pendingSelection = null;
      _selectionCompleter = null;
    }

    // Persist the outcome — including failures. "It last failed, and why"
    // is collection state the UI must be able to show after a restart.
    final succeeded =
        outcome.state == UpdateCheckState.upToDate ||
        outcome.state == UpdateCheckState.updatesAvailable;
    try {
      await db.writeCollectionCheck(
        collectionId,
        CollectionsCompanion(
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
        '${outcome.newEntries} new entry(s) found '
            '(not downloaded — save is a separate step)',
      UpdateCheckState.cancelled => 'check cancelled',
      _ => 'check failed: ${outcome.error}',
    });
    notifyListeners();
    return outcome;
  }

  Future<UpdateCheckOutcome> _run(Collection item) async {
    final entries = await db.entriesForCollection(item.id);
    if (entries.isEmpty) {
      return const UpdateCheckOutcome(
        state: UpdateCheckState.failed,
        error: 'no known entry to start from',
      );
    }

    for (final c in entries) {
      _visited.add(c.urlKey);
    }

    double? latestNumber;
    for (final c in entries) {
      final n = c.entryNumber;
      if (n != null && (latestNumber == null || n > latestNumber)) {
        latestNumber = n;
      }
    }
    var maxEntryOrder = 0;
    for (final c in entries) {
      if (c.entryOrder > maxEntryOrder) maxEntryOrder = c.entryOrder;
    }

    var pages = 0;
    var found = 0;

    // --- strategy 1: the collection page's entry list ------------------------
    final collectionIndexUrl = item.collectionIndexUrl;
    final collectionKey = item.collectionKey;
    if (collectionIndexUrl != null &&
        collectionIndexUrl.isNotEmpty &&
        collectionKey != null) {
      if (_cancelRequested) {
        return const UpdateCheckOutcome(state: UpdateCheckState.cancelled);
      }
      _addLog('inspecting collection page: $collectionIndexUrl');
      final probe = await _navigateAndProbe(collectionIndexUrl);
      pages++;
      if (probe != null) {
        final discovery = discoverFromEntryList(
          probe,
          collectionKey: collectionKey,
          latestKnownNumber: latestNumber,
          knownUrlKeys: _visited,
          maxNew: config.maxNewEntries,
        );
        _addLog(
          'entry list: ${discovery.direction.name}, '
          '${discovery.knownSeen} already held, '
          '${discovery.newEntries.length} new'
          '${discovery.orderingConfident ? '' : ' (ordering unclear)'}',
        );
        if (discovery.dropped > 0) {
          _addLog(
            '${discovery.dropped} further new entry(s) left for the next '
            'check (limit ${config.maxNewEntries})',
          );
        }
        // Trusting an empty result means declaring the collection up to date
        // without looking any further. That is only safe when the list's own
        // ordering was unambiguous; otherwise "nothing above the checkpoint"
        // may just mean we could not tell what was above it, and the chain
        // walk gets its turn.
        if (discovery.listRecognised &&
            (discovery.newEntries.isNotEmpty || discovery.orderingConfident)) {
          for (final found_ in discovery.newEntries) {
            maxEntryOrder++;
            await _recordDiscovered(
              item: item,
              url: found_.url,
              title: found_.title,
              number: found_.number,
              entryOrder: maxEntryOrder,
              basis: 'entryList',
              confidence: 'high',
            );
            found++;
            _addLog('found: ${found_.title}');
          }
          return UpdateCheckOutcome(
            state: found > 0
                ? UpdateCheckState.updatesAvailable
                : UpdateCheckState.upToDate,
            newEntries: found,
            pagesInspected: pages,
            detail: 'entry list on the collection page',
          );
        }
        _addLog(
          discovery.listRecognised
              ? 'entry list gave nothing but could not be ordered — '
                    'walking the entry chain'
              : 'no recognisable entry list — walking the entry chain',
        );
      } else {
        _addLog('collection page unreachable — walking the entry chain');
      }
    }

    // --- strategy 2: follow next-entry links from the latest known -------
    final ordered = [...entries]
      ..sort(
        (a, b) => compareEntriesForReading(
          (number: a.entryNumber, entryOrder: a.entryOrder, savedAt: a.savedAt),
          (number: b.entryNumber, entryOrder: b.entryOrder, savedAt: b.savedAt),
        ),
      );
    final latest = ordered.last;
    _addLog('latest known: ${latest.sourceMarker ?? latest.title}');

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
      // Only now open the latest entry's own page to read its next link.
      if (_cancelRequested) {
        return UpdateCheckOutcome(
          state: UpdateCheckState.cancelled,
          newEntries: found,
        );
      }
      final probe = await _navigateAndProbe(latest.sourceUrl);
      pages++;
      if (probe == null) {
        return UpdateCheckOutcome(
          state: UpdateCheckState.failed,
          error: 'could not open the latest known entry',
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
        found < config.maxNewEntries &&
        pages < config.maxPagesInspected) {
      if (_cancelRequested) {
        return UpdateCheckOutcome(
          state: UpdateCheckState.cancelled,
          newEntries: found,
          pagesInspected: pages,
        );
      }

      // The chain may not leave the collection: a "next" that jumps to another
      // collection (or a login page — the validator already rejects those paths)
      // ends the check instead of being followed.
      if (collectionFingerprint(next) !=
          collectionFingerprint(latest.sourceUrl)) {
        _addLog('next link leaves the collection — stopping: $next');
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
        _addLog('landed on an already known entry — stopping');
        break;
      }
      if (collectionFingerprint(landed) != collectionFingerprint(next)) {
        _addLog('redirect left the collection — stopping');
        break;
      }
      _visited.add(landedKey);

      final title = probe.title.trim().isEmpty
          ? (browser.title.isEmpty ? landed : browser.title)
          : probe.title;

      // Resolve this page's own next link before recording, so the row can
      // carry it — the next check continues the chain without a page load.
      final resolved = await _resolveNext(probe, landed);

      maxEntryOrder++;
      await _recordDiscovered(
        item: item,
        url: landed,
        title: title,
        number: parseEntryNumber(title: title, url: landed),
        entryOrder: maxEntryOrder,
        basis: 'nextChain',
        confidence: resolved.confidence ?? 'high',
        nextSourceUrl: resolved.url,
      );
      found++;
      _addLog('found: $title');

      if (resolved.cancelled) {
        return UpdateCheckOutcome(
          state: UpdateCheckState.cancelled,
          newEntries: found,
          pagesInspected: pages,
        );
      }
      next = resolved.url;
      if (next == null) _addLog('end of chain');
      await Future<void>.delayed(config.cooldownBetweenPages);
    }

    if (next != null && pages >= config.maxPagesInspected) {
      _addLog('page bound reached with more entries possibly remaining');
    }
    if (next != null && found >= config.maxNewEntries) {
      _addLog('new-entry bound reached; check again to continue');
    }

    return UpdateCheckOutcome(
      state: found > 0
          ? UpdateCheckState.updatesAvailable
          : UpdateCheckState.upToDate,
      newEntries: found,
      pagesInspected: pages,
      detail: 'entry chain from the latest known entry',
    );
  }

  /// Saved rule first, then the generic chain; ask the user only when
  /// detection is not confident, exactly like a save would.
  Future<({String? url, String? confidence, bool cancelled})> _resolveNext(
    PageProbe probe,
    String currentUrl,
  ) async {
    String? hintHref;
    final rule = await rules.findFor(currentUrl, HintKind.nextLink);
    if (rule != null) {
      final match = await browser.applyLocator(rule.locator.toJson());
      if (match != null && match.isMatch) {
        hintHref = match.href;
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
      hintHref: hintHref,
    );

    if (result.needsUserSelection && !_cancelRequested) {
      final outcome = await _askUser(
        SelectionRequest(
          kind: HintKind.nextLink,
          sourceUrl: currentUrl,
          prompt: 'Select the next entry button',
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
      // Same protection as save (the hidden-tab class of bug): a
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
    required Collection item,
    required String url,
    required String title,
    required double? number,
    required int entryOrder,
    required String basis,
    required String confidence,
    String? nextSourceUrl,
  }) async {
    final key = normalizeUrl(url);
    _visited.add(key);
    final existing = await db.findEntryByUrlKey(item.id, key);
    if (existing != null) return; // already known — never a duplicate row

    await db.upsertEntry(
      Entry(
        id: _uuid.v4(),
        collectionId: item.id,
        title: title,
        sourceUrl: url,
        urlKey: key,
        host: Uri.tryParse(url)?.host.toLowerCase() ?? '',
        // Discovery reads a list of links, not the pages themselves, so it has
        // no evidence about what any of them contains. `unknownWebContent` at
        // `low` is the honest answer, and the collection's own shape is what the
        // UI labels these with until one is actually opened and saved.
        contentKind: ContentKind.unknownWebContent.name,
        contentKindConfidence: ShapeConfidence.low.name,
        contentKindIsUserSet: false,
        // Nothing is stored, so there is no artifact yet. The column carries
        // its default rather than a claim: a discovered entry has no package,
        // and `save_status`/`content_path` are what say so.
        artifactFormat: ArtifactFormat.imageSequence.name,
        // Known to exist at the source; holds nothing locally. Everything that
        // means "readable offline" keys off contentPath + status, so this can
        // never masquerade as an offline entry.
        saveStatus: 'knownRemote',
        contentPath: null,
        savedAt: null,
        detectedAssetCount: 0,
        storedAssetCount: 0,
        nextSourceUrl: nextSourceUrl,
        entryOrder: entryOrder,
        saveError: null,
        byteSize: 0,
        entryNumber: number,
        sourceMarker: sourceMarkerFrom(title: title, url: url, number: number),
        readStatus: 'unread',
        progressFraction: 0,
        progressPageIndex: 0,
        progressOffsetInPage: 0,
        discoveredAt: DateTime.now(),
        discoveryBasis: basis,
        discoveryConfidence: confidence,
      ),
    );
  }
}

/// One entry link found on a collection page.
class DiscoveredEntry {
  const DiscoveredEntry({required this.url, required this.title, this.number});

  final String url;
  final String title;
  final double? number;
}

/// Which way an entry list runs down the page.
///
/// Most sites list newest first; some list oldest first; a few are not
/// ordered coherently at all. Getting this wrong is what makes an update
/// check save entry 1 when the user wanted 386.
enum EntryListDirection { newestFirst, oldestFirst, unknown }

class EntryListDiscovery {
  const EntryListDiscovery({
    required this.listRecognised,
    required this.newEntries,
    this.knownSeen = 0,
    this.direction = EntryListDirection.unknown,
    this.orderingConfident = false,
    this.dropped = 0,
  });

  /// Whether the page plausibly showed this collection's entry list at all.
  /// False means "fall back to the chain walk", not "up to date".
  final bool listRecognised;

  /// New entries in **save order: oldest first**, so a partial run leaves
  /// a contiguous block rather than holes.
  final List<DiscoveredEntry> newEntries;
  final int knownSeen;

  /// Which way the list ran, as read off the page itself.
  final EntryListDirection direction;

  /// True only when the list's own ordering was unambiguous. An empty result
  /// from a list we could not order is *not* evidence of being up to date —
  /// see the caller, which keeps walking the chain in that case.
  final bool orderingConfident;

  /// New entries found but cut by `maxNew`. Reported rather than silently
  /// dropped: the next check picks them up, and the log should say so.
  final int dropped;
}

/// One same-collection link, with the two things ordering can be read from: the
/// number in its label and its position in the list.
class _EntryLink {
  _EntryLink({
    required this.index,
    required this.url,
    required this.key,
    required this.title,
    required this.number,
    required this.depth,
  }) : position = number;

  final int index;
  final String url;
  final String key;
  final String title;
  final double? number;
  final int depth;

  /// Where this entry sits on the number line: its own number, or — for an
  /// unnumbered one — a value interpolated from its numbered neighbours.
  /// Null only when the list offers nothing to interpolate from.
  double? position;
}

/// Whether a link is an entry *of this collection*.
///
/// [collectionFingerprint] answers this for ordinary entries by dropping a
/// trailing entry-looking segment. It cannot for an entry whose slug is
/// just a word — `/guide/foo/extra`, `/guide/foo/side-story` — which keeps
/// its own segment and so fingerprints as a different collection. Those are
/// admitted on structure instead: exactly one segment below the collection path.
/// (What stops that from admitting `/guide/foo/comments` is the caller, which
/// only keeps an unnumbered link that sits *inside* the numbered run.)
bool _belongsToCollection(String url, String collectionKey) {
  if (collectionFingerprint(url) == collectionKey) return true;
  final path = Uri.tryParse(url)?.path;
  if (path == null) return false;
  final trailing = RegExp(r'/+$');
  final prefix = '${collectionKey.replaceAll(trailing, '')}/';
  final trimmed = path.replaceAll(trailing, '');
  if (!trimmed.startsWith(prefix)) return false;
  return !trimmed.substring(prefix.length).contains('/');
}

int _pathDepth(String url) =>
    Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty).length ?? 0;

/// Read a collection page's entry list. Pure — unit tested against literal
/// probes.
///
/// Three things this has to get right, in order of how often they bite:
///
/// 1. **Newest-to-oldest lists.** The links arrive in DOM order, which is the
///    site's own ordering. That ordering is measured (not assumed) and used
///    to emit new entries oldest-first, whichever way the page runs.
/// 2. **Decimals.** `385 < 385.5 < 386`; comparisons are on the parsed
///    numbers, never on text.
/// 3. **Unnumbered entries.** `"Extra"`, `"Prologue"`, `"Side Story"` have no
///    number to compare, so they are placed by position relative to the
///    entries already held — not discarded, which is what used to happen.
///
/// "Starting from the middle" falls out of the same rule: the checkpoint is
/// the highest number already held plus the set of known URLs, so a library
/// holding 100–105 of 400 finds 106 onwards and saves upward from there.
EntryListDiscovery discoverFromEntryList(
  PageProbe probe, {
  required String collectionKey,
  required double? latestKnownNumber,
  required Set<String> knownUrlKeys,
  int maxNew = 20,
}) {
  final base = probe.url;
  final baseKey = normalizeUrl(base);
  final seen = <String>{};
  final candidates = <_EntryLink>[];

  for (final link in probe.links) {
    final resolved = resolveUrl(base, link.href);
    if (resolved == null) continue;
    if (hostOf(resolved).toLowerCase() != hostOf(base).toLowerCase()) continue;
    if (!_belongsToCollection(resolved, collectionKey)) continue;

    final key = normalizeUrl(resolved);
    // The collection page links to itself from its own header; that is not a
    // entry.
    if (key == baseKey) continue;
    if (!seen.add(key)) continue;

    candidates.add(
      _EntryLink(
        index: candidates.length,
        url: resolved,
        key: key,
        title: link.text.trim().isEmpty ? resolved : link.text.trim(),
        number: parseEntryNumber(title: link.text, url: resolved),
        depth: _pathDepth(resolved),
      ),
    );
  }

  final numbered = candidates.where((c) => c.number != null).toList();

  // An unnumbered link only counts as an entry when it sits inside the
  // numbered run and at the same URL depth. Without that, a collection page's
  // "comments" or "bookmark" link would be saved as an entry — which is
  // why these used to be dropped outright.
  final modalDepth = _modalDepth(numbered);
  final firstNumbered = numbered.isEmpty ? -1 : numbered.first.index;
  final lastNumbered = numbered.isEmpty ? -1 : numbered.last.index;
  final links = candidates.where((c) {
    if (c.number != null) return true;
    if (knownUrlKeys.contains(c.key)) return true;
    return c.depth == modalDepth &&
        c.index > firstNumbered &&
        c.index < lastNumbered;
  }).toList();

  // Give every unnumbered entry a place on the number line by interpolating
  // between its numbered neighbours in list order: a "Side Story" between
  // 386 and 385 belongs at 385.5. That is what lets the *same* comparison
  // decide novelty and ordering for numbered and unnumbered entries alike —
  // and it is immune to the shortcut links ("First Entry", "Latest") that
  // real collection pages put above their list.
  _interpolateUnnumbered(links);

  // --- which way does the list run? ---------------------------------------
  //
  // Reported, and used only to gate early stopping. Deliberately tolerant:
  // those same shortcut links break strict monotonicity on both sites this
  // project verifies against, so a majority with a clear margin is what a
  // real entry list looks like.
  var ascendingPairs = 0;
  var descendingPairs = 0;
  for (var i = 1; i < numbered.length; i++) {
    final delta = numbered[i].number!.compareTo(numbered[i - 1].number!);
    if (delta > 0) {
      ascendingPairs++;
    } else if (delta < 0) {
      descendingPairs++;
    }
  }
  final orderedPairs = ascendingPairs + descendingPairs;
  final majority = descendingPairs >= ascendingPairs
      ? descendingPairs
      : ascendingPairs;
  final decided = orderedPairs > 0 && majority >= orderedPairs * 0.8;
  final direction = !decided
      ? EntryListDirection.unknown
      : descendingPairs > ascendingPairs
      ? EntryListDirection.newestFirst
      : EntryListDirection.oldestFirst;
  // Enough entries for the majority to mean something. Two links that happen
  // to descend are a coincidence; three or more are an ordering.
  final confident =
      direction != EntryListDirection.unknown && numbered.length >= 3;

  var knownSeen = 0;
  for (final c in links) {
    if (knownUrlKeys.contains(c.key)) knownSeen++;
  }

  // --- which of them are new ----------------------------------------------
  final fresh = <_EntryLink>[];
  for (final c in links) {
    if (knownUrlKeys.contains(c.key)) continue;
    final position = c.position;
    final bool isNew;
    if (latestKnownNumber == null) {
      // Nothing to measure against: the first check reports the whole list.
      isNew = true;
    } else if (position != null) {
      // Decimal-safe by construction: 385.5 > 385, and 386 > 385.5.
      isNew = position > latestKnownNumber;
    } else {
      // Neither a number nor a numbered neighbour. "New" cannot be
      // established from a list alone, so it is not claimed.
      isNew = false;
    }
    if (isNew) fresh.add(c);
  }

  // --- oldest first, so save runs forward -------------------------------
  fresh.sort((a, b) {
    final ap = a.position;
    final bp = b.position;
    if (ap != null && bp != null) {
      final byNumber = ap.compareTo(bp);
      if (byNumber != 0) return byNumber;
    } else if (ap != null) {
      return -1;
    } else if (bp != null) {
      return 1;
    }
    return a.index.compareTo(b.index);
  });

  // Recognised = the page demonstrably lists this collection's entries: either
  // it shows entries we already hold, or several numbered same-collection
  // links. A page with neither tells us nothing and must not produce
  // "up to date".
  final recognised = knownSeen > 0 || numbered.length >= 2;

  return EntryListDiscovery(
    listRecognised: recognised,
    newEntries: fresh
        .take(maxNew)
        .map(
          (c) => DiscoveredEntry(url: c.url, title: c.title, number: c.number),
        )
        .toList(),
    knownSeen: knownSeen,
    direction: direction,
    orderingConfident: confident,
    dropped: fresh.length > maxNew ? fresh.length - maxNew : 0,
  );
}

/// Place each unnumbered entry between its numbered neighbours in list
/// order. With neighbours on both sides it lands midway between them; with
/// only one side it borrows that neighbour's number, which keeps it adjacent
/// to where the site put it. With no numbered neighbour at all it stays
/// null — and an entry with no position is never claimed as new.
void _interpolateUnnumbered(List<_EntryLink> links) {
  for (var i = 0; i < links.length; i++) {
    if (links[i].number != null) continue;
    double? before;
    for (var j = i - 1; j >= 0; j--) {
      if (links[j].number != null) {
        before = links[j].number;
        break;
      }
    }
    double? after;
    for (var j = i + 1; j < links.length; j++) {
      if (links[j].number != null) {
        after = links[j].number;
        break;
      }
    }
    links[i].position = before != null && after != null
        ? (before + after) / 2
        : (before ?? after);
  }
}

/// The URL depth most of the numbered entry links share.
int _modalDepth(List<_EntryLink> numbered) {
  if (numbered.isEmpty) return -1;
  final counts = <int, int>{};
  for (final c in numbered) {
    counts[c.depth] = (counts[c.depth] ?? 0) + 1;
  }
  var best = numbered.first.depth;
  for (final entry in counts.entries) {
    if (entry.value > (counts[best] ?? 0)) best = entry.key;
  }
  return best;
}

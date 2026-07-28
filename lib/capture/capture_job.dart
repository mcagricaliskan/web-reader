import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../browser/browser_controller.dart';
import '../browser/history_repository.dart' show NavigationSource;
import '../core/config.dart';
import '../core/device_storage.dart';
import '../core/url_utils.dart';
import '../storage/database.dart';
import '../storage/file_store.dart';
import 'asset_downloader.dart';
import 'capture_engine.dart';
import 'capture_preflight.dart';
import 'capture_state.dart';
import '../library/series_identity.dart';
import 'next_page.dart';
import 'rule_repository.dart';
import 'selection_request.dart';
import 'site_rule.dart';

const _uuid = Uuid();

/// The persisted pause reason for "the user left the Browser mid-capture".
const kPauseBrowserHidden = 'browserHidden';

/// How a capture run was launched (D58).
///
/// The distinction is not cosmetic: a `direct` run holds the Browser the user
/// is looking at right now and was never a pending queue entry, so it must not
/// become one — not when it is interrupted, and not when it finishes.
enum CaptureOrigin {
  /// Started straight from the Browser's capture sheet ("Start Capture").
  direct,

  /// Released from the capture queue by an explicit Start.
  queue,
}

CaptureOrigin captureOriginFromName(String? name) => CaptureOrigin.values
    .firstWhere((o) => o.name == name, orElse: () => CaptureOrigin.queue);

/// What a finished run *was*, kept after the run so the Browser can show a
/// result without the run's live progress standing in as the current state.
///
/// Page-scoped by construction: [pageSession] is the Browser page identity the
/// run ended on, and the Browser shows this only while that page is still the
/// page on screen (D59). Durable history lives in Activity, not here.
class CaptureRunRecord {
  const CaptureRunRecord({
    required this.jobId,
    required this.origin,
    required this.state,
    required this.urlKey,
    required this.pageSession,
    required this.storedChapters,
    required this.skippedChapters,
    required this.message,
    this.error,
  });

  final String jobId;
  final CaptureOrigin origin;
  final CaptureState state;

  /// Canonical identity of the page the run ended on.
  final String urlKey;
  final int pageSession;
  final int storedChapters;
  final int skippedChapters;
  final String message;
  final String? error;

  bool get succeeded =>
      state == CaptureState.complete || state == CaptureState.partial;
}

/// Drives a bounded multi-chapter run: capture, find next, validate, navigate,
/// repeat. Only one job runs at a time.
///
/// Job state is written to the database on every meaningful transition so an
/// interrupted run is recognisable after a restart. Resume is always offered,
/// never automatic — resuming navigates a WebView and hits a remote site,
/// which needs user intent.
class CaptureJobController extends ChangeNotifier implements SelectionHost {
  CaptureJobController({
    required this.browser,
    required this.db,
    required this.fileStore,
    RuleRepository? rules,
    this.config = kDefaultCaptureConfig,
    DeviceStorage? deviceStorage,
  }) : rules = rules ?? RuleRepository(db),
       deviceStorage = deviceStorage ?? DeviceStorage();

  @override
  final BrowserController browser;
  final AppDatabase db;
  final FileStore fileStore;
  final RuleRepository rules;
  final CaptureConfig config;
  final DeviceStorage deviceStorage;

  CaptureProgress _progress = const CaptureProgress();
  CaptureProgress get progress => _progress;

  final List<String> _log = [];
  List<String> get log => List.unmodifiable(_log);

  CaptureEngine? _engine;
  String? _jobId;
  bool _running = false;

  /// How the run in progress (or the last one) was launched.
  CaptureOrigin origin = CaptureOrigin.queue;

  CaptureRunRecord? _lastRun;

  /// The finished run's result, or null when nothing has finished since the
  /// last start. Transient by design: the Browser presents it only for the
  /// page it belongs to, and Activity holds the durable copy (D59).
  CaptureRunRecord? get lastRun => _lastRun;

  /// Drop the finished-run result — the user acknowledged it, or the Browser
  /// moved to another page.
  void clearLastRun() {
    if (_lastRun == null) return;
    _lastRun = null;
    notifyListeners();
  }

  /// Canonical identity of the page this run is working on, or empty when
  /// nothing is running. What "is this page capturing?" is answered with.
  String get activePageKey =>
      _running || isPaused ? pageIdentityKey(_progress.currentUrl) : '';

  /// True while a run exists that owns the WebView or is holding mid-run —
  /// which includes a paused one. A finished run is not active, however
  /// recently it finished.
  bool get hasActiveRun => _running || isPaused;

  bool _skipRequested = false;
  bool _retryRequested = false;
  bool _stopRequested = false;
  final Set<String> _visited = {};

  /// Set while the job is holding for the user to point at a control.
  SelectionRequest? _pendingSelection;
  @override
  SelectionRequest? get pendingSelection => _pendingSelection;
  Completer<SelectionOutcome>? _selectionCompleter;

  /// Set while the job is holding on an already-captured chapter, waiting for
  /// the user's skip / re-download / stop decision.
  DuplicateRequest? _pendingDuplicate;
  DuplicateRequest? get pendingDuplicate => _pendingDuplicate;
  Completer<DuplicateChoice>? _duplicateCompleter;

  /// Session-scoped duplicate answers. Reset by [start], persisted with the
  /// job so an interrupted-session resume keeps them, never stored anywhere
  /// global.
  SessionDuplicateDecision sessionDuplicateDecision =
      SessionDuplicateDecision.ask;
  SessionPartialDecision sessionPartialDecision = SessionPartialDecision.ask;

  bool get isRunning => _running;
  bool get isPaused => _progress.state == CaptureState.paused;
  String? get jobId => _jobId;

  void _addLog(String message) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    // Driver exceptions carry the entire failing SQL statement; a log line that
    // long is unreadable in the panel and drowns everything around it.
    final trimmed = message.length > 300
        ? '${message.substring(0, 300)}… (truncated)'
        : message;
    _log.insert(0, '$stamp  $trimmed');
    if (_log.length > 300) _log.removeLast();
    notifyListeners();
  }

  void _setProgress(CaptureProgress Function(CaptureProgress) update) {
    final next = update(_progress);
    if (!isTransitionAllowed(_progress.state, next.state)) {
      // A rejected transition is a bug in the engine, not something to paper
      // over — surface it in the log rather than silently accepting it.
      _addLog(
        'illegal transition ${_progress.state.name} -> ${next.state.name}',
      );
    }
    _progress = next;
    notifyListeners();
  }

  // --- controls -----------------------------------------------------------

  /// Test seams: put the controller in a running state without standing up
  /// a real run, so the leave-Browser rules can be exercised per phase.
  @visibleForTesting
  void debugSetRunning(bool value) => _running = value;

  @visibleForTesting
  void debugSetProgress(CaptureProgress progress) {
    _jobId ??= _uuid.v4();
    _progress = progress;
    notifyListeners();
  }

  @visibleForTesting
  Future<void> debugPersist() => _persistJob(
    _progress.state,
    _progress.currentUrl,
    _progress.storedChapters,
  );

  /// Why the run is paused, when it is paused for a reason worth persisting
  /// and naming in the UI. `browserHidden` is the leave-the-Browser pause.
  String? pauseReason;

  void pause() {
    pauseReason = null;
    _engine?.pause();
    _addLog('paused by user');
    notifyListeners();
  }

  /// The user left the Browser while a rendered-WebView phase was running.
  /// The run holds exactly where it is: nothing scrolls, nothing extracts,
  /// nothing is marked complete, and the queue task keeps the reason so
  /// Activity can say "Browser required" instead of a bare "paused".
  void pauseForBrowserHidden() {
    if (!_running || isPaused) return;
    pauseReason = kPauseBrowserHidden;
    _engine?.pause();
    _addLog('paused — the Browser was left while capture needed it');
    unawaited(
      _persistJob(
        _progress.state,
        _progress.currentUrl,
        _progress.storedChapters,
      ),
    );
    notifyListeners();
  }

  /// Back on the Browser and the surface is usable again.
  void resumeAfterBrowserVisible() {
    if (pauseReason != kPauseBrowserHidden) return;
    pauseReason = null;
    _engine?.resume();
    _addLog('resumed — the Browser is visible again');
    final id = _jobId;
    unawaited(() async {
      await _persistJob(
        _progress.state,
        _progress.currentUrl,
        _progress.storedChapters,
      );
      // Explicit: a null on the data class would be treated as "leave it".
      if (id != null) await db.clearJobPauseReason(id);
    }());
    notifyListeners();
  }

  /// True while a phase that genuinely needs a rendered WebView is running:
  /// inspecting, scrolling, waiting for page assets, verifying, extracting,
  /// detecting the next link, or navigating. Downloading and saving read
  /// bytes over HTTP and touch no layout — leaving during those is safe, so
  /// the confirmation must not appear.
  bool get needsRenderedBrowser {
    // Already held for this exact reason: asking again would be noise.
    if (!_running || isPaused || pauseReason != null) return false;
    return switch (_progress.state) {
      CaptureState.inspecting ||
      CaptureState.scrolling ||
      CaptureState.waitingForAssets ||
      CaptureState.verifying ||
      CaptureState.extracting ||
      CaptureState.detectingNext ||
      CaptureState.navigating => true,
      _ => false,
    };
  }

  /// One line for the leave dialog: what this run has done so far.
  String get progressSummary {
    final p = _progress;
    final parts = <String>[
      if (p.chapterTitle.isNotEmpty) p.chapterTitle,
      '${p.storedChapters} captured',
      if (p.skippedChapters > 0) '${p.skippedChapters} skipped',
      if (p.requestedChapters > p.storedChapters)
        '${p.requestedChapters - p.storedChapters} remaining',
    ];
    return parts.join(' · ');
  }

  void resume() {
    _engine?.resume();
    _addLog('resumed by user');
    notifyListeners();
  }

  void stop() {
    // Held on the controller, not only forwarded to the engine: between
    // chapters there is no engine to cancel, and Stop must still be honoured.
    _stopRequested = true;
    _engine?.cancel();
    _addLog('stop requested');
    notifyListeners();
  }

  void skipCurrentChapter() {
    _skipRequested = true;
    _engine?.cancel();
    _addLog('skip requested');
  }

  /// The user picked an element in the WebView.
  @override
  Future<void> submitSelection(
    SelectedElement element, {
    RuleScope scope = RuleScope.series,
  }) async {
    final request = _pendingSelection;
    if (request == null) return;

    if (request.kind == RuleKind.nextLink) {
      // A user-selected control is a strong signal about one link — it is not
      // permission to follow it anywhere. Validate exactly as if the page had
      // offered it automatically.
      final check = validateNextUrl(
        candidate: element.href,
        currentUrl: request.sourceUrl,
        visited: _visited,
      );
      if (!check.isAccepted) {
        _addLog('selection rejected: ${check.rejection?.name}');
        _pendingSelection = request.withError(
          'That link is not usable here (${check.rejection?.name}). '
          'Pick the control that opens the next chapter.',
        );
        notifyListeners();
        return;
      }
    }

    final rule = request.kind == RuleKind.nextLink
        ? await rules.createNextLinkRule(
            element: element,
            sourceUrl: request.sourceUrl,
            scope: scope,
          )
        : await rules.createReaderAreaRule(
            element: element,
            sourceUrl: request.sourceUrl,
            scope: scope,
          );

    _addLog(
      'saved ${rule.kind.name} rule for ${rule.host}'
      '${rule.seriesPath ?? ""} (scope: ${rule.scope.label}, '
      '${rule.locator.signalCount} signal(s)'
      '${rule.locator.isWeak ? ", weak" : ""})',
    );

    await browser.stopSelection();
    _pendingSelection = null;
    _selectionCompleter?.complete(SelectionOutcome.rule(rule, element));
    _selectionCompleter = null;
    notifyListeners();
  }

  /// The user gave up on selecting; end the job rather than guess.
  @override
  Future<void> cancelSelection() async {
    await browser.stopSelection();
    _pendingSelection = null;
    _selectionCompleter?.complete(const SelectionOutcome.cancelled());
    _selectionCompleter = null;
    _addLog('selection cancelled by user');
    notifyListeners();
  }

  /// Let the user teach a rule mid-job, before detection has failed.
  void requestNextLinkSelection() =>
      _manualSelectionRequest = RuleKind.nextLink;

  void requestReaderAreaSelection() =>
      _manualSelectionRequest = RuleKind.readerArea;

  RuleKind? _manualSelectionRequest;

  /// Try automatic detection once more instead of picking by hand.
  @override
  Future<void> retryAutomaticDetection() async {
    await browser.stopSelection();
    _pendingSelection = null;
    _selectionCompleter?.complete(const SelectionOutcome.retryAuto());
    _selectionCompleter = null;
    _addLog('retrying automatic detection');
    notifyListeners();
  }

  Future<SelectionOutcome> _askUser(SelectionRequest request) async {
    _pendingSelection = request;
    _selectionCompleter = Completer<SelectionOutcome>();
    _setProgress(
      (p) => p.copyWith(
        state: CaptureState.awaitingSelection,
        message: request.prompt,
      ),
    );
    _addLog('asking the user: ${request.prompt} — ${request.reason}');
    await browser.startSelection(
      mode: request.kind == RuleKind.nextLink ? 'link' : 'reader',
    );
    return _selectionCompleter!.future;
  }

  void retryCurrentChapter() {
    _retryRequested = true;
    _engine?.cancel();
    _addLog('retry requested');
  }

  /// The user answered the mid-run duplicate prompt.
  void resolveDuplicate(DuplicateChoice choice) {
    if (_pendingDuplicate == null) return;
    _pendingDuplicate = null;
    _duplicateCompleter?.complete(choice);
    _duplicateCompleter = null;
    notifyListeners();
  }

  Future<DuplicateChoice> _askDuplicate(DuplicateRequest request) async {
    _pendingDuplicate = request;
    _duplicateCompleter = Completer<DuplicateChoice>();
    _setProgress(
      (p) => p.copyWith(
        state: CaptureState.awaitingSelection,
        message: request.title,
        currentUrl: request.preflight.url,
      ),
    );
    _addLog(
      'holding: ${request.title} '
      '(${request.chapter?.chapterLabel ?? request.preflight.url})',
    );
    return _duplicateCompleter!.future;
  }

  /// Turn the user's answer into the loop action, recording it for the rest
  /// of the session when asked to. Stop is deliberately not recordable.
  DuplicateAction _applyDuplicateChoice(
    DuplicateChoice choice,
    ChapterLocalState state,
  ) {
    final isComplete = state == ChapterLocalState.complete;
    switch (choice.action) {
      case DuplicateChoiceAction.stopCapture:
        return DuplicateAction.skip; // unreachable; stop handled by caller
      case DuplicateChoiceAction.skip:
        if (choice.applyToSession) {
          if (isComplete) {
            sessionDuplicateDecision =
                SessionDuplicateDecision.skipCompleteForSession;
            _addLog('session policy: skip already-saved chapters');
          } else {
            sessionPartialDecision = SessionPartialDecision.skipForSession;
            _addLog('session policy: skip partial/failed chapters');
          }
        }
        return DuplicateAction.skip;
      case DuplicateChoiceAction.redownload:
      case DuplicateChoiceAction.retryMissing:
      case DuplicateChoiceAction.restartChapter:
        if (choice.applyToSession) {
          if (isComplete) {
            sessionDuplicateDecision =
                SessionDuplicateDecision.replaceCompleteForSession;
            _addLog('session policy: re-download already-saved chapters');
          } else {
            sessionPartialDecision = SessionPartialDecision.retryForSession;
            _addLog('session policy: re-attempt partial/failed chapters');
          }
        }
        return DuplicateAction.capture;
    }
  }

  // --- running ------------------------------------------------------------

  /// How this job treats chapters that already exist. Chosen by the user in
  /// the preflight sheet, then applied without asking again.
  DuplicatePolicy duplicatePolicy = DuplicatePolicy.skipComplete;

  /// How the current job's range was chosen. Persisted with the job so a
  /// resume keeps the mode.
  CaptureRangeMode rangeMode = CaptureRangeMode.fixedCount;

  Future<void> start({
    required int chapterLimit,
    String? startUrl,
    DuplicatePolicy policy = DuplicatePolicy.skipComplete,
    SessionDuplicateDecision sessionDuplicate = SessionDuplicateDecision.ask,
    SessionPartialDecision sessionPartial = SessionPartialDecision.ask,
    CaptureRangeMode range = CaptureRangeMode.fixedCount,
    CaptureOrigin origin = CaptureOrigin.direct,
  }) async {
    if (_running) return;
    if (browser.automationOwner != null) {
      _addLog('cannot start: ${browser.automationOwner} is using the browser');
      return;
    }
    // The flag flips before the first await: `isRunning` must be true from
    // the moment start() is called, or a caller can observe a started job
    // that claims to be idle.
    _running = true;
    this.origin = origin;
    // A new run replaces the previous run's result — never accumulates with
    // it, and never leaves it to be read as this run's outcome.
    _lastRun = null;
    // Identity from the first moment, not from the first chapter: a run that
    // refuses to start is still a run, and it still has a result to report.
    _jobId = _uuid.v4();

    // Disk preflight: starting a capture that cannot write is worse than
    // refusing one. Unknown free space is allowed through (the rolling
    // per-chapter check will also try, and refusing to capture because a
    // platform call failed would be policy by accident).
    final free = await deviceStorage.freeBytes();
    if (free != null && free < config.minFreeSpaceToStart) {
      _running = false;
      _log.clear();
      _addLog(
        'refused to start: ${_mb(free)} free, '
        'minimum ${_mb(config.minFreeSpaceToStart)} (insufficientStorage)',
      );
      _setProgress(
        (_) => const CaptureProgress().copyWith(
          state: CaptureState.failed,
          lastError: 'insufficientStorage',
          message:
              'Not enough space to start — existing downloads are not '
              'affected.',
        ),
      );
      _publishRunRecord(startUrl ?? browser.currentUrl);
      return;
    }

    _stopRequested = false;
    _skipRequested = false;
    _retryRequested = false;
    _visited.clear();
    _log.clear();

    duplicatePolicy = policy;
    // Session decisions are per-job. A resume passes the interrupted job's
    // answers back in; a fresh job always starts at "ask".
    sessionDuplicateDecision = sessionDuplicate;
    sessionPartialDecision = sessionPartial;
    rangeMode = range;
    final limit = switch (range) {
      CaptureRangeMode.currentChapter => 1,
      CaptureRangeMode.fixedCount => chapterLimit.clamp(
        1,
        config.maxChaptersPerJob,
      ),
      // "Until the end" is bounded by the safety limit, never by a count the
      // user typed — hitting it reports its own distinct result.
      CaptureRangeMode.untilEnd => config.untilEndSafetyLimit,
    };
    final beginUrl = startUrl ?? browser.currentUrl;

    _setProgress(
      (_) => CaptureProgress(
        state: CaptureState.inspecting,
        currentUrl: beginUrl,
        requestedChapters: limit,
        chapterIndex: 1,
      ),
    );

    await _persistJob(CaptureState.inspecting, beginUrl, 0);
    _addLog(
      'job ${_jobId!.substring(0, 8)} start · ${range.name} · '
      'limit $limit · $beginUrl',
    );

    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Not fatal — the run just needs the user to keep the screen alive.
    }

    // While the job runs the page may not navigate itself. A user-selected
    // control is a strong signal about one link, not permission to follow
    // whatever the page does next.
    browser.navigationLocked = true;
    browser.automationOwner = 'a capture job';
    // The chapter chain is the app walking the site, not the user browsing
    // it: these pages never enter browsing history (D53).
    browser.navigationSource = NavigationSource.captureAutomation;
    // A host the user allowed while browsing is not thereby allowed for an
    // unattended run — make the job earn its own consent.
    browser.clearAllowedHostChanges();
    browser.allowNextNavigation(beginUrl);

    try {
      await _runLoop(limit: limit, startUrl: beginUrl);
    } finally {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      browser.navigationLocked = false;
      browser.automationOwner = null;
      browser.navigationSource = NavigationSource.manual;
      _running = false;
      _engine = null;
      _pendingDuplicate = null;
      _duplicateCompleter = null;
      pauseReason = null;
      _publishRunRecord(_progress.currentUrl);
      notifyListeners();
    }
  }

  /// Turn the run that just ended into a page-scoped result.
  ///
  /// [progress] is deliberately left alone: it is the run's own record, which
  /// Activity, the copy-log and the integration suites all read after the fact.
  /// What changes is that the Browser no longer *derives page state from it* —
  /// it reads this record, and only while its page is still on screen (D59).
  void _publishRunRecord(String endedAtUrl) {
    final id = _jobId;
    if (id == null) return;
    _lastRun = CaptureRunRecord(
      jobId: id,
      origin: origin,
      state: _progress.state,
      urlKey: pageIdentityKey(
        endedAtUrl.isEmpty ? _progress.currentUrl : endedAtUrl,
      ),
      pageSession: browser.pageSession,
      storedChapters: _progress.storedChapters,
      skippedChapters: _progress.skippedChapters,
      message: _progress.message,
      error: _progress.lastError,
    );
  }

  Future<void> _runLoop({required int limit, required String startUrl}) async {
    final jobDeadline = DateTime.now().add(
      rangeMode == CaptureRangeMode.untilEnd
          ? config.untilEndJobDuration
          : config.maxJobDuration,
    );
    var url = startUrl;
    var stored = 0;
    var hitSafetyLimit = false;
    var diskStop = false;

    /// New capture attempts. This — not pages walked — is what the requested
    /// count means: "capture 3 chapters" starting inside saved territory
    /// captures 3 new ones, it does not spend the request on skips.
    var attempts = 0;

    /// Pages walked, including skips. Drives `sequence` (chain order).
    var traversed = 0;
    var skipped = 0;
    LibraryItem? item;
    var attemptsForCurrent = 0;
    var isRetry = false;

    while (attempts < limit) {
      if (_stopRequested) {
        _setProgress((p) => p.copyWith(state: CaptureState.cancelled));
        await _persistJob(CaptureState.cancelled, url, stored);
        _addLog('job cancelled after $stored chapter(s)');
        return;
      }
      if (DateTime.now().isAfter(jobDeadline)) {
        _addLog('job duration bound reached');
        break;
      }
      if (skipped >= config.maxSkippedPerJob) {
        _addLog(
          'skipped ${config.maxSkippedPerJob} chapters without finding new '
          'ones — stopping rather than crawling on',
        );
        break;
      }

      // Rolling disk check: multi-chapter and until-end runs must not write
      // the device into the ground. Estimated from this series' own chapters
      // when it has any; the conservative default otherwise.
      final free = await deviceStorage.freeBytes();
      if (free != null) {
        final estimate = await _estimateChapterBytes(item);
        if (free < config.emergencyReserve + estimate) {
          _addLog(
            'stopping before the next chapter: ${_mb(free)} free, need '
            '~${_mb(estimate)} plus the ${_mb(config.emergencyReserve)} '
            'reserve (insufficientStorage)',
          );
          diskStop = true;
          break;
        }
      }

      // A retry re-captures the page the browser is already on; everything
      // about it (preflight, navigation, ordinal) has already happened.
      if (!isRetry) {
        traversed++;

        // What already exists here, and what to do about it — decided BEFORE
        // navigating, so a skip with a stored next-URL costs no page load,
        // and before anything downloads either way.
        final decision = await _decideDuplicate(url, item, traversed);
        if (decision == null) return; // user stopped the job at the prompt
        if (decision.action == DuplicateAction.skip) {
          skipped++;
          final moved = await _continueAfterSkip(decision.preflight, url);
          if (moved == null) break;
          url = moved;
          continue;
        }
        attempts++;
      }
      isRetry = false;

      _setProgress(
        (p) => p.copyWith(
          chapterIndex: attempts,
          currentUrl: url,
          detectedImages: 0,
          storedImages: 0,
          failedImages: 0,
          scrollPercent: 0,
          retryCount: attemptsForCurrent,
          clearError: true,
        ),
      );

      // Navigate unless the browser is already showing this page. That is
      // usually true for the first walked chapter (capture started from the
      // page on screen) — but not when the job was started from the library
      // ("Capture new chapters") with the WebView parked somewhere else.
      final alreadyOnPage =
          browser.currentUrl.isNotEmpty &&
          normalizeUrl(browser.currentUrl) == normalizeUrl(url);
      if (traversed > 1 || !alreadyOnPage) {
        _setProgress((p) => p.copyWith(state: CaptureState.navigating));
        await _persistJob(CaptureState.navigating, url, stored);
        _addLog('opening $url');
        browser.allowNextNavigation(url);
        await browser.loadAndWait(url);
        await Future<void>.delayed(config.cooldownBetweenChapters);

        // Where we landed after redirects is what matters, not where we aimed.
        final landed = browser.currentUrl;
        if (landed.isNotEmpty && normalizeUrl(landed) != normalizeUrl(url)) {
          final check = validateNextUrl(
            candidate: landed,
            currentUrl: url,
            visited: _visited,
          );
          if (!check.isAccepted) {
            _addLog(
              'redirected to an unsafe destination '
              '(${check.rejection?.name}): $landed',
            );
            break;
          }
          if (seriesFingerprint(landed) != seriesFingerprint(url)) {
            _addLog(
              'redirect left the series '
              '(${seriesFingerprint(url)} -> ${seriesFingerprint(landed)}) — '
              'stopping rather than capturing something else',
            );
            break;
          }
          _addLog('followed redirect to $landed');
          url = check.normalized!;

          // The redirect may have landed on a chapter we already hold — the
          // duplicate decision applies to where we ARE, not where we aimed.
          final landedDecision = await _decideDuplicate(url, item, traversed);
          if (landedDecision == null) return;
          if (landedDecision.action == DuplicateAction.skip) {
            attempts--; // nothing was attempted here after all
            skipped++;
            final moved = await _continueAfterSkip(
              landedDecision.preflight,
              url,
            );
            if (moved == null) break;
            url = moved;
            continue;
          }
        }
      }

      _visited.add(normalizeUrl(url));

      final probeUrl = browser.currentUrl.isEmpty ? url : browser.currentUrl;
      // Series hints come from the page itself; the probe carries them
      // alongside the links it already collects.
      if (item == null) {
        SeriesHints hints = const SeriesHints();
        try {
          hints = (await browser.probe(withLinks: true)).seriesHints;
        } catch (_) {
          // Not fatal — identity falls back to the URL fingerprint.
        }
        item = await ensureLibraryItem(
          db: db,
          url: probeUrl,
          title: browser.title,
          hints: hints,
          log: _addLog,
        );
      }

      final preflight = await CapturePreflight(
        db: db,
        fileStore: fileStore,
      ).inspect(probeUrl, libraryItemId: item.id, ignoreJobId: _jobId);
      final existing = preflight.chapter;

      final replacing = preflight.existsLocally;
      if (replacing) {
        // Replacement holds the old and new copy simultaneously — that
        // moment needs headroom for BOTH, or a failed rename could meet a
        // full disk with the readable copy stepped aside.
        final free = await deviceStorage.freeBytes();
        final oldSize = existing?.byteSize ?? 0;
        if (free != null && free < config.emergencyReserve + oldSize) {
          _addLog(
            'not replacing "${existing?.title ?? probeUrl}": ${_mb(free)} '
            'free cannot hold both copies (insufficientStorage) — the '
            'existing capture is kept',
          );
          diskStop = true;
          break;
        }
        _addLog(
          'replacing existing ${preflight.state.name} capture: '
          '${existing?.title ?? probeUrl}',
        );
        _setProgress((p) => p.copyWith(message: 'Replacing existing capture'));
      }

      _engine = CaptureEngine(
        browser: browser,
        db: db,
        fileStore: fileStore,
        downloader: AssetDownloader(browser: browser, config: config),
        config: config,
        onProgress: _setProgress,
        onLog: _addLog,
      );

      await _persistJob(CaptureState.inspecting, url, stored);

      // The user asked to teach a rule before anything failed.
      if (_manualSelectionRequest != null) {
        final kind = _manualSelectionRequest!;
        _manualSelectionRequest = null;
        final outcome = await _askUser(
          SelectionRequest(
            kind: kind,
            sourceUrl: url,
            prompt: kind == RuleKind.nextLink
                ? 'Select the next chapter button'
                : 'Select the reader area',
            reason: 'requested by you',
          ),
        );
        if (outcome.cancelled) {
          _setProgress((p) => p.copyWith(state: CaptureState.cancelled));
          await _persistJob(CaptureState.cancelled, url, stored);
          return;
        }
      }

      // Narrowest applicable rule the user taught us for this page, if any.
      var readerRule = await rules.findFor(url, RuleKind.readerArea);
      final nextRule = await rules.findFor(url, RuleKind.nextLink);
      if (readerRule != null) {
        _addLog('using saved reader-area rule (${readerRule.scope.label})');
      }
      if (nextRule != null) {
        _addLog('using saved next-link rule (${nextRule.scope.label})');
      }

      var result = await _engine!.captureCurrentPage(
        libraryItemId: item.id,
        sequence: traversed,
        visitedNormalized: _visited,
        readerRule: readerRule,
        nextRule: nextRule,
        replaceExisting: replacing,
      );

      // Extraction failed, or a saved reader rule stopped matching. Ask the
      // user to point at the reader area rather than guessing at another
      // container.
      if (!_stopRequested &&
          (result.extractionFailed || result.readerRuleFailed)) {
        if (result.readerRuleFailed && readerRule != null) {
          await rules.recordUse(readerRule.id, success: false);
        }
        final outcome = await _askUser(
          SelectionRequest(
            kind: RuleKind.readerArea,
            sourceUrl: result.pageUrl.isEmpty ? url : result.pageUrl,
            prompt: 'Select the reader area',
            reason: result.error ?? 'automatic extraction found too little',
            isRuleFailure: result.readerRuleFailed,
            failedRuleId: readerRule?.id,
          ),
        );
        if (outcome.cancelled) {
          _setProgress((p) => p.copyWith(state: CaptureState.cancelled));
          await _persistJob(CaptureState.cancelled, url, stored);
          _addLog('job ended: user cancelled the reader-area selection');
          return;
        }
        if (outcome.hasRule && result.readerRuleFailed && readerRule != null) {
          await rules.delete(readerRule.id);
          _addLog('replaced the broken reader-area rule');
        }
        readerRule = outcome.rule ?? readerRule;
        _engine?.reset();
        result = await _engine!.captureCurrentPage(
          libraryItemId: item.id,
          sequence: traversed,
          visitedNormalized: _visited,
          readerRule: readerRule,
          nextRule: nextRule,
        );
      }

      // Skip / retry / stop are surfaced through cancellation.
      if (_skipRequested) {
        _skipRequested = false;
        _addLog('chapter skipped by user');
        _engine?.reset();
        final next = await _peekNextFromPage(url);
        if (next == null) break;
        url = next;
        attemptsForCurrent = 0;
        continue;
      }
      if (_retryRequested) {
        _retryRequested = false;
        attemptsForCurrent++;
        _engine?.reset();
        _addLog('retrying chapter (attempt ${attemptsForCurrent + 1})');
        isRetry = true; // same chapter, same attempt — no re-preflight
        continue;
      }
      if (result.error == 'cancelled') {
        _setProgress((p) => p.copyWith(state: CaptureState.cancelled));
        await _persistJob(CaptureState.cancelled, url, stored);
        _addLog('job cancelled after $stored chapter(s)');
        return;
      }

      if (result.isUsable) {
        stored++;
        attemptsForCurrent = 0;
        _setProgress((p) => p.copyWith(storedChapters: stored));
        await _persistJob(CaptureState.saving, url, stored);
      } else {
        _addLog('chapter failed: ${result.error}');
        await _persistJob(
          CaptureState.failed,
          url,
          stored,
          error: result.error,
        );
        // A chapter failure is not a job failure: try to keep walking.
        final next = await _peekNextFromPage(url);
        if (next == null) {
          _setProgress(
            (p) =>
                p.copyWith(state: CaptureState.failed, lastError: result.error),
          );
          await _persistJob(
            CaptureState.failed,
            url,
            stored,
            error: result.error,
          );
          return;
        }
        url = next;
        continue;
      }

      if (attempts >= limit) {
        if (rangeMode == CaptureRangeMode.untilEnd && result.nextUrl != null) {
          // The chain went on but the safety bound did not — say so
          // distinctly; this is not a confirmed end of the series.
          hitSafetyLimit = true;
          _addLog(
            'until-end safety limit ($limit chapters) reached with a next '
            'chapter still available',
          );
        } else {
          _addLog('requested chapter limit reached');
        }
        break;
      }

      if (nextRule != null && result.nextResult != null) {
        await rules.recordUse(nextRule.id, success: result.nextResult!.hasNext);
      }

      var next = result.nextUrl;
      final nextResult = result.nextResult;

      if (next == null &&
          nextResult != null &&
          nextResult.needsUserSelection &&
          !_stopRequested) {
        final outcome = await _askUser(
          SelectionRequest(
            kind: RuleKind.nextLink,
            sourceUrl: result.pageUrl.isEmpty ? url : result.pageUrl,
            prompt: 'Select the next chapter button',
            reason: nextResult.reason,
            candidates: nextResult.considered,
            isRuleFailure: nextRule != null,
            failedRuleId: nextRule?.id,
          ),
        );

        if (outcome.cancelled) {
          // The user gave up on picking the control: the run ends as
          // cancelled — what was already stored stays stored, but "complete"
          // would claim an ending the user never reached.
          _addLog('job ended: user cancelled the next-chapter selection');
          _setProgress(
            (p) => p.copyWith(
              state: CaptureState.cancelled,
              storedChapters: stored,
            ),
          );
          await _persistJob(CaptureState.cancelled, url, stored);
          if (_jobId != null) await db.deleteJob(_jobId!);
          return;
        }
        if (outcome.retryAutomatic) {
          final retry = await _peekNextFromPage(url);
          if (retry == null) {
            _addLog('automatic retry still found nothing — end of chain');
            break;
          }
          next = retry;
        } else if (outcome.hasRule) {
          if (nextRule != null && result.nextResult?.hasNext != true) {
            await rules.delete(nextRule.id);
            _addLog('replaced the broken next-link rule');
          }
          // Resolve through the freshly saved rule so the stored signals are
          // exercised immediately rather than trusted on faith.
          final match = await browser.applyLocator(
            outcome.rule!.locator.toJson(),
          );
          final href = match?.isMatch == true
              ? match!.href
              : (outcome.element?.href ?? '');
          final check = validateNextUrl(
            candidate: href,
            currentUrl: url,
            visited: _visited,
          );
          if (!check.isAccepted) {
            _addLog(
              'selected link failed validation: ${check.rejection?.name}',
            );
            break;
          }
          next = check.normalized;
        }
      }

      if (next == null) {
        _addLog('no valid next chapter — end of chain');
        break;
      }
      url = next;
    }

    final finalState = diskStop && stored == 0
        ? CaptureState.failed
        : stored == 0 && skipped == 0
        ? CaptureState.failed
        : (_progress.state == CaptureState.partial
              ? CaptureState.partial
              : CaptureState.complete);
    // The requested count means new capture attempts; skips and traversal are
    // reported alongside it so "3 requested, 3 captured, 2 skipped, 5 walked"
    // is one honest sentence rather than a puzzle. Disk stops and the
    // until-end safety limit each get their own distinct sentence — neither
    // may masquerade as an ordinary completion.
    final counts =
        'captured $stored'
        '${skipped > 0 ? ' · skipped $skipped existing' : ''}'
        ' · traversed $traversed';
    final message = diskStop
        ? 'Stopped: not enough disk space. $counts. '
              'Existing downloads are unaffected.'
        : hitSafetyLimit
        ? 'Stopped at the safety limit before a confirmed end of series. '
              '$counts.'
        : rangeMode == CaptureRangeMode.untilEnd
        ? 'Reached the end of the series. $counts.'
        : skipped > 0
        ? 'Requested $limit new · $counts'
        : 'Captured $stored chapter(s)';
    _setProgress(
      (p) => p.copyWith(
        state: finalState,
        storedChapters: stored,
        lastError: diskStop ? 'insufficientStorage' : null,
        message: message,
      ),
    );
    await _persistJob(CaptureState.complete, url, stored);
    if (_jobId != null) await db.deleteJob(_jobId!);
    _addLog(
      'job finished (${rangeMode.name}'
      '${hitSafetyLimit ? ', safety limit' : ''}'
      '${diskStop ? ', disk stop' : ''}): '
      '$stored new chapter(s) stored of $limit requested'
      '${skipped > 0 ? ' · $skipped skipped as already saved' : ''}'
      ' · $traversed page(s) traversed',
    );
  }

  /// Planning estimate for the next chapter: the median of this series' own
  /// stored chapters when it has any, the conservative default otherwise.
  Future<int> _estimateChapterBytes(LibraryItem? item) async {
    if (item == null) return config.unknownChapterEstimate;
    final sizes = (await db.chaptersForItem(
      item.id,
    )).map((c) => c.byteSize).where((b) => b > 0).toList()..sort();
    if (sizes.isEmpty) return config.unknownChapterEstimate;
    return sizes[sizes.length ~/ 2];
  }

  static String _mb(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';

  /// Preflight + policy + (when needed) the user prompt for the chapter at
  /// [url]. Returns null when the user chose to stop the job.
  Future<({DuplicateAction action, ChapterPreflight preflight})?>
  _decideDuplicate(String url, LibraryItem? item, int ordinal) async {
    final preflight = await CapturePreflight(
      db: db,
      fileStore: fileStore,
    ).inspect(url, libraryItemId: item?.id, ignoreJobId: _jobId);

    var action = resolveDuplicateAction(
      state: preflight.state,
      policy: duplicatePolicy,
      sessionComplete: sessionDuplicateDecision,
      sessionPartial: sessionPartialDecision,
    );

    if (action == DuplicateAction.promptUser && !_stopRequested) {
      final choice = await _askDuplicate(
        DuplicateRequest(preflight: preflight, ordinal: ordinal),
      );
      if (choice.action == DuplicateChoiceAction.stopCapture) {
        _setProgress((p) => p.copyWith(state: CaptureState.cancelled));
        await _persistJob(
          CaptureState.cancelled,
          url,
          _progress.storedChapters,
        );
        _addLog('job stopped by user at the duplicate prompt');
        return null;
      }
      action = _applyDuplicateChoice(choice, preflight.state);
      await _persistJob(_progress.state, url, _progress.storedChapters);
    } else if (action == DuplicateAction.skip &&
        preflight.state == ChapterLocalState.inActiveJob) {
      _addLog('skipped (owned by another job): $url');
    }

    return (action: action, preflight: preflight);
  }

  /// Walk past a chapter that stays as it is: prefer its stored (and
  /// re-validated) next URL — costing no page load — else open the page and
  /// read the next link off it. Returns null at the end of the chain.
  Future<String?> _continueAfterSkip(
    ChapterPreflight preflight,
    String url,
  ) async {
    final existing = preflight.chapter;
    final reason = switch (preflight.state) {
      ChapterLocalState.complete => 'already saved',
      ChapterLocalState.partial => 'partial, kept as-is',
      ChapterLocalState.inActiveJob => 'owned by another job',
      _ => preflight.state.name,
    };
    _addLog('skipped ($reason): ${existing?.title ?? url}');
    _setProgress(
      (p) => p.copyWith(
        skippedChapters: p.skippedChapters + 1,
        message: 'Skipped — $reason',
      ),
    );
    _visited.add(normalizeUrl(url));

    var next = existing?.nextSourceUrl;
    if (next != null) {
      final check = validateNextUrl(
        candidate: next,
        currentUrl: url,
        visited: _visited,
      );
      next = check.isAccepted ? check.normalized : null;
    }
    if (next == null && !_stopRequested) {
      // Only now is a page load needed: the stored chain ends here.
      _setProgress((p) => p.copyWith(state: CaptureState.navigating));
      browser.allowNextNavigation(url);
      await browser.loadAndWait(url);
      next = await _peekNextFromPage(url);
    }
    if (next == null) _addLog('no next chapter beyond the skipped one');
    return next;
  }

  /// After a skip or failure we still want the chain to continue, so read the
  /// next link straight off whatever page is on screen.
  Future<String?> _peekNextFromPage(String currentUrl) async {
    try {
      final probe = await browser.probe(withLinks: true);
      final result = resolveNextPage(
        probe,
        currentUrl: currentUrl,
        visitedNormalized: _visited,
      );
      if (result.hasNext) _addLog('continuing at ${result.chosen!.href}');
      return result.chosen?.href;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistJob(
    CaptureState state,
    String currentUrl,
    int completed, {
    String? error,
  }) async {
    final id = _jobId;
    if (id == null) return;
    final now = DateTime.now();
    await db.upsertJob(
      CaptureJob(
        id: id,
        libraryItemId: null,
        startUrl: _progress.currentUrl,
        currentUrl: currentUrl,
        requestedChapters: _progress.requestedChapters,
        completedChapters: completed,
        state: state.name,
        lastError: error,
        visitedUrls: _visited.join('\n'),
        duplicatePolicy: duplicatePolicy.name,
        // Session answers ride on the job row so an interrupted-session
        // resume keeps them — and die with it, never becoming a preference.
        sessionDuplicateDecision: sessionDuplicateDecision.name,
        sessionPartialDecision: sessionPartialDecision.name,
        rangeMode: rangeMode.name,
        pauseReason: pauseReason,
        // Carried so an interrupted direct capture is resumed as one, rather
        // than being folded into the pending queue (D58).
        origin: origin.name,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Resume an interrupted job: continue from its recorded current URL with
  /// the visited set restored, so completed chapters are not re-captured —
  /// under the same duplicate policy and session decisions it was running
  /// with.
  Future<void> resumeJob(CaptureJob job) async {
    _visited
      ..clear()
      ..addAll(job.visitedUrls.split('\n').where((s) => s.isNotEmpty));
    _addLog(
      'resuming job ${job.id.substring(0, 8)} '
      'at ${job.currentUrl ?? job.startUrl}',
    );
    final mode = captureRangeModeFromName(job.rangeMode);
    final remaining = job.requestedChapters - job.completedChapters;
    await db.deleteJob(job.id);
    await start(
      // An until-end resume continues until the end — the safety limit
      // starts fresh; the visited set is what prevents re-capturing.
      chapterLimit: remaining <= 0 ? 1 : remaining,
      startUrl: job.currentUrl ?? job.startUrl,
      policy: duplicatePolicyFromName(job.duplicatePolicy),
      sessionDuplicate: sessionDuplicateDecisionFromName(
        job.sessionDuplicateDecision,
      ),
      sessionPartial: sessionPartialDecisionFromName(
        job.sessionPartialDecision,
      ),
      range: mode,
      // A resumed run keeps the launch it was interrupted mid-way through: a
      // direct capture resumes directly and never joins the pending queue.
      origin: captureOriginFromName(job.origin),
    );
  }

  Future<void> discardJob(CaptureJob job) async {
    await db.deleteJob(job.id);
    _addLog('discarded interrupted job ${job.id.substring(0, 8)}');
  }
}

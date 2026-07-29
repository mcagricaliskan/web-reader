import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../browser/browser_controller.dart';
import '../browser/browser_navigator.dart';
import '../browser/browser_presentation.dart';
import '../browser/browser_url.dart';
import '../capture/capture_job.dart';
import '../capture/capture_preflight.dart';
import '../core/config.dart';
import '../core/connectivity.dart';
import '../library/update_checker.dart';
import '../providers.dart';
import '../queue/task_queue.dart';
import '../ui/palette.dart';
import 'browser_capture_state.dart';
import 'browser_home.dart';
import 'browser_page_actions.dart';
import 'browser_states.dart';
import 'browser_toolbar.dart';
import 'browser_url_editor.dart';
import 'capture_panel.dart';
import 'capture_queue_ui.dart';
import 'capture_preflight_sheet.dart';
import 'capture_range_sheet.dart';
import 'duplicate_decision_panel.dart';
import 'saved_site_sheets.dart';
import 'selection_overlay.dart';

/// The browser *and* the capture surface. One WebView, kept alive and mounted
/// for the whole session: capture runs in exactly the environment the user
/// browsed in, and there is something to watch while it works.
///
/// Browser Home and the URL editor are **layers over** that WebView, never
/// replacements for it (D52). Nothing in this file constructs a second
/// `InAppWebView`, and nothing removes the one it has from the tree — which
/// is what makes "open Home, come back, the page is still there, still
/// scrolled, still signed in" true rather than merely likely.
class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  bool _panelOpen = false;
  bool _findOpen = false;
  BrowserController? _browser;
  BrowserPresentation? _presentation;
  BrowserNavigator? _navigator;
  late final String _initialUrl;

  /// True while a post-frame drain is already scheduled, so the three things
  /// that can trigger one (a new request, a WebView attach, a rebuild) do not
  /// schedule three.
  bool _drainScheduled = false;

  /// The page identity everything transient on this screen is scoped to (D59).
  ///
  /// Not a convenience copy of the URL: it is what distinguishes "the page
  /// changed" from "the same page said something again". When it moves, every
  /// transient thing the Browser was showing about the previous page goes with
  /// it — result banners, the panel, the offline lookup, the log drawer.
  int _pageSession = -1;
  String _pageKey = '';

  /// Whether the user is what put this page on screen. An automation hop owns
  /// its own page, so the run stays on screen across it.
  bool _pageEnteredManually = true;

  /// What this page already holds locally, looked up once per page session.
  /// Null while unknown — which is also the honest answer for a page nobody
  /// has ever captured.
  ChapterLocalState? _pageChapterState;

  @override
  void initState() {
    super.initState();
    _initialUrl = widget.initialUrl ?? kBrowserStartUrl;
    // A cold start has no page, so the toolbar's address field and the
    // blank WebView would both be empty. Browser Home is the designed
    // first-run surface, and it is where the last visited page lives (D57).
    if (!_hasRealPage(_initialUrl)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final presentation = ref.read(browserPresentationProvider);
        // ...unless something is already on its way here. Opening Home over
        // a page the user explicitly asked for is the bug this whole flow
        // exists to fix.
        if (ref.read(browserNavigatorProvider).hasPending) return;
        if (presentation.surface == BrowserSurface.website &&
            !_hasRealPage(ref.read(browserProvider).currentUrl)) {
          presentation.openHome();
        }
      });
    }
  }

  static bool _hasRealPage(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final browser = ref.read(browserProvider);
    if (!identical(browser, _browser)) {
      _browser?.removeListener(_onBrowserChanged);
      _browser = browser..addListener(_onBrowserChanged);
    }
    final presentation = ref.read(browserPresentationProvider);
    if (!identical(presentation, _presentation)) {
      _presentation?.removeListener(_onPresentationChanged);
      _presentation = presentation..addListener(_onPresentationChanged);
    }
    final navigator = ref.read(browserNavigatorProvider);
    if (!identical(navigator, _navigator)) {
      _navigator?.removeListener(_scheduleDrain);
      _navigator = navigator..addListener(_scheduleDrain);
    }
    // A request may already be waiting — this screen can be built *because*
    // of one.
    _scheduleDrain();
  }

  /// Keep the preserved-page snapshot current so Browser Home can offer a way
  /// back to whatever is actually loaded — including the chapter hops an
  /// autonomous job makes.
  void _onBrowserChanged() {
    final browser = _browser;
    if (browser == null) return;
    // An attach is one of the two things a pending request waits for.
    _scheduleDrain();
    _syncPageSession(browser);
    final url = browser.currentUrl;
    if (url.isEmpty) return;
    _presentation?.rememberPage(PreservedPage(url: url, title: browser.title));
  }

  /// The Browser moved to another page: re-scope everything transient to it.
  ///
  /// This is the whole of "reset on navigation" (D59). It does not reach into
  /// the capture job — a running job is not this screen's to reset, and an
  /// automation hop between chapters lands here exactly like a manual one:
  /// the *presentation* follows the page, the *run* is untouched.
  void _syncPageSession(BrowserController browser) {
    if (browser.pageSession == _pageSession) return;
    _pageSession = browser.pageSession;
    _pageKey = browser.pageSessionKey;
    _pageEnteredManually = browser.pageSessionIsManual;
    _pageChapterState = null;
    _panelOpen = false;
    // A result the user never dismissed belongs to the page they have now
    // left; it is in Activity, which is where history lives.
    final job = _browser == null ? null : ref.read(captureJobProvider);
    final stale = job?.lastRun;
    if (stale != null && stale.pageSession != _pageSession) job!.clearLastRun();
    unawaited(_loadPageChapterState(_pageSession, _pageKey));
    if (mounted) setState(() {});
  }

  /// Read this page's own captured/offline metadata — separately from any job,
  /// and discarded if the page moves on while the read is in flight.
  Future<void> _loadPageChapterState(int session, String pageKey) async {
    if (pageKey.isEmpty) return;
    final preflight = CapturePreflight(
      db: ref.read(databaseProvider),
      fileStore: ref.read(fileStoreProvider),
    );
    final result = await preflight.inspect(pageKey);
    if (!mounted || session != _pageSession) return;
    setState(() => _pageChapterState = result.state);
  }

  void _onPresentationChanged() {
    if (mounted) setState(() {});
  }

  /// Drain after the current frame.
  ///
  /// Deferred, not delayed: draining calls `showWebsite()`, which notifies
  /// listeners and calls `setState` — illegal during a build, and
  /// `didChangeDependencies` is part of one. The wait is for the frame to
  /// end, never for a duration.
  void _scheduleDrain() {
    if (_drainScheduled || !mounted) return;
    final navigator = _navigator;
    if (navigator == null || !navigator.hasPending) return;
    _drainScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainScheduled = false;
      _drainPendingOpen();
    });
  }

  /// Hand a waiting request to the WebView, exactly once.
  ///
  /// Held back until the WebView is attached: a load into an unattached
  /// controller is silently dropped, which is precisely how the old flow lost
  /// the URL. Nothing polls — [_onBrowserChanged] fires on attach and brings
  /// us straight back here.
  void _drainPendingOpen() {
    if (!mounted) return;
    final navigator = _navigator;
    final browser = _browser;
    if (navigator == null || browser == null) return;

    PendingOpenDrainer(
      navigator: navigator,
      presentation: ref.read(browserPresentationProvider),
      isAttached: () => browser.isAttached,
      reveal: ref.read(browserPresentationProvider).showWebsite,
      load: (url) => unawaited(browser.load(url)),
    ).drain();
  }

  @override
  void dispose() {
    _browser?.removeListener(_onBrowserChanged);
    _presentation?.removeListener(_onPresentationChanged);
    _navigator?.removeListener(_scheduleDrain);
    super.dispose();
  }

  // --- navigation ----------------------------------------------------------

  BrowserPresentation get _p => ref.read(browserPresentationProvider);

  /// Opening a local surface hides the rendered page, so it goes through the
  /// same guard as leaving the Browser entirely (§15). Nothing is paused
  /// unless the user chooses to.
  Future<void> _openHome() async {
    if (!await LeaveBrowserGuard.confirmLeave(context)) return;
    if (!mounted) return;
    final browser = ref.read(browserProvider);
    _p.openHome(
      preserving: PreservedPage(url: browser.currentUrl, title: browser.title),
    );
  }

  void _openAddressEditor({bool fromHome = false}) {
    final browser = ref.read(browserProvider);
    final url = browser.currentUrl;
    _p.openAddressEditor(
      // From Home the field starts blank, as drawn; from a page it starts
      // with the whole URL, selected, so typing replaces it (§6).
      draft: fromHome ? '' : url,
      selectAll: !fromHome && url.isNotEmpty,
    );
  }

  /// Open [url] in the existing WebView. Never creates one.
  Future<void> _openUrl(String url, [String title = '']) async {
    final browser = ref.read(browserProvider);
    _p.showWebsite();
    await browser.load(url);
  }

  Future<void> _submitAddress(String text) async {
    final browser = ref.read(browserProvider);
    _p.showWebsite();
    final intent = await browser.open(text);
    if (!mounted) return;
    if (isExternalAppScheme(intent.url)) {
      // Classified, not loaded — the banner offers the handoff.
      return;
    }
  }

  Future<void> _goBack() async {
    final browser = ref.read(browserProvider);
    // Back closes a local surface first: the page it is covering is what the
    // user means by "back" while Home is up.
    if (_p.isEditingAddress) {
      _p.closeAddressEditor();
      return;
    }
    if (_p.isHome) {
      _p.showWebsite();
      return;
    }
    if (browser.canGoBack) {
      await browser.goBack();
      return;
    }
    // Nothing left in the page's history and no overlay: this is a request
    // to leave the Browser, and the capture guard owns that decision.
    if (!await LeaveBrowserGuard.confirmLeave(context)) return;
    if (!mounted) return;
    ref.read(shellTabRequestProvider).value = 0;
  }

  Future<void> _openHistory() async {
    if (!await LeaveBrowserGuard.confirmLeave(context)) return;
    if (!mounted) return;
    context.push('/history');
  }

  Future<void> _addSavedSite() async {
    await showAddSavedSiteSheet(context);
  }

  Future<void> _saveCurrentPage({String? url, String? title}) async {
    final browser = ref.read(browserProvider);
    final target = url ?? browser.currentUrl;
    if (target.trim().isEmpty) return;
    await showSaveSiteSheet(
      context,
      url: target,
      title: (title ?? browser.title).trim().isEmpty
          ? displayHost(target)
          : (title ?? browser.title),
    );
  }

  Future<void> _openPageActions() async {
    final browser = ref.read(browserProvider);
    final url = browser.currentUrl;
    if (url.trim().isEmpty) return;
    final action = await showPageActionsSheet(
      context: context,
      ref: ref,
      url: url,
      title: browser.title,
    );
    if (!mounted) return;
    switch (action) {
      case PageAction.capture:
        await _showCaptureSheet(context);
      case PageAction.addToSavedSites:
        await _saveCurrentPage();
      case PageAction.findInPage:
        setState(() => _findOpen = true);
      case PageAction.none:
        break;
    }
  }

  // --- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final browser = ref.watch(browserProvider);
    final presentation = ref.watch(browserPresentationProvider);
    final job = ref.watch(captureJobProvider);
    final checker = ref.watch(updateCheckerProvider);

    // Settings asked for Browser Home from another route; honour it once the
    // Browser is actually on screen.
    if (presentation.consumeHomeRequest()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onPresentationChanged();
      });
    }
    // A page can arrive before any listener fires (first build, a restored
    // session): keep the scope in step without waiting for a notification.
    if (browser.pageSession != _pageSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPageSession(browser);
      });
    }

    // Read once, here, in the build that owns this ref — the pieces below
    // rebuild from Listenables, and a `watch` from inside one of those
    // callbacks is a dependency registered outside its widget's build.
    final tasks = ref.watch(queueTasksProvider).value ?? const [];
    final pageIsQueued = pageHasQueuedCapture(tasks, _pageKey);
    final waitingCaptures = QueueSummary.of(tasks).queuedCaptures;

    return Scaffold(
      backgroundColor: palette.surfaceMuted,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BrowserToolbar(
              browser: browser,
              homeActive: presentation.isHome,
              onBack: _goBack,
              onForward: browser.canGoForward ? browser.goForward : null,
              onAddress: () => _openAddressEditor(),
              onReloadOrStop: () =>
                  browser.isLoading ? browser.stopLoading() : browser.reload(),
              onHome: _openHome,
            ),
            if (_findOpen)
              FindInPageBar(
                browser: browser,
                onClose: () => setState(() => _findOpen = false),
              ),
            _HostChangeBanner(browser: browser),
            _PageStateBanner(
              browser: browser,
              onRetry: browser.reload,
              onEditAddress: () => _openAddressEditor(),
              onGoHome: _openHome,
            ),
            Expanded(
              child: Stack(
                children: [
                  // Always in the tree, always laid out at full size. The
                  // layers below cover it; none of them unmount it.
                  _WebViewHost(browser: browser, initialUrl: _initialUrl),
                  _BlockingPageState(
                    browser: browser,
                    onRetry: browser.reload,
                    onEditAddress: () => _openAddressEditor(),
                    onGoHome: _openHome,
                    onOpenLibrary: () =>
                        ref.read(shellTabRequestProvider).value = 0,
                  ),
                  // While a job runs, block stray taps from reaching the page.
                  AnimatedBuilder(
                    animation: job,
                    builder: (context, _) =>
                        job.isRunning && job.pendingSelection == null
                        ? Positioned.fill(
                            child: AbsorbPointer(
                              child: ColoredBox(color: palette.veil),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  _CaptureActions(
                    job: job,
                    checker: checker,
                    pageKey: _pageKey,
                    pageSession: _pageSession,
                    pageChapterState: _pageChapterState,
                    pageIsQueued: pageIsQueued,
                    pageEnteredManually: _pageEnteredManually,
                    waitingCaptures: waitingCaptures,
                    onCapture: () => _showCaptureSheet(context),
                    onPageActions: _openPageActions,
                    onViewActivity: () =>
                        LeaveBrowserGuard.push(context, '/activity'),
                  ),
                  if (presentation.isHome)
                    Positioned.fill(
                      child: BrowserHome(
                        preserved: presentation.preserved,
                        onClose: _p.showWebsite,
                        onOpenAddressEditor: () =>
                            _openAddressEditor(fromHome: true),
                        onOpenUrl: _openUrl,
                        onOpenHistory: _openHistory,
                        onAddSite: _addSavedSite,
                        onEditSite: (site) => showSaveSiteSheet(
                          context,
                          url: site.url,
                          title: site.title,
                          editingId: site.id,
                          offerSiteRoot: false,
                        ),
                      ),
                    ),
                  if (presentation.isEditingAddress)
                    Positioned.fill(
                      child: BrowserUrlEditor(
                        initialText: presentation.addressDraft,
                        selectAll: presentation.selectAllOnOpen,
                        currentPageUrl: browser.currentUrl,
                        onSubmit: _submitAddress,
                        onCancel: () => _p.closeAddressEditor(
                          // Cancelling out of an editor opened from Home
                          // returns to Home, not to the page behind it.
                          toHome:
                              presentation.addressDraft.isEmpty &&
                              presentation.preserved != null,
                        ),
                        onSaveSite: (url, title) =>
                            _saveCurrentPage(url: url, title: title),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([job, checker]),
              builder: (context, _) {
                final request = job.pendingSelection;
                if (request != null) {
                  return RuleSelectionOverlay(job: job, request: request);
                }
                // An update check can also need the user to point at the
                // next-chapter control; the same overlay serves it.
                final checkRequest = checker.pendingSelection;
                if (checkRequest != null) {
                  return RuleSelectionOverlay(
                    job: checker,
                    request: checkRequest,
                  );
                }
                final duplicate = job.pendingDuplicate;
                if (duplicate != null) {
                  return DuplicateDecisionPanel(job: job, request: duplicate);
                }
                // Page-scoped from here down (D59): the run panel belongs to
                // the page being captured, and a finished run's banner belongs
                // to the page it finished on. Neither survives navigating away.
                final ui = _captureUi(job, checker, pageIsQueued);
                if (ui.showsRunPanel) {
                  return CapturePanel(
                    job: job,
                    expanded: _panelOpen || job.isRunning,
                    onToggle: () => setState(() => _panelOpen = !_panelOpen),
                  );
                }
                final result = ui.result;
                if (result != null) {
                  return CaptureResultBanner(
                    result: result,
                    onDismiss: job.clearLastRun,
                    onViewActivity: () =>
                        LeaveBrowserGuard.push(context, '/activity'),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// The capture control's state for the page on screen.
  BrowserCaptureState _captureUi(
    CaptureJobController job,
    UpdateChecker checker,
    bool pageIsQueued,
  ) {
    return resolveBrowserCaptureState(
      pageKey: _pageKey,
      pageSession: _pageSession,
      hasActiveRun: job.hasActiveRun,
      activePageKey: job.activePageKey,
      activeState: job.progress.state,
      needsRenderedBrowser: job.needsRenderedBrowser,
      awaitingUser:
          job.pendingSelection != null || job.pendingDuplicate != null,
      pausedForBrowser: job.pauseReason == kPauseBrowserHidden,
      checkerRunning: checker.isRunning,
      pageEnteredManually: _pageEnteredManually,
      lastRun: job.lastRun,
      pageChapterState: _pageChapterState,
      pageIsQueued: pageIsQueued,
    );
  }

  Future<void> _showCaptureSheet(BuildContext context) async {
    final queue = ref.read(taskQueueProvider);
    final job = ref.read(captureJobProvider);
    // Asked before the sheet opens, so it can offer what is actually possible
    // rather than failing after the choice (§3). Queueing is always on offer;
    // only the direct start can conflict.
    final owner = queue.browserOwner;
    final choice = await showCaptureRangeSheet(
      context: context,
      config: job.config,
      deviceStorage: job.deviceStorage,
      currentTitle: ref.read(browserProvider).title,
      busyLabel: owner?.label,
    );
    if (choice == null || !context.mounted) return;
    if (choice.action == CaptureSheetAction.viewActiveTask) {
      await LeaveBrowserGuard.push(context, '/activity');
      return;
    }
    await _startCapture(context, choice);
  }

  /// Carry out [action] for a resolved request. The single place the two
  /// launches diverge — everything before it (range, preflight, policy) is
  /// shared, which is what makes the intent survive the preflight (D58).
  Future<void> _launch(
    BuildContext context,
    CaptureSheetAction action, {
    required String startUrl,
    required int chapterLimit,
    required DuplicatePolicy policy,
    required CaptureRangeMode range,
  }) async {
    final queue = ref.read(taskQueueProvider);
    if (action == CaptureSheetAction.addToQueue) {
      final result = await queue.enqueueCapture(
        startUrl: startUrl,
        chapterLimit: chapterLimit,
        policy: policy,
        range: range,
      );
      if (!context.mounted) return;
      // Queued, not started (D46). The user stays exactly where they are.
      showQueuedConfirmation(context, result);
      return;
    }

    final started = await queue.startDirectCapture(
      startUrl: startUrl,
      chapterLimit: chapterLimit,
      policy: policy,
      range: range,
    );
    if (!context.mounted) return;
    switch (started) {
      case DirectStartResult.started:
        // Nothing to say: the panel is now the answer, on this page.
        break;
      case DirectStartResult.browserBusy:
        showDirectStartRefusal(
          context,
          'Another capture is already using the Browser. This one can wait '
          'in the queue instead.',
        );
      case DirectStartResult.browserUnavailable:
        showDirectStartRefusal(
          context,
          'The Browser is not ready yet. Nothing was started, and nothing '
          'was queued.',
        );
      case DirectStartResult.noPage:
        showDirectStartRefusal(context, 'There is no page to capture.');
    }
  }

  /// Launch whatever the preflight answer resolved to, keeping the launch the
  /// user chose before it interrupted (D58).
  Future<void> _launchPlanned(
    BuildContext context,
    String url,
    PreflightDecision decision,
    CaptureSheetAction action,
    int limit,
    CaptureRangeMode range,
  ) async {
    final plan = planAfterPreflight(
      action: action,
      choice: decision.choice,
      requestedLimit: limit,
      requestedRange: range,
      policy: decision.policy,
    );
    if (plan == null) return;
    await _launch(
      context,
      plan.action,
      startUrl: url,
      chapterLimit: plan.chapterLimit,
      policy: plan.policy,
      range: plan.range,
    );
  }

  /// Preflight before anything downloads: if this chapter already exists, say
  /// so and ask, rather than starting a job that silently does nothing.
  ///
  /// The decision-making stays here — the sheet resolves duplicates and
  /// conflicts *before* anything runs — and the launch the user chose is
  /// carried through it unchanged (D58). "Start Capture" that turns into
  /// "Re-download this chapter" still starts here and now; "Add to Queue" that
  /// turns into the same thing still waits. The question is never asked twice.
  Future<void> _startCapture(
    BuildContext context,
    CaptureRangeChoice choice,
  ) async {
    final job = ref.read(captureJobProvider);
    final queue = ref.read(taskQueueProvider);
    final url = ref.read(browserProvider).currentUrl;
    if (url.isEmpty) return;
    final action = choice.action;
    final limit = switch (choice.mode) {
      CaptureRangeMode.currentChapter => 1,
      CaptureRangeMode.fixedCount => choice.count,
      // The job derives its own bound from the safety limit.
      CaptureRangeMode.untilEnd => job.config.untilEndSafetyLimit,
    };

    final preflight = CapturePreflight(
      db: ref.read(databaseProvider),
      fileStore: ref.read(fileStoreProvider),
    );
    final current = await preflight.inspect(url);

    if (!current.needsUserDecision) {
      if (!context.mounted) return;
      // `ask` here means: if the run later walks onto a chapter that is
      // already saved, hold and ask — never silently skip or re-download.
      await _launch(
        context,
        action,
        startUrl: url,
        chapterLimit: limit,
        policy: DuplicatePolicy.ask,
        range: choice.mode,
      );
      return;
    }

    // Look ahead over the stored next-URL chain so the sheet can summarise the
    // range instead of only the chapter in front of us. Bounded for
    // until-end: the lookahead is a courtesy summary, not a crawl.
    final lookahead = choice.mode == CaptureRangeMode.untilEnd ? 10 : limit;
    final range = lookahead > 1
        ? await preflight.inspectRange(url, lookahead)
        : null;
    if (!context.mounted) return;

    final decision = await showCapturePreflightSheet(
      context: context,
      preflight: current,
      requestedCount: limit,
      range: range,
    );
    if (decision == null || decision.choice == PreflightChoice.cancel) return;

    switch (decision.choice) {
      case PreflightChoice.openExisting:
        final id = current.chapter?.id;
        if (id != null && context.mounted) context.push('/reader/\$id');

      case PreflightChoice.removeRecord:
        final id = current.chapter?.id;
        if (id != null) {
          final path = current.chapter?.contentPath;
          if (path != null) {
            await ref.read(fileStoreProvider).deleteChapterContent(path);
          }
          await ref.read(databaseProvider).deleteChapter(id);
        }

      case PreflightChoice.resumeJob:
        // Resuming is always immediate — it is one job the user pointed at,
        // and it keeps the launch it was interrupted under (D58).
        final existing = current.blockingJob;
        if (existing != null) await queue.resumeInterruptedCapture(existing);

      case PreflightChoice.discardJobAndRestart:
        final existing = current.blockingJob;
        if (existing != null) await job.discardJob(existing);
        if (!context.mounted) return;
        await _launchPlanned(
          context,
          url,
          decision,
          action,
          limit,
          choice.mode,
        );

      case PreflightChoice.captureFollowing:
      case PreflightChoice.redownload:
      case PreflightChoice.retryMissing:
      case PreflightChoice.restartCapture:
      case PreflightChoice.repair:
      case PreflightChoice.captureNow:
        if (!context.mounted) return;
        await _launchPlanned(
          context,
          url,
          decision,
          action,
          limit,
          choice.mode,
        );

      case PreflightChoice.cancel:
        break;
    }
  }
}

/// The capture control, the page-actions button, and the queued chip.
///
/// The control says what is true **of this page** (D59): idle, already
/// available offline, queued, or the phase of the run that is working on it.
/// A run that finished, or one that is working somewhere else, never presents
/// itself as this page's state — and never disables its Capture button.
class _CaptureActions extends StatelessWidget {
  const _CaptureActions({
    required this.job,
    required this.checker,
    required this.pageKey,
    required this.pageSession,
    required this.pageChapterState,
    required this.pageIsQueued,
    required this.pageEnteredManually,
    required this.waitingCaptures,
    required this.onCapture,
    required this.onPageActions,
    required this.onViewActivity,
  });

  final CaptureJobController job;
  final UpdateChecker checker;
  final String pageKey;
  final int pageSession;
  final ChapterLocalState? pageChapterState;
  final bool pageIsQueued;
  final bool pageEnteredManually;
  final int waitingCaptures;
  final VoidCallback onCapture;
  final VoidCallback onPageActions;
  final VoidCallback onViewActivity;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([job, checker]),
      builder: (context, _) {
        final ui = resolveBrowserCaptureState(
          pageKey: pageKey,
          pageSession: pageSession,
          hasActiveRun: job.hasActiveRun,
          activePageKey: job.activePageKey,
          activeState: job.progress.state,
          needsRenderedBrowser: job.needsRenderedBrowser,
          awaitingUser:
              job.pendingSelection != null || job.pendingDuplicate != null,
          pausedForBrowser: job.pauseReason == kPauseBrowserHidden,
          checkerRunning: checker.isRunning,
          pageEnteredManually: pageEnteredManually,
          lastRun: job.lastRun,
          pageChapterState: pageChapterState,
          pageIsQueued: pageIsQueued,
        );

        // While the user is being asked something, the overlay owns the
        // screen; a floating button over it is noise.
        if (ui.status == BrowserCaptureStatus.needsInput) {
          return const SizedBox.shrink();
        }

        final waiting = waitingCaptures;
        final running = ui.showsRunPanel;

        return Positioned(
          left: 14,
          right: 14,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (waiting > 0 && !running) ...[
                QueuedCapturesChip(
                  count: waiting,
                  onViewActivity: onViewActivity,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!running) ...[
                    _RoundAction(
                      icon: Icons.more_horiz,
                      tooltip: 'Page actions',
                      onPressed: onPageActions,
                    ),
                    const SizedBox(width: 8),
                  ],
                  FloatingActionButton.extended(
                    key: const ValueKey('browserCaptureAction'),
                    heroTag: 'browserCapture',
                    onPressed: ui.opensCaptureSheet
                        ? onCapture
                        : onViewActivity,
                    tooltip: ui.detail ?? 'Capture chapters',
                    backgroundColor: running
                        ? palette.surface
                        : palette.primary,
                    foregroundColor: running
                        ? palette.inkStrong
                        : palette.onPrimary,
                    icon: Icon(switch (ui.status) {
                      BrowserCaptureStatus.queued => Icons.schedule,
                      BrowserCaptureStatus.capturing => Icons.swipe_vertical,
                      BrowserCaptureStatus.downloading => Icons.downloading,
                      BrowserCaptureStatus.waitingForBrowser => Icons.public,
                      BrowserCaptureStatus.availableOffline =>
                        Icons.download_for_offline,
                      _ => Icons.download,
                    }, size: 20),
                    label: Text(ui.label),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 46,
        child: Material(
          color: palette.surface,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.border),
          ),
          child: InkWell(
            key: const ValueKey('browserPageActions'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Icon(icon, size: 21, color: palette.inkStrong),
          ),
        ),
      ),
    );
  }
}

/// A banner-style page state, shown above the page it is describing.
class _PageStateBanner extends StatelessWidget {
  const _PageStateBanner({
    required this.browser,
    required this.onRetry,
    required this.onEditAddress,
    required this.onGoHome,
  });

  final BrowserController browser;
  final VoidCallback onRetry;
  final VoidCallback onEditAddress;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: browser,
    builder: (context, _) {
      final fault = browser.fault;
      if (fault == null || PageStateView.isBlocking(fault.state)) {
        return const SizedBox.shrink();
      }
      return PageStateView(
        fault: fault,
        actions: switch (fault.state) {
          BrowserPageState.certificate => [
            PageStateAction('Go Home', onGoHome, primary: true),
            PageStateAction('Dismiss', browser.clearFault),
          ],
          BrowserPageState.externalApp => [
            PageStateAction('Stay here', browser.clearFault),
          ],
          _ => [
            PageStateAction('Retry', onRetry, primary: true),
            PageStateAction('Edit address', onEditAddress),
          ],
        },
      );
    },
  );
}

/// A page state that replaces the page, because there is nothing behind it.
class _BlockingPageState extends ConsumerWidget {
  const _BlockingPageState({
    required this.browser,
    required this.onRetry,
    required this.onEditAddress,
    required this.onGoHome,
    required this.onOpenLibrary,
  });

  final BrowserController browser;
  final VoidCallback onRetry;
  final VoidCallback onEditAddress;
  final VoidCallback onGoHome;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AnimatedBuilder(
    animation: browser,
    builder: (context, _) {
      final fault = browser.fault;
      if (fault == null || !PageStateView.isBlocking(fault.state)) {
        return const SizedBox.shrink();
      }
      return Positioned.fill(
        child: PageStateView(
          fault: fault,
          blocking: true,
          actions: switch (fault.state) {
            BrowserPageState.offline => [
              PageStateAction('Retry', onRetry, primary: true),
              PageStateAction('Open library', onOpenLibrary),
            ],
            BrowserPageState.invalidAddress => [
              PageStateAction('Edit address', onEditAddress, primary: true),
              PageStateAction('Go Home', onGoHome),
            ],
            _ => [
              PageStateAction('Retry', onRetry, primary: true),
              PageStateAction('Edit address', onEditAddress),
              PageStateAction('Go Home', onGoHome),
            ],
          },
        ),
      );
    },
  );
}

/// The only place an `InAppWebView` widget is constructed.
class _WebViewHost extends StatefulWidget {
  const _WebViewHost({required this.browser, required this.initialUrl});

  final BrowserController browser;
  final String initialUrl;

  @override
  State<_WebViewHost> createState() => _WebViewHostState();
}

class _WebViewHostState extends State<_WebViewHost>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
      initialSettings: BrowserController.settings,
      findInteractionController: widget.browser.findController,
      initialUserScripts: UnmodifiableListView([
        BrowserController.bridgeUserScript,
      ]),
      onWebViewCreated: (controller) {
        widget.browser.attach(controller);
        controller.addJavaScriptHandler(
          handlerName: 'webread.selection',
          callback: (args) {
            if (args.isNotEmpty && args.first is Map) {
              widget.browser.onSelection(
                Map<String, dynamic>.from(args.first as Map),
              );
            }
            return null;
          },
        );
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final target = action.request.url?.toString();
        if (widget.browser.shouldBlockNavigation(
          target,
          isMainFrame: action.isForMainFrame,
        )) {
          return NavigationActionPolicy.CANCEL;
        }

        // A scheme this Browser cannot render is a handoff, not a page. Named
        // rather than allowed to fail as an opaque platform error (§14).
        if (target != null &&
            (action.isForMainFrame) &&
            isExternalAppScheme(target)) {
          widget.browser.onExternalAppLink(target);
          return NavigationActionPolicy.CANCEL;
        }

        // A page hopping to another host on its own gets asked about. Silence
        // for 5s is a refusal, and the current site keeps running.
        final userInitiated =
            (action.hasGesture ?? false) && !(action.isRedirect ?? false);
        if (widget.browser.needsHostChangeConsent(
          fromUrl: widget.browser.currentUrl,
          toUrl: target,
          isMainFrame: action.isForMainFrame,
          userInitiated: userInitiated,
        )) {
          final allowed = await widget.browser.requestHostChange(
            fromUrl: widget.browser.currentUrl,
            toUrl: target!,
          );
          return allowed
              ? NavigationActionPolicy.ALLOW
              : NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      // No popups during capture — an unrelated top-level window is exactly
      // the kind of navigation a locked job must not follow.
      onCreateWindow: (controller, request) async => false,
      onLoadStart: (_, url) => widget.browser.onLoadStart(url?.toString()),
      onLoadStop: (_, url) => widget.browser.onLoadStop(url?.toString()),
      onProgressChanged: (_, p) => widget.browser.onProgress(p),
      onUpdateVisitedHistory: (_, url, _) =>
          widget.browser.onUrlChanged(url?.toString()),
      onReceivedError: (_, request, error) async {
        if (request.isForMainFrame ?? true) {
          // Whether the device has a connection at all changes "this site is
          // down" into "you are offline", which is a different instruction.
          final online = await hasNetwork();
          widget.browser.onPageFault(
            description: error.description,
            type: error.type.toString(),
            online: online,
          );
        }
      },
      onReceivedHttpError: (_, request, response) {
        if ((request.isForMainFrame ?? true) &&
            (response.statusCode ?? 0) >= 400) {
          widget.browser.onPageFault(statusCode: response.statusCode);
        }
      },
      onConsoleMessage: (_, msg) {
        if (msg.messageLevel == ConsoleMessageLevel.ERROR) {
          debugPrint('[page] ${msg.message}');
        }
      },
    );
  }
}

/// Asks before a page takes the browser to a different host.
///
/// Counts down and then refuses. A redirect the user did not ask for should
/// not win by default just because nobody was looking — the current site keeps
/// running instead.
class _HostChangeBanner extends StatefulWidget {
  const _HostChangeBanner({required this.browser});

  final BrowserController browser;

  @override
  State<_HostChangeBanner> createState() => _HostChangeBannerState();
}

class _HostChangeBannerState extends State<_HostChangeBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.browser.addListener(_onBrowserChanged);
  }

  void _onBrowserChanged() {
    final pending = widget.browser.pendingHostChange != null;
    if (pending && _ticker == null) {
      _ticker = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => setState(() {}),
      );
    } else if (!pending) {
      _ticker?.cancel();
      _ticker = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.browser.removeListener(_onBrowserChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.browser.pendingHostChange;
    if (request == null) return const SizedBox.shrink();

    final seconds = (request.remaining.inMilliseconds / 1000).ceil();
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Icon(
              Icons.open_in_new,
              size: 18,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'This page wants to open ${request.toHost}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  Text(
                    'Staying on ${request.fromHost} in ${seconds}s',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => widget.browser.resolveHostChange(false),
              child: const Text('Stay'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () => widget.browser.resolveHostChange(true),
              child: Text('Allow ($seconds)'),
            ),
          ],
        ),
      ),
    );
  }
}

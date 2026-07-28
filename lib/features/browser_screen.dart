import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../browser/browser_controller.dart';
import '../browser/browser_presentation.dart';
import '../browser/browser_url.dart';
import '../capture/capture_preflight.dart';
import '../core/config.dart';
import '../core/connectivity.dart';
import '../providers.dart';
import '../queue/task_queue.dart';
import '../ui/palette.dart';
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
  late final String _initialUrl;

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
  }

  /// Keep the preserved-page snapshot current so Browser Home can offer a way
  /// back to whatever is actually loaded — including the chapter hops an
  /// autonomous job makes.
  void _onBrowserChanged() {
    final browser = _browser;
    if (browser == null) return;
    final url = browser.currentUrl;
    if (url.isEmpty) return;
    _presentation?.rememberPage(PreservedPage(url: url, title: browser.title));
  }

  void _onPresentationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _browser?.removeListener(_onBrowserChanged);
    _presentation?.removeListener(_onPresentationChanged);
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
                        ? const Positioned.fill(
                            child: AbsorbPointer(
                              child: ColoredBox(color: Color(0x22000000)),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  _IdleActions(
                    job: job,
                    checker: checker,
                    onCapture: () => _showCaptureSheet(context),
                    onPageActions: _openPageActions,
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
                return CapturePanel(
                  job: job,
                  expanded: _panelOpen || job.isRunning,
                  onToggle: () => setState(() => _panelOpen = !_panelOpen),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCaptureSheet(BuildContext context) async {
    final choice = await showCaptureRangeSheet(
      context: context,
      config: ref.read(captureJobProvider).config,
      deviceStorage: ref.read(captureJobProvider).deviceStorage,
      currentTitle: ref.read(browserProvider).title,
    );
    if (choice == null || !context.mounted) return;
    await _startCapture(context, choice);
  }

  /// Preflight before anything downloads: if this chapter already exists, say
  /// so and ask, rather than starting a job that silently does nothing.
  ///
  /// Every start goes through the activity queue (M14): the decision-making
  /// stays here — the sheet resolves duplicates/conflicts *before* anything
  /// is enqueued — but the run itself is a queue task, so it appears in
  /// Activity history and serializes with checks on the shared WebView.
  Future<void> _startCapture(
    BuildContext context,
    CaptureRangeChoice choice,
  ) async {
    final job = ref.read(captureJobProvider);
    final queue = ref.read(taskQueueProvider);
    final url = ref.read(browserProvider).currentUrl;
    if (url.isEmpty) return;
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
      // `ask` here means: if the run later walks onto a chapter that is
      // already saved, hold and ask — never silently skip or re-download.
      final result = await queue.enqueueCapture(
        startUrl: url,
        chapterLimit: limit,
        policy: DuplicatePolicy.ask,
        range: choice.mode,
      );
      if (!context.mounted) return;
      // Queued, not started — even here, in the Browser (D46). The panel
      // opens when the run does, and the user stays on the page.
      showQueuedConfirmation(context, result);
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
        final existing = current.blockingJob;
        if (existing != null) await job.resumeJob(existing);

      case PreflightChoice.discardJobAndRestart:
        final existing = current.blockingJob;
        if (existing != null) await job.discardJob(existing);
        final restarted = await queue.enqueueCapture(
          startUrl: url,
          chapterLimit: limit,
          policy: decision.policy ?? DuplicatePolicy.skipComplete,
          range: choice.mode,
        );
        if (context.mounted) showQueuedConfirmation(context, restarted);

      case PreflightChoice.captureFollowing:
      case PreflightChoice.redownload:
      case PreflightChoice.retryMissing:
      case PreflightChoice.restartCapture:
      case PreflightChoice.repair:
      case PreflightChoice.captureNow:
        // "Re-download this chapter" is a single-chapter job even when the
        // sheet was opened from a larger request — the user asked for this
        // chapter, not a run starting at it.
        final isSingle =
            decision.choice == PreflightChoice.redownload ||
            decision.choice == PreflightChoice.retryMissing ||
            decision.choice == PreflightChoice.restartCapture ||
            decision.choice == PreflightChoice.repair;
        final queued = await queue.enqueueCapture(
          startUrl: url,
          chapterLimit: isSingle ? 1 : limit,
          policy: decision.policy ?? DuplicatePolicy.skipComplete,
          range: isSingle ? CaptureRangeMode.currentChapter : choice.mode,
        );
        if (context.mounted) showQueuedConfirmation(context, queued);

      case PreflightChoice.cancel:
        break;
    }
  }
}

/// The floating Capture button, the page-actions button, and the queued
/// chip — all of which only make sense when nothing is running.
class _IdleActions extends ConsumerWidget {
  const _IdleActions({
    required this.job,
    required this.checker,
    required this.onCapture,
    required this.onPageActions,
  });

  final Listenable job;
  final Listenable checker;
  final VoidCallback onCapture;
  final VoidCallback onPageActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobController = ref.watch(captureJobProvider);
    final checkerController = ref.watch(updateCheckerProvider);

    return AnimatedBuilder(
      animation: Listenable.merge([job, checker]),
      builder: (context, _) {
        if (jobController.isRunning || checkerController.isRunning) {
          return const SizedBox.shrink();
        }
        final tasks = ref.watch(queueTasksProvider).value ?? const [];
        final waiting = QueueSummary.of(tasks).queuedCaptures;

        return Positioned(
          left: 14,
          right: 14,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (waiting > 0) ...[
                QueuedCapturesChip(
                  count: waiting,
                  onViewActivity: () =>
                      LeaveBrowserGuard.push(context, '/activity'),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _RoundAction(
                    icon: Icons.more_horiz,
                    tooltip: 'Page actions',
                    onPressed: onPageActions,
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.extended(
                    heroTag: 'browserCapture',
                    onPressed: onCapture,
                    tooltip: 'Capture chapters',
                    backgroundColor: AppPalette.of(context).primary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Capture'),
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

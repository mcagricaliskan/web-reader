import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../browser/browser_controller.dart';
import '../capture/capture_preflight.dart';
import '../core/config.dart';
import '../providers.dart';
import 'capture_panel.dart';
import 'capture_queue_ui.dart';
import 'capture_preflight_sheet.dart';
import 'capture_range_sheet.dart';
import 'duplicate_decision_panel.dart';
import 'selection_overlay.dart';

/// The browser *and* the capture surface. One WebView, kept alive and visible
/// for the whole session: capture runs in exactly the environment the user
/// browsed in, and there is something to watch while it works.
class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  final _urlField = TextEditingController();
  final _urlFocus = FocusNode();
  bool _panelOpen = false;
  BrowserController? _browser;
  String _lastSyncedUrl = '';

  @override
  void initState() {
    super.initState();
    _urlField.text = widget.initialUrl ?? 'http://localhost:8099/chapter/1';
    _lastSyncedUrl = _urlField.text;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final browser = ref.read(browserProvider);
    if (identical(browser, _browser)) return;
    _browser?.removeListener(_syncAddressBar);
    _browser = browser..addListener(_syncAddressBar);
  }

  /// Keep the address bar on whatever page the WebView is actually showing —
  /// including redirects and the chapter hops an autonomous job makes. Skipped
  /// while the field has focus so it never overwrites what the user is typing.
  void _syncAddressBar() {
    final url = _browser?.currentUrl ?? '';
    if (url.isEmpty || url == _lastSyncedUrl) return;
    if (_urlFocus.hasFocus) return;
    _lastSyncedUrl = url;
    _urlField.value = TextEditingValue(
      text: url,
      selection: TextSelection.collapsed(offset: url.length),
    );
  }

  @override
  void dispose() {
    _browser?.removeListener(_syncAddressBar);
    _urlFocus.dispose();
    _urlField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browser = ref.watch(browserProvider);
    final job = ref.watch(captureJobProvider);
    final checker = ref.watch(updateCheckerProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _AddressBar(
              controller: _urlField,
              focusNode: _urlFocus,
              browser: browser,
              onGo: () {
                _urlFocus.unfocus();
                browser.load(_urlField.text);
              },
            ),
            _HostChangeBanner(browser: browser),
            AnimatedBuilder(
              animation: browser,
              builder: (context, _) => browser.isLoading
                  ? LinearProgressIndicator(
                      value: browser.progress == 0 ? null : browser.progress,
                      minHeight: 2,
                    )
                  : const SizedBox(height: 2),
            ),
            AnimatedBuilder(
              animation: browser,
              builder: (context, _) {
                final error = browser.lastError;
                if (error == null) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: Stack(
                children: [
                  _WebViewHost(browser: browser, initialUrl: _urlField.text),
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
      floatingActionButton: AnimatedBuilder(
        animation: Listenable.merge([job, checker]),
        builder: (context, _) {
          if (job.isRunning || checker.isRunning) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => _showCaptureSheet(context, job),
            tooltip: 'Capture chapters',
            backgroundColor: const Color(0xFF35606F),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.download, size: 20),
            label: const Text('Capture'),
          );
        },
      ),
    );
  }

  Future<void> _showCaptureSheet(BuildContext context, dynamic job) async {
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
      // opens when the run does.
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

class _AddressBar extends StatelessWidget {
  const _AddressBar({
    required this.controller,
    required this.focusNode,
    required this.browser,
    required this.onGo,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final BrowserController browser;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: browser,
      builder: (context, _) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFBFAF8),
          border: Border(bottom: BorderSide(color: Color(0xFFE7E3DC))),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            _NavButton(
              icon: Icons.arrow_back_ios_new,
              tooltip: 'Back',
              onPressed: browser.canGoBack ? browser.goBack : null,
            ),
            _NavButton(
              icon: Icons.arrow_forward_ios,
              tooltip: 'Forward',
              onPressed: browser.canGoForward ? browser.goForward : null,
            ),
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.only(left: 12, right: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEE9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE4E0D8)),
                ),
                child: Row(
                  children: [
                    Icon(
                      browser.currentUrl.startsWith('https://')
                          ? Icons.lock
                          : Icons.lock_open,
                      size: 15,
                      color: const Color(0xFF7A756C),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => onGo(),
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 12,
                          color: Color(0xFF3E3A34),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Enter a URL',
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      color: const Color(0xFF3E3A34),
                      icon: Icon(
                        browser.isLoading ? Icons.close : Icons.refresh,
                      ),
                      tooltip: browser.isLoading ? 'Stop' : 'Reload',
                      onPressed: browser.isLoading
                          ? browser.stopLoading
                          : browser.reload,
                    ),
                  ],
                ),
              ),
            ),
            _NavButton(
              icon: Icons.subdirectory_arrow_left,
              tooltip: 'Go',
              onPressed: onGo,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    tooltip: tooltip,
    color: const Color(0xFF3E3A34),
    disabledColor: const Color(0xFFB3ADA3),
    visualDensity: VisualDensity.compact,
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
      onReceivedError: (_, request, error) {
        if (request.isForMainFrame ?? true) {
          widget.browser.onError('${error.description} (${error.type})');
        }
      },
      onReceivedHttpError: (_, request, response) {
        if ((request.isForMainFrame ?? true) &&
            (response.statusCode ?? 0) >= 400) {
          widget.browser.onError('HTTP ${response.statusCode}');
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

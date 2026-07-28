import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'capture/capture_job.dart';
import 'features/activity_screen.dart';
import 'features/archived_screen.dart';
import 'core/local_reset.dart';
import 'features/browser_history_screen.dart';
import 'features/browser_screen.dart';
import 'features/developer_screen.dart';
import 'features/library_screen.dart';
import 'features/reader_screen.dart';
import 'features/rules_screen.dart';
import 'features/series_detail_screen.dart';
import 'features/cleanup_dialogs.dart';
import 'features/settings_screen.dart';
import 'features/storage_screen.dart';
import 'library/update_checker.dart';
import 'core/device_capacity_provider.dart';
import 'providers.dart';
import 'queue/task_queue.dart';
import 'storage/cleanup.dart';
import 'ui/palette.dart';
import 'ui/theme.dart';

/// The browser tab keeps its WebView alive across tab switches — the session
/// the user browsed with is the session capture runs in, so it must not be
/// rebuilt when they look at the library.
class WebReaderApp extends ConsumerStatefulWidget {
  const WebReaderApp({super.key});

  @override
  ConsumerState<WebReaderApp> createState() => _WebReaderAppState();
}

class _WebReaderAppState extends ConsumerState<WebReaderApp> {
  // Built per app instance, not as a top-level singleton: a global router
  // keeps its navigation stack across app restarts inside a test process, so
  // a second boot would come up on whatever route the first one ended on.
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _Shell()),
      GoRoute(
        path: '/reader/:chapterId',
        builder: (context, state) =>
            ReaderScreen(chapterId: state.pathParameters['chapterId']!),
      ),
      GoRoute(
        path: '/series/:seriesId',
        builder: (context, state) => SeriesDetailScreen(
          seriesId: state.pathParameters['seriesId']!,
          startInSelectionMode: state.uri.queryParameters['select'] == '1',
        ),
      ),
      GoRoute(path: '/rules', builder: (context, state) => const RulesScreen()),
      GoRoute(
        path: '/history',
        builder: (context, state) => const BrowserHistoryScreen(),
      ),
      GoRoute(
        path: '/activity',
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/archived',
        builder: (context, state) => const ArchivedScreen(),
      ),
      GoRoute(
        path: '/storage',
        builder: (context, state) => const StorageScreen(),
      ),
      // Registered only in debug: in release the route does not exist, so
      // even a hand-typed deep link cannot reach it (D50).
      if (developerToolsAvailable)
        GoRoute(
          path: '/developer',
          builder: (context, state) => const DeveloperScreen(),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // Read as a value, not awaited: the app must render on the first frame,
    // and the persisted preference arriving a microsecond later re-themes it
    // without a flash of the wrong appearance being possible to notice.
    final appearance =
        ref.watch(appearanceProvider).value ?? AppearanceMode.system;
    return MaterialApp.router(
      title: 'Web Reader',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      darkTheme: appDarkTheme(),
      themeMode: themeModeFor(appearance),
      routerConfig: _router,
    );
  }
}

class _Shell extends ConsumerStatefulWidget {
  const _Shell();

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  int _index = 0;

  // Held as fields: listeners must be removed in dispose, where Riverpod
  // forbids `ref`.
  late final CaptureJobController _job;
  late final UpdateChecker _checker;
  bool _wasBusy = false;

  late final ValueNotifier<int?> _tabRequest;
  late final CleanupService _cleanup;
  late final TaskQueueController _queue;

  /// Files just went away: the device figure the Library shows is stale by
  /// exactly the amount that was freed.
  void _onStorageChanged() {
    unawaited(ref.read(deviceCapacityProvider.notifier).refresh(force: true));
  }

  @override
  void initState() {
    super.initState();
    _job = ref.read(captureJobProvider);
    _checker = ref.read(updateCheckerProvider);
    _tabRequest = ref.read(shellTabRequestProvider);
    _job.addListener(_onAutomationChanged);
    _checker.addListener(_onAutomationChanged);
    _tabRequest.addListener(_onTabRequested);
    _cleanup = ref.read(cleanupProvider);
    _cleanup.removals.addListener(_onStorageChanged);
    // The queue asks the shell to bring the Browser forward before it drives
    // the WebView. The shell is the only thing that can switch tabs, and the
    // ordering — navigate, THEN automate — is the whole contract (D47).
    _queue = ref.read(taskQueueProvider);
    _queue.ensureBrowserVisible = _ensureBrowserVisible;
  }

  /// Show the Browser tab and wait for its WebView to attach.
  ///
  /// Attachment is not the same as *rendered*: the capture engine still runs
  /// its own zero-viewport guard (D32). This only guarantees the user is
  /// looking at the Browser before anything starts, so automation is never a
  /// surprise happening behind another screen.
  Future<bool> _ensureBrowserVisible() async {
    if (!mounted) return false;
    if (_index != 1) setState(() => _index = 1);
    final browser = ref.read(browserProvider);
    for (var i = 0; i < 100; i++) {
      if (!mounted) return false;
      if (browser.isAttached) return true;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return browser.isAttached;
  }

  @override
  void dispose() {
    _job.removeListener(_onAutomationChanged);
    _checker.removeListener(_onAutomationChanged);
    _tabRequest.removeListener(_onTabRequested);
    _cleanup.removals.removeListener(_onStorageChanged);
    _queue.ensureBrowserVisible = null;
    super.dispose();
  }

  /// True when leaving the Browser right now would strand a WebView-
  /// dependent phase. Downloading/saving phases and already-paused runs are
  /// deliberately excluded — the modal must not cry wolf.
  bool get _leavingBrowserIsRisky =>
      _index == 1 && (_job.needsRenderedBrowser || _checker.isRunning);

  /// The design's leave-Browser confirmation. Returns true when navigation
  /// may proceed (either nothing was at risk, or the user chose to pause).
  Future<bool> confirmLeaveBrowser() async {
    if (!_leavingBrowserIsRisky) return true;
    final leave = await showLeaveBrowserDialog(
      context: context,
      progressLine: _job.isRunning
          ? _job.progressSummary
          : 'Checking for new chapters',
    );
    if (!leave) return false;
    // Pause the WebView-dependent phase before anything moves. The task
    // stays active and queued work is untouched: this is a hold, not a stop.
    if (_job.isRunning) _job.pauseForBrowserHidden();
    return true;
  }

  /// A widget inside a tab asked for a tab switch (e.g. "Open Browser" on a
  /// capture that is holding on a hidden WebView).
  ///
  /// Deliberately does **not** call [_onEnteredBrowser]. "Open in Browser"
  /// arrives here having just paused a capture on purpose, and auto-resuming
  /// it on the way in would restart the run one frame before the page is
  /// navigated out from under it. Only a *user-initiated* tab tap ([_select])
  /// lifts a leave-pause.
  void _onTabRequested() {
    final requested = _tabRequest.value;
    if (requested == null) return;
    _tabRequest.value = null;
    if (requested != _index && requested >= 0 && requested <= 1) {
      setState(() => _index = requested);
    }
  }

  /// When a capture or update check starts, bring the Browser tab forward —
  /// what the design's prototype does, and also load-bearing: an offstage
  /// WKWebView throttles rAF and lazy-loading, so a capture driving a hidden
  /// WebView (e.g. started from series detail) would stall mid-scroll.
  /// Transition-edge only: once the user has seen the switch they are free to
  /// go back to the Library without the shell fighting them.
  void _onAutomationChanged() {
    final busy = _job.isRunning || _checker.isRunning;
    if (busy && !_wasBusy && _index != 1) {
      setState(() => _index = 1);
    }
    // Falling idle is the moment the disk actually changed: a capture just
    // wrote (or a check just did not). Re-read then, rather than polling —
    // the Library's percentage is otherwise as stale as its throttle allows.
    if (!busy && _wasBusy) {
      unawaited(ref.read(deviceCapacityProvider.notifier).refresh(force: true));
    }
    _wasBusy = busy;
  }

  /// Returning to the Browser: the capture engine's own render guard does
  /// the validating (viewport, then the page it was on). Here we only lift
  /// the leave-pause; if the page changed, the engine keeps holding and the
  /// Browser shows why.
  void _onEnteredBrowser() {
    if (_job.pauseReason == kPauseBrowserHidden) {
      _job.resumeAfterBrowserVisible();
    }
  }

  Future<void> _select(int i) async {
    if (i == _index) return;
    if (i != 1 && !await confirmLeaveBrowser()) return;
    if (!mounted) return;
    setState(() => _index = i);
    if (i == 1) _onEnteredBrowser();
  }

  @override
  Widget build(BuildContext context) {
    return LeaveBrowserGuard(
      confirm: confirmLeaveBrowser,
      // System back out of the shell is a leave too: block it while a
      // WebView-dependent phase is running, then let it through once the
      // user has answered.
      child: PopScope(
        canPop: !_leavingBrowserIsRisky,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          if (await confirmLeaveBrowser() && mounted) {
            navigator.maybePop();
          }
        },
        child: Scaffold(
          // IndexedStack, not a swapped child: switching tabs must not
          // dispose the WebView or a running capture dies with it.
          body: IndexedStack(
            index: _index,
            children: const [LibraryScreen(), BrowserScreen()],
          ),
          bottomNavigationBar: _BottomNav(index: _index, onSelect: _select),
        ),
      ),
    );
  }
}

/// Exposes the shell's leave-Browser confirmation to anything that can
/// navigate away from it — route pushes (Settings, Activity, Storage,
/// Archived, Rules) and system back.
///
/// An InheritedWidget rather than a provider so a widget deep in the Library
/// or Browser tab can ask "may I navigate?" without knowing the shell exists.
class LeaveBrowserGuard extends InheritedWidget {
  const LeaveBrowserGuard({
    super.key,
    required this.confirm,
    required super.child,
  });

  /// Resolves true when navigation may proceed.
  final Future<bool> Function() confirm;

  static LeaveBrowserGuard? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LeaveBrowserGuard>();

  /// Ask before leaving. Safe to call from anywhere — with no guard in the
  /// tree (tests, deep routes) it simply allows the navigation.
  static Future<bool> confirmLeave(BuildContext context) async {
    final guard = maybeOf(context);
    if (guard == null) return true;
    return guard.confirm();
  }

  /// Guarded `context.push`: confirms first when a capture needs the
  /// Browser, then navigates. Used by every route that leaves the Browser.
  static Future<void> push(BuildContext context, String location) async {
    if (!await confirmLeave(context)) return;
    if (context.mounted) context.push(location);
  }

  @override
  bool updateShouldNotify(LeaveBrowserGuard oldWidget) =>
      confirm != oldWidget.confirm;
}

/// The design's two-item bar: a filled pill behind the selected glyph rather
/// than Material's default indicator, and no ripple sprawl. Plain Material
/// widgets only, so it renders identically on iOS and Android; the bottom
/// inset comes from [MediaQuery] rather than an assumed iPhone home bar.
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.collections_bookmark, 'Library'),
      (Icons.public, 'Browser'),
    ];

    final palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.divider)),
      ),
      padding: EdgeInsets.only(
        top: 6,
        bottom: 6 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                key: ValueKey('navTab-${items[i].$2}'),
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(16),
                child: _NavItem(
                  icon: items[i].$1,
                  label: items[i].$2,
                  selected: i == index,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fg = selected ? palette.onPrimaryContainer : palette.inkMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? palette.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 22, color: fg),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontVariations: wght(selected ? 600 : 400),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

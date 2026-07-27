import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'capture/capture_job.dart';
import 'features/activity_screen.dart';
import 'features/archived_screen.dart';
import 'features/browser_screen.dart';
import 'features/library_screen.dart';
import 'features/reader_screen.dart';
import 'features/rules_screen.dart';
import 'features/series_detail_screen.dart';
import 'features/settings_screen.dart';
import 'library/update_checker.dart';
import 'providers.dart';
import 'ui/theme.dart';

/// The browser tab keeps its WebView alive across tab switches — the session
/// the user browsed with is the session capture runs in, so it must not be
/// rebuilt when they look at the library.
class WebReaderApp extends StatefulWidget {
  const WebReaderApp({super.key});

  @override
  State<WebReaderApp> createState() => _WebReaderAppState();
}

class _WebReaderAppState extends State<WebReaderApp> {
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
        builder: (context, state) =>
            SeriesDetailScreen(seriesId: state.pathParameters['seriesId']!),
      ),
      GoRoute(path: '/rules', builder: (context, state) => const RulesScreen()),
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
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Web Reader',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
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

  @override
  void initState() {
    super.initState();
    _job = ref.read(captureJobProvider);
    _checker = ref.read(updateCheckerProvider);
    _tabRequest = ref.read(shellTabRequestProvider);
    _job.addListener(_onAutomationChanged);
    _checker.addListener(_onAutomationChanged);
    _tabRequest.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    _job.removeListener(_onAutomationChanged);
    _checker.removeListener(_onAutomationChanged);
    _tabRequest.removeListener(_onTabRequested);
    super.dispose();
  }

  /// A widget inside a tab asked for a tab switch (e.g. "Open Browser" on a
  /// capture that is holding on a hidden WebView).
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
    _wasBusy = busy;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack, not a swapped child: switching tabs must not dispose the
      // WebView or a running capture dies with it.
      body: IndexedStack(
        index: _index,
        children: const [LibraryScreen(), BrowserScreen()],
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
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

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFBFAF8),
        border: Border(top: BorderSide(color: Color(0xFFEFECE7))),
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
    final fg = selected ? const Color(0xFF133845) : const Color(0xFF5F5B54);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEAF1F4) : Colors.transparent,
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

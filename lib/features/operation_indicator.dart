import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart' show kShellBottomBarHeight;
import '../library/update_checker.dart';
import '../providers.dart';
import '../save/save_run.dart';
import '../save/save_state.dart';
import '../ui/palette.dart';
import 'open_in_browser.dart';

/// What a running operation looks like from anywhere that is not the Browser.
///
/// Hosted above the router, so it is reachable from the Reader, the Library,
/// Settings and every screen that is pushed over them. It is **free and never
/// gated**: knowing what your device is doing, and being able to stop it, is
/// not a feature to sell (docs/FOREGROUND_MULTITASKING.md §10.1).
///
/// Absent on the Browser itself, which already shows the save and check panels
/// in full — two accounts of the same run, one over the other, is how a user
/// stops believing either.
class OperationIndicator extends ConsumerStatefulWidget {
  const OperationIndicator({super.key});

  @override
  ConsumerState<OperationIndicator> createState() => _OperationIndicatorState();
}

class _OperationIndicatorState extends ConsumerState<OperationIndicator> {
  late final SaveRunController _run;
  late final UpdateChecker _checker;
  late final ValueNotifier<bool> _browserOnScreen;

  @override
  void initState() {
    super.initState();
    _run = ref.read(saveRunProvider);
    _checker = ref.read(updateCheckerProvider);
    _browserOnScreen = ref.read(browserOnScreenProvider);
    _run.addListener(_onChanged);
    _checker.addListener(_onChanged);
    _browserOnScreen.addListener(_onChanged);
  }

  @override
  void dispose() {
    _run.removeListener(_onChanged);
    _checker.removeListener(_onChanged);
    _browserOnScreen.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// True when the operation will not move again until a person does
  /// something. Distinct from merely waiting, which resolves itself.
  bool get _needsUser {
    if (_checker.pendingSelection != null) return true;
    if (!_run.isRunning) return false;
    return switch (_run.progress.state) {
      SaveState.awaitingSelection || SaveState.waitingForBrowser => true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final saving = _run.isRunning;
    final checking = _checker.isRunning;
    if ((!saving && !checking) || _browserOnScreen.value) {
      return const SizedBox.shrink();
    }

    final palette = AppPalette.of(context);
    final title = saving
        ? _run.progress.state.label
        : (_checker.activeTitle.isEmpty
              ? 'Checking for new entries'
              : 'Checking ${_checker.activeTitle}');
    final detail = saving
        ? _run.progressSummary
        : '${_checker.pagesInspected} page(s) · '
              '${_checker.newEntries} new entry(s)';

    return Positioned(
      left: 12,
      right: 12,
      // Clear of the shell's bottom bar, which is the one piece of chrome that
      // is always in the same place; on a pushed screen it simply floats a
      // little higher than the edge.
      bottom: 12 + kShellBottomBarHeight + MediaQuery.paddingOf(context).bottom,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: _needsUser
            ? 'Needs you: $title. $detail'
            : 'Running: $title. $detail',
        child: Material(
          color: palette.surface,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.divider),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: _needsUser
                        ? Icon(
                            Icons.error_outline,
                            size: 18,
                            color: palette.primary,
                          )
                        : CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.primary,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _needsUser ? 'Needs you' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                        if (detail.isNotEmpty)
                          Text(
                            _needsUser ? title : detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_needsUser)
                  TextButton(
                    key: const ValueKey('operationIndicator-open'),
                    onPressed: () => showBrowserSurface(context, ref),
                    child: const Text('Open Browser'),
                  ),
                TextButton(
                  key: const ValueKey('operationIndicator-stop'),
                  onPressed: _stop,
                  child: const Text('Stop'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Stops through the controllers themselves, which is the same path the
  /// Browser's own panels use. No second cancellation route is introduced —
  /// there is exactly one winner, and it is decided where it always was.
  void _stop() {
    if (_run.isRunning) _run.stop();
    if (_checker.isRunning) _checker.cancel();
  }
}

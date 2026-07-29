import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../storage/cleanup.dart';
import '../ui/palette.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';

/// The one-time cleanup question for a series (D37).
///
/// Asked on the first eligible forward transition inside a series that has no
/// stored decision, and never again unless the decision is reset. It is a
/// choice between two named outcomes with an explicit *Save choice* — not a
/// yes/no about the chapter in hand, because what is being saved is a rule for
/// the series.
///
/// `Remove after continuing` is preselected, always. The preselection is a
/// constant of this widget: no global setting, no other series and no previous
/// answer can reach it. Dismissing without saving returns null, which stores
/// nothing and keeps the files.
Future<SeriesCleanupPref?> showSeriesCleanupDialog({
  required BuildContext context,
  required String seriesName,
}) => showDialog<SeriesCleanupPref>(
  context: context,
  builder: (context) => _SeriesCleanupDialog(seriesName: seriesName),
);

class _SeriesCleanupDialog extends StatefulWidget {
  const _SeriesCleanupDialog({required this.seriesName});

  final String seriesName;

  @override
  State<_SeriesCleanupDialog> createState() => _SeriesCleanupDialogState();
}

class _SeriesCleanupDialogState extends State<_SeriesCleanupDialog> {
  /// The preselected answer, fixed by the product model (D37).
  SeriesCleanupPref _choice = SeriesCleanupPref.remove;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AlertDialog(
      // Two option rows and their explanations are taller than a short phone
      // in landscape: the content scrolls rather than overflowing.
      scrollable: true,
      icon: Icon(Icons.folder_open, size: 26, color: palette.inkMuted),
      title: const Text('Downloaded chapters in this series'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.seriesName,
            style: TextStyle(
              fontSize: 12,
              fontVariations: wght(600),
              fontWeight: FontWeight.w600,
              color: palette.inkStrong,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "What should happen to a finished chapter's downloaded files "
            'after you continue to the next chapter?',
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: palette.inkMuted,
            ),
          ),
          const SizedBox(height: 13),
          for (final option in _cleanupOptions) ...[
            CleanupPrefOption(
              optionKey: 'seriesCleanup-${option.$1?.name ?? 'ask'}',
              label: option.$2,
              sub: option.$3,
              selected: _choice == option.$1,
              onTap: () => setState(() => _choice = option.$1!),
            ),
            const SizedBox(height: 7),
          ],
          const SizedBox(height: 3),
          Text(
            'This choice applies only to this series. You can change it later '
            'from the series settings.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: palette.inkFaint,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          key: const ValueKey('saveSeriesCleanup'),
          onPressed: () => Navigator.pop(context, _choice),
          child: const Text('Save choice'),
        ),
      ],
    );
  }
}

/// The two outcomes, in the order they are offered. Shared by the dialog and
/// the series sheet so a rename can never drift between them.
const _cleanupOptions = <(SeriesCleanupPref?, String, String)>[
  (
    SeriesCleanupPref.remove,
    'Remove after continuing',
    'When you move on to the next chapter, the finished one\'s downloaded '
        'files are removed. It stays in your library with your reading '
        'history, and you can capture it again any time.',
  ),
  (
    SeriesCleanupPref.keep,
    'Keep downloaded files',
    'Finished chapters stay on this device until you remove them yourself.',
  ),
];

/// Settings-sheet-shaped radio row. Public because the series sheet and the
/// first-transition dialog draw the same control.
class CleanupPrefOption extends StatelessWidget {
  const CleanupPrefOption({
    super.key,
    required this.optionKey,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String optionKey;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: selected ? palette.primaryContainer : palette.surfaceMuted,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey(optionKey),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? palette.primaryBorder : palette.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? palette.primary : palette.inkMuted,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontVariations: wght(500),
                        fontWeight: FontWeight.w500,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One removal confirmation for every scope: a single chapter, a selection,
/// a whole series, or every finished chapter. Facts are computed by the
/// caller so this widget never guesses at sizes.
class RemovalSummary {
  const RemovalSummary({
    required this.title,
    required this.body,
    required this.facts,
    this.lockNote,
    this.cta = 'Remove files',
  });

  final String title;
  final String body;

  /// key → value rows ("Chapters" → "412", "Space freed" → "~3.4 GB").
  final List<(String, String)> facts;

  /// Chapters that will be kept because something is using them.
  final String? lockNote;
  final String cta;
}

Future<bool> showRemovalConfirm({
  required BuildContext context,
  required RemovalSummary summary,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final palette = AppPalette.of(context);
      return AlertDialog(
        icon: Icon(Icons.delete_sweep, size: 26, color: palette.inkMuted),
        title: Text(summary.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.body,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: palette.inkMuted,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  for (final (k, v) in summary.facts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            k,
                            style: monoStyle(
                              size: 11.5,
                              color: palette.inkMuted,
                            ),
                          ),
                          Text(
                            v,
                            style: monoStyle(size: 11.5, color: palette.ink),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (summary.lockNote != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock, size: 15, color: palette.warn),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      summary.lockNote!,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: palette.warn,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(summary.cta),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// The design's dark toast, with an optional Undo.
void showCleanupToast(
  BuildContext context, {
  required String text,
  Future<void> Function()? undo,
  IconData icon = Icons.delete_sweep,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final palette = AppPalette.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(milliseconds: 4200),
      // `SnackBar.persist` defaults to `action != null`, which means a snack
      // bar with an Undo NEVER times out — [duration] is ignored and it sits
      // there until something dismisses it. Only a screen reader has a real
      // claim on that behaviour (reaching the action takes longer), so that is
      // the only case where it is kept.
      persist: MediaQuery.maybeOf(context)?.accessibleNavigation ?? false,
      backgroundColor: palette.toastSurface,
      content: Row(
        children: [
          Icon(icon, size: 19, color: palette.toastAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: palette.toastInk,
              ),
            ),
          ),
        ],
      ),
      action: undo == null
          ? null
          : SnackBarAction(
              label: 'Undo',
              textColor: palette.toastAccent,
              onPressed: () async {
                await undo();
                if (context.mounted) {
                  showCleanupToast(
                    context,
                    text: 'Restored — the files are back',
                    icon: Icons.undo,
                  );
                }
              },
            ),
    ),
  );
}

/// Series detail › "Downloaded chapters": change or reset this series'
/// decision (D37).
///
/// Three options, because a decision that cannot be un-made is a trap: the two
/// outcomes, plus *Ask again next time*, which clears the stored value so the
/// question comes back on the next eligible transition. There is no "use the
/// global setting" — no global setting exists.
///
/// Each tap writes immediately and only ever to [seriesId], captured when the
/// sheet was opened.
Future<void> showSeriesCleanupSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String seriesId,
  required String seriesName,
  required SeriesCleanupPref? current,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => _SeriesCleanupSheet(
    seriesId: seriesId,
    seriesName: seriesName,
    initial: current,
  ),
);

class _SeriesCleanupSheet extends ConsumerStatefulWidget {
  const _SeriesCleanupSheet({
    required this.seriesId,
    required this.seriesName,
    required this.initial,
  });

  final String seriesId;
  final String seriesName;
  final SeriesCleanupPref? initial;

  @override
  ConsumerState<_SeriesCleanupSheet> createState() =>
      _SeriesCleanupSheetState();
}

class _SeriesCleanupSheetState extends ConsumerState<_SeriesCleanupSheet> {
  late SeriesCleanupPref? _value = widget.initial;

  Future<void> _select(SeriesCleanupPref? pref) async {
    setState(() => _value = pref);
    // Writes a rule, never a command: nothing already downloaded moves because
    // of this tap.
    await ref
        .read(databaseProvider)
        .setSeriesFinishedCleanup(widget.seriesId, pref?.name);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Downloaded chapters',
              style: serifStyle(size: 20, color: palette.ink),
            ),
            const SizedBox(height: 5),
            Text(
              'What happens to a finished chapter\'s downloaded files in '
              '${widget.seriesName} when you continue to the next chapter. '
              'Changing this never removes anything you already have.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: palette.inkMuted,
              ),
            ),
            const SizedBox(height: 14),
            for (final option in const [
              ..._cleanupOptions,
              (
                null,
                'Ask again next time',
                'Clears this choice. The next time you finish a chapter here '
                    'and continue, the question comes back.',
              ),
            ]) ...[
              CleanupPrefOption(
                optionKey: 'seriesCleanupPref-${option.$1?.name ?? 'ask'}',
                label: option.$2,
                sub: option.$3,
                selected: _value == option.$1,
                onTap: () => _select(option.$1),
              ),
              const SizedBox(height: 7),
            ],
            const SizedBox(height: 3),
            Text(
              'This applies to this series only. Other series keep their own '
              'choice.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: palette.inkFaint,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one-line summary of a series' decision, for the menu row that opens
/// [showSeriesCleanupSheet].
String seriesCleanupSummary(SeriesCleanupPref? pref) => switch (pref) {
  SeriesCleanupPref.remove => 'Remove after continuing',
  SeriesCleanupPref.keep => 'Keep downloaded files',
  null => 'Not set · asked when you finish a chapter',
};

/// The design's leave-Browser modal. Returns true when the user chose
/// "Leave and pause".
Future<bool> showLeaveBrowserDialog({
  required BuildContext context,
  required String progressLine,
}) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) {
      final palette = AppPalette.of(context);
      return AlertDialog(
        icon: Icon(Icons.public, size: 26, color: palette.primary),
        title: const Text('Leave the Browser?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capture needs the Browser to stay open. Leaving now pauses it — '
              'nothing captured so far is lost, and it resumes when you come '
              'back.',
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: palette.inkMuted,
              ),
            ),
            if (progressLine.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  progressLine,
                  style: monoStyle(size: 11.5, color: palette.inkMuted),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave and pause'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay in Browser'),
          ),
        ],
      );
    },
  );
  return leave ?? false;
}

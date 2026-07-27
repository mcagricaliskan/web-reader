import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../storage/cleanup.dart';
import '../storage/database.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';
import 'library_screen.dart' show formatBytes;

/// What the finished-chapter dialog returned.
class FinishedChapterChoice {
  const FinishedChapterChoice({
    required this.remove,
    required this.rememberChoice,
  });

  final bool remove;

  /// "Don't ask again" was ticked — the choice becomes the persistent
  /// preference (keep → keep offline, remove → remove automatically).
  final bool rememberChoice;
}

/// Asked after finishing a chapter and continuing forward, when the stored
/// preference is `ask`.
///
/// Keep is the highlighted (primary) action deliberately: the safest default
/// preserves files. Dismissing the dialog keeps too.
Future<FinishedChapterChoice?> showFinishedChapterDialog({
  required BuildContext context,
  required Chapter chapter,
}) {
  var remember = false;
  final label = chapter.chapterLabel ?? chapter.title;

  return showDialog<FinishedChapterChoice>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        icon: const Icon(
          Icons.library_add_check,
          size: 26,
          color: Color(0xFF5F5B54),
        ),
        title: const Text('Remove the finished chapter?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You finished $label. Removing its offline files frees '
              '${formatBytes(chapter.byteSize)}. It stays in your library '
              'with your reading history — you can capture it again any time.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.55,
                color: Color(0xFF5F5B54),
              ),
            ),
            InkWell(
              onTap: () => setState(() => remember = !remember),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 14, 2, 4),
                child: Row(
                  children: [
                    Icon(
                      remember
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 21,
                      color: remember
                          ? const Color(0xFF35606F)
                          : const Color(0xFF5F5B54),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        remember
                            ? "Don't ask again — your next choice becomes the "
                                  'default for every finished chapter (change '
                                  'it in Settings › Storage)'
                            : "Don't ask again — this choice applies to "
                                  '$label only',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Color(0xFF3E3A34),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              FinishedChapterChoice(remove: true, rememberChoice: remember),
            ),
            child: const Text('Remove offline files'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              FinishedChapterChoice(remove: false, rememberChoice: remember),
            ),
            child: const Text('Keep offline'),
          ),
        ],
      ),
    ),
  );
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
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_sweep, size: 26, color: Color(0xFF5F5B54)),
      title: Text(summary.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Color(0xFF5F5B54),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3EF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE7E3DC)),
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
                            color: const Color(0xFF4A463F),
                          ),
                        ),
                        Text(
                          v,
                          style: monoStyle(
                            size: 11.5,
                            color: const Color(0xFF4A463F),
                          ),
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
                const Icon(Icons.lock, size: 15, color: Color(0xFF8A5A1F)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    summary.lockNote!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: Color(0xFF8A5A1F),
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
    ),
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
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(milliseconds: 4200),
      backgroundColor: const Color(0xFF201F1C),
      content: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF9FC3CE)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Color(0xFFF2EFE9),
              ),
            ),
          ),
        ],
      ),
      action: undo == null
          ? null
          : SnackBarAction(
              label: 'Undo',
              textColor: const Color(0xFF9FC3CE),
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

/// Settings › Storage › "After finishing a chapter": the three-option sheet.
Future<void> showAfterFinishedSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final current =
            ref.watch(afterFinishedPrefProvider).value ?? AfterFinishedPref.ask;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('After finishing a chapter', style: serifStyle(size: 20)),
                const SizedBox(height: 5),
                const Text(
                  'Applies when you continue from a finished chapter to the '
                  'next one. Changing this never removes anything you '
                  'already have.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Color(0xFF5F5B54),
                  ),
                ),
                const SizedBox(height: 14),
                for (final option in const [
                  (
                    AfterFinishedPref.ask,
                    'Ask each time',
                    'When you finish a chapter and continue, the app asks. '
                        'Keeping the files is always the highlighted answer.',
                  ),
                  (
                    AfterFinishedPref.keep,
                    'Keep offline',
                    'Never ask. Finished chapters stay on the device until '
                        'you remove them.',
                  ),
                  (
                    AfterFinishedPref.remove,
                    'Remove automatically',
                    'After you continue past a finished chapter, its files '
                        'are removed. Read marks and history are kept. Never '
                        'touches the open chapter or anything mid-capture.',
                  ),
                ]) ...[
                  _PrefOption(
                    label: option.$2,
                    sub: option.$3,
                    selected: current == option.$1,
                    onTap: () => setAfterFinishedPref(ref, option.$1),
                  ),
                  const SizedBox(height: 7),
                ],
                const SizedBox(height: 3),
                Text(
                  current == AfterFinishedPref.remove
                      ? 'Applies to chapters you finish from now on. '
                            'Already-downloaded chapters are not touched — use '
                            'Storage › Remove finished offline chapters for '
                            'those.'
                      : 'You can change this any time.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: Color(0xFF8C877E),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
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
      },
    ),
  );
}

class _PrefOption extends StatelessWidget {
  const _PrefOption({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFEAF1F4) : const Color(0xFFF5F3EF),
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFD2E2E8) : const Color(0xFFE7E3DC),
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
              color: selected
                  ? const Color(0xFF35606F)
                  : const Color(0xFF5F5B54),
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: Color(0xFF5F5B54),
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

/// The design's leave-Browser modal. Returns true when the user chose
/// "Leave and pause".
Future<bool> showLeaveBrowserDialog({
  required BuildContext context,
  required String progressLine,
}) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.public, size: 26, color: Color(0xFF35606F)),
      title: const Text('Leave the Browser?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Capture needs the Browser to stay open. Leaving now pauses it — '
            'nothing captured so far is lost, and it resumes when you come '
            'back.',
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Color(0xFF5F5B54),
            ),
          ),
          if (progressLine.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3EF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7E3DC)),
              ),
              child: Text(
                progressLine,
                style: monoStyle(size: 11.5, color: const Color(0xFF4A463F)),
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
    ),
  );
  return leave ?? false;
}

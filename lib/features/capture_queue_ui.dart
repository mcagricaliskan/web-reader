import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../providers.dart';
import '../queue/task_queue.dart';
import '../library/series_identity.dart';
import '../storage/database.dart';
import '../ui/status_style.dart';

/// Everything the "queue it now, start it later" flow needs on screen.
///
/// The rule this file exists to enforce (D46): **queueing never starts
/// anything.** Every entry point here confirms in place and leaves the user
/// where they were. The only thing that opens the Browser is
/// [confirmAndStartCaptures], and only after the user says so.

/// "Added to capture queue", with a way to look but no redirect.
///
/// A snackbar rather than a dialog: the user asked for one small thing and
/// should be able to keep going. The action is an offer, not a funnel.
void showQueuedConfirmation(
  BuildContext context,
  QueueEnqueueResult result, {
  String? what,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final subject = what == null ? '' : ' · $what';
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          result.alreadyQueued
              ? 'This episode is already in the capture queue.$subject'
              : 'Added to capture queue$subject',
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View Activity',
          onPressed: () => LeaveBrowserGuard.push(context, '/activity'),
        ),
      ),
    );
}

/// A direct start that could not begin, said plainly.
///
/// Nothing was queued and nothing was started — the request is simply not
/// under way, and the user is still where they were, so this is a line of text
/// rather than a dialog they have to dismiss.
void showDirectStartRefusal(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const ValueKey('directStartRefused'),
        content: Text(message),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View Activity',
          onPressed: () => LeaveBrowserGuard.push(context, '/activity'),
        ),
      ),
    );
}

/// The same confirmation for a multi-select batch, which has more to say:
/// how many went in, how many were already there, and how many could not go
/// because the chapter has no source page.
void showBatchQueuedConfirmation(BuildContext context, BatchQueueResult r) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final parts = <String>[
    if (r.queued > 0) '${r.queued} added to capture queue',
    if (r.alreadyQueued.isNotEmpty) '${r.alreadyQueued.length} already queued',
    if (r.missingSource.isNotEmpty)
      '${r.missingSource.length} have no source page',
  ];
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(parts.isEmpty ? 'Nothing to queue' : parts.join(' · ')),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'View Activity',
          onPressed: () => LeaveBrowserGuard.push(context, '/activity'),
        ),
      ),
    );
}

/// What a batch would do, shown *before* it is queued.
class BatchQueuePlan {
  const BatchQueuePlan({
    required this.seriesName,
    required this.capturable,
    required this.missingSource,
    required this.estimatedBytes,
  });

  final String seriesName;
  final List<Chapter> capturable;
  final List<Chapter> missingSource;

  /// Best effort: the average of whatever sizes we have already seen for this
  /// series, times the number of chapters. Null when nothing has ever been
  /// captured here, because a made-up number is worse than no number.
  final int? estimatedBytes;

  int get selected => capturable.length + missingSource.length;

  /// "488 – 490", or a single label, or empty when nothing is numbered.
  String get range {
    if (capturable.isEmpty) return '';
    final ordered = sortChaptersForCaptureOrder(capturable);
    final first = _label(ordered.first);
    final last = _label(ordered.last);
    return first == last ? first : '$first – $last';
  }

  static String _label(Chapter c) => chapterDisplayLabel(
    number: c.chapterNumber,
    rawLabel: c.chapterLabel,
    title: c.title,
  );
}

/// Ask before queueing a batch: the counts are the point, especially the
/// chapters that cannot be queued at all.
Future<bool> showBatchQueueConfirm({
  required BuildContext context,
  required BatchQueuePlan plan,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add to capture queue',
              style: serifStyle(size: 22),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 6),
            Text(
              'These episodes will wait in the queue. Nothing downloads '
              'until you start the queue and open the Browser.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF5F5B54),
              ),
            ),
            const SizedBox(height: 16),
            _PlanFact('Series', plan.seriesName),
            _PlanFact('Selected', '${plan.selected} episodes'),
            _PlanFact(
              'Can be queued',
              '${plan.capturable.length}'
                  '${plan.range.isEmpty ? '' : ' · ${plan.range}'}',
            ),
            if (plan.missingSource.isNotEmpty)
              _PlanFact(
                'No source page',
                '${plan.missingSource.length} — these cannot be captured '
                    'automatically',
                warn: true,
              ),
            if (plan.estimatedBytes != null)
              _PlanFact(
                'Estimated',
                '≈ ${formatBytesForQueue(plan.estimatedBytes!)}',
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: plan.capturable.isEmpty
                  ? null
                  : () => Navigator.of(sheetContext).pop(true),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                plan.capturable.isEmpty
                    ? 'Nothing can be queued'
                    : 'Queue ${plan.capturable.length} for re-download',
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

class _PlanFact extends StatelessWidget {
  const _PlanFact(this.label, this.value, {this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: monoStyle(size: 11.5, color: const Color(0xFF8C877E)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: warn ? const Color(0xFF8A5A1F) : const Color(0xFF3E3A34),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The Start Capture confirmation, and the only place Browser automation is
/// authorised from.
///
/// It spells out the two facts that decide whether now is a good time: the
/// Browser has to stay visible while pages are prepared, and once a page is
/// prepared its downloads carry on without it.
Future<bool> confirmAndStartCaptures(
  BuildContext context,
  WidgetRef ref,
) async {
  final queue = ref.read(taskQueueProvider);
  final waiting = await queue.queuedCaptures();
  if (!context.mounted) return false;
  if (waiting.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Nothing is waiting in the capture queue.')),
    );
    return false;
  }

  final start = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.play_circle, size: 26, color: Color(0xFF35606F)),
      title: const Text('Start queued captures?'),
      content: Text(
        'The Browser will open and must remain visible while pages are '
        'prepared.\n\n'
        'You can add more episodes to the queue before starting. Once each '
        'page is prepared, its image downloads may continue from Activity.',
        style: const TextStyle(fontSize: 13.5, height: 1.55),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop(false);
            LeaveBrowserGuard.push(context, '/activity');
          },
          child: const Text('View queue'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Start and open Browser'),
        ),
      ],
    ),
  );
  if (start != true) return false;

  // Browser first, automation second — never the other way round (D47).
  ref.read(shellTabRequestProvider).value = 1;
  await queue.startQueuedCaptures();
  return true;
}

String formatBytesForQueue(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).round()} MB';
  return '${(bytes / 1024).round()} KB';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../providers.dart';
import '../queue/task_queue.dart';
import '../storage/database.dart';
import '../ui/palette.dart';
import '../ui/status_style.dart';
import '../library/entry_labels.dart';

/// Everything the "queue it now, start it later" flow needs on screen.
///
/// The rule this file exists to enforce (D46): **queueing never starts
/// anything.** Every entry point here confirms in place and leaves the user
/// where they were. The only thing that opens the Browser is
/// [confirmAndStartSaves], and only after the user says so.

/// "Added to save queue", with a way to look but no redirect.
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
              ? 'This entry is already in the save queue.$subject'
              : 'Added to save queue$subject',
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
/// because the entry has no source page.
void showBatchQueuedConfirmation(BuildContext context, BatchQueueResult r) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final parts = <String>[
    if (r.queued > 0) '${r.queued} added to save queue',
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
    required this.collectionName,
    required this.capturable,
    required this.missingSource,
    required this.estimatedBytes,
  });

  final String collectionName;
  final List<Entry> capturable;
  final List<Entry> missingSource;

  /// Best effort: the average of whatever sizes we have already seen for this
  /// collection, times the number of entries. Null when nothing has ever been
  /// saved here, because a made-up number is worse than no number.
  final int? estimatedBytes;

  int get selected => capturable.length + missingSource.length;

  /// "488 – 490", or a single label, or empty when nothing is numbered.
  String get range {
    if (capturable.isEmpty) return '';
    final ordered = sortEntriesForSaveOrder(capturable);
    final first = _label(ordered.first);
    final last = _label(ordered.last);
    return first == last ? first : '$first – $last';
  }

  static String _label(Entry c) => entryDisplayLabel(
    labels: labelsFromNames(
      contentKind: c.contentKind,
      confidence: c.contentKindConfidence,
    ),
    number: c.entryNumber,
    sourceMarker: c.sourceMarker,
    title: c.title,
  );
}

/// Ask before queueing a batch: the counts are the point, especially the
/// entries that cannot be queued at all.
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
              'Add to save queue',
              style: serifStyle(size: 22),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 6),
            Text(
              'These entries will wait in the queue. Nothing downloads '
              'until you start the queue and open the Browser.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppPalette.of(context).inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            _PlanFact('Collection', plan.collectionName),
            _PlanFact('Selected', '${plan.selected} entries'),
            _PlanFact(
              'Can be queued',
              '${plan.capturable.length}'
                  '${plan.range.isEmpty ? '' : ' · ${plan.range}'}',
            ),
            if (plan.missingSource.isNotEmpty)
              _PlanFact(
                'No source page',
                '${plan.missingSource.length} — these cannot be saved '
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
            style: monoStyle(
              size: 11.5,
              color: AppPalette.of(context).inkFaint,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: warn
                  ? AppPalette.of(context).warn
                  : AppPalette.of(context).inkStrong,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The Start Save confirmation, and the only place Browser automation is
/// authorised from.
///
/// It spells out the two facts that decide whether now is a good time: the
/// Browser has to stay visible while pages are prepared, and once a page is
/// prepared its downloads carry on without it.
Future<bool> confirmAndStartSaves(BuildContext context, WidgetRef ref) async {
  final queue = ref.read(taskQueueProvider);
  final waiting = await queue.queuedSaves();
  if (!context.mounted) return false;
  if (waiting.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Nothing is waiting in the save queue.')),
    );
    return false;
  }

  final start = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        Icons.play_circle,
        size: 26,
        color: AppPalette.of(dialogContext).primary,
      ),
      title: const Text('Start queued saves?'),
      content: Text(
        'The Browser will open and must remain visible while pages are '
        'prepared.\n\n'
        'You can add more entries to the queue before starting. Once each '
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
  await queue.startQueuedSaves();
  return true;
}

// --- cancelling and removing (D64) -----------------------------------------

/// Ask before stopping work that is already under way.
///
/// The dividing line for a dialog is whether anything is *lost*: a waiting row
/// has done nothing, so it goes on a tap with an Undo; a running one has
/// partial progress, so it gets a sentence about what survives and what does
/// not. The copy is per task type because "the entry in progress is
/// discarded" is nonsense for a file removal.
Future<bool> confirmStopRunningTask(
  BuildContext context,
  QueueTaskType type,
) async {
  final (title, body, stop) = switch (type) {
    QueueTaskType.entrySave || QueueTaskType.sequenceSave => (
      'Stop this save?',
      'It stops at the next safe point. Entries already saved are kept — '
          'the one in progress is discarded and can be saved again later.',
      'Stop save',
    ),
    QueueTaskType.collectionCheck || QueueTaskType.checkAllCollections => (
      'Stop this update check?',
      'It stops at the next safe point. Entries it already found stay in '
          'the library; the rest of the collection is simply not checked yet.',
      'Stop check',
    ),
    QueueTaskType.removeOfflineFiles => (
      'Stop removing files?',
      'It stops after the current entry. Files already removed stay '
          'removed — every remaining entry keeps its files. No reading '
          'history is affected either way.',
      'Stop removing',
    ),
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(fontSize: 13.5, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep going'),
        ),
        FilledButton(
          key: const ValueKey('confirmStopTask'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(stop),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Cancel a waiting row and say so, with the way back.
///
/// No dialog: nothing has run, nothing is discarded, and an Undo that puts the
/// row back **in its place** is a better answer to a mis-tap than a modal
/// asking about work that does not exist yet.
Future<void> removeQueuedTaskWithUndo(
  BuildContext context,
  TaskQueueController queue,
  String id,
) async {
  final result = await queue.cancelTask(id);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  if (result != CancelResult.cancelledBeforeStart) {
    // It started while the finger was moving. Saying "removed" would be a lie
    // about work that is currently running.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('queueRemoveRaced'),
          content: Text(
            result == CancelResult.stoppingRunning
                ? 'It had already started — stopping it now.'
                : 'That request is no longer waiting.',
          ),
        ),
      );
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const ValueKey('queueRemoved'),
        content: const Text(
          'Removed from the queue · nothing downloaded was deleted',
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => queue.restoreQueuedTask(id),
        ),
      ),
    );
}

String formatBytesForQueue(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).round()} MB';
  return '${(bytes / 1024).round()} KB';
}

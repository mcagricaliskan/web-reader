import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/capture_job.dart';
import '../providers.dart';
import '../queue/task_queue.dart';
import '../storage/database.dart';
import '../ui/palette.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';
import 'capture_queue_ui.dart';
import 'library_screen.dart' show formatRelative;

/// Everything the app is doing on the user's behalf, grouped by what the user
/// can do about it: Running (stop it), Queued (drop it), Failed (retry it),
/// Completed (nothing — it is history).
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final queue = ref.watch(taskQueueProvider);
    final tasks = ref.watch(queueTasksProvider);
    final job = ref.watch(captureJobProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          // Bulk cancel for a check-all run: drops the queued checks, lets
          // the in-flight one finish (M15's cancel semantic).
          if ((tasks.value ?? const <QueueTask>[]).any(
            (t) =>
                t.state == QueueTaskState.queued.name &&
                t.taskType == QueueTaskType.seriesCheck.name,
          ))
            TextButton(
              onPressed: () => queue.cancelQueuedChecks(),
              child: const Text('Cancel queued checks'),
            ),
          TextButton(
            onPressed: () => queue.clearHistory(),
            child: const Text('Clear history'),
          ),
        ],
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Activity error: $e')),
        data: (list) {
          final queuedAll = _of(list, QueueTaskState.queued);
          // Two different kinds of "queued": captures that are waiting for
          // the user to press Start, and checks/cleanup that will drain on
          // their own. Showing them together makes the first look stuck.
          final waitingToStart = [
            for (final t in queuedAll)
              if (taskWaitsForExplicitStart(queueTaskTypeFromName(t.taskType)))
                t,
          ];
          final autoQueued = [
            for (final t in queuedAll)
              if (!taskWaitsForExplicitStart(queueTaskTypeFromName(t.taskType)))
                t,
          ];

          final groups = <(String, String, List<QueueTask>)>[
            ('RUNNING', 'active', _of(list, QueueTaskState.running)),
            ('QUEUED', 'starting on their own', autoQueued),
            ('FAILED', 'needs you', _of(list, QueueTaskState.failed)),
            (
              'COMPLETED',
              'last ${queue.historyLimit} kept',
              [
                ..._of(list, QueueTaskState.completed),
                ..._of(list, QueueTaskState.cancelled),
              ],
            ),
          ];

          if (list.isEmpty) {
            return const _NothingHappening();
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ListenableBuilder(
                listenable: queue,
                builder: (context, _) => queue.resumeOffered
                    ? _ResumeOffer(queue: queue)
                    : const SizedBox.shrink(),
              ),
              // A capture started from the Browser has no pending row to
              // show — it was never queued (D58) — so it is presented from
              // the job itself, as what it is: an active direct capture.
              ListenableBuilder(
                listenable: Listenable.merge([queue, job]),
                builder: (context, _) =>
                    job.hasActiveRun && queue.runningTaskId == null
                    ? _DirectCaptureRow(job: job, queue: queue)
                    : const SizedBox.shrink(),
              ),
              _BatchSummary(tasks: list),
              if (waitingToStart.isNotEmpty) ...[
                SectionLabel(
                  'WAITING TO START',
                  trailing: Text(
                    '${waitingToStart.length} capture'
                    '${waitingToStart.length == 1 ? '' : 's'}',
                    style: monoStyle(color: palette.inkFaint),
                  ),
                ),
                _QueueControls(count: waitingToStart.length),
                for (final (i, task) in waitingToStart.indexed)
                  _QueuedCaptureRow(
                    task: task,
                    queue: queue,
                    position: i + 1,
                    total: waitingToStart.length,
                  ),
              ],
              for (final (label, note, group) in groups)
                if (group.isNotEmpty) ...[
                  SectionLabel(
                    label,
                    trailing: Text(
                      '${group.length} $note',
                      style: monoStyle(color: palette.inkFaint),
                    ),
                  ),
                  for (final task in group)
                    _TaskRow(task: task, queue: queue, job: job),
                ],
            ],
          );
        },
      ),
    );
  }

  static List<QueueTask> _of(List<QueueTask> all, QueueTaskState state) =>
      all.where((t) => t.state == state.name).toList();
}

/// Queued work is offered after a restart, never resumed on its own (Q24).
class _ResumeOffer extends StatelessWidget {
  const _ResumeOffer({required this.queue});

  final TaskQueueController queue;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Work was waiting when the app closed',
            style: TextStyle(
              fontSize: 13,
              fontVariations: wght(600),
              fontWeight: FontWeight.w600,
              color: palette.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Nothing has run on its own. Start it when you are ready.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: palette.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: queue.resumeQueue,
                child: const Text('Resume queue'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: queue.clearHistory,
                child: const Text('Clear history'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The capture the user started from the Browser, while it runs.
///
/// Classified as a **direct** capture, never as a queued task: it holds no
/// place in the queue, releases nothing behind it, and the pending rows below
/// it are untouched by how it ends (D58).
class _DirectCaptureRow extends ConsumerWidget {
  const _DirectCaptureRow({required this.job, required this.queue});

  final CaptureJobController job;
  final TaskQueueController queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final p = job.progress;
    final browserRequired = job.pauseReason == kPauseBrowserHidden;
    return Container(
      key: const ValueKey('directCaptureRow'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: palette.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.download_for_offline,
                size: 20,
                color: palette.onPrimaryContainer,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  job.origin == CaptureOrigin.direct
                      ? 'Capturing now · started from the Browser'
                      : 'Capturing now',
                  style: TextStyle(
                    fontSize: 13,
                    fontVariations: wght(600),
                    fontWeight: FontWeight.w600,
                    color: palette.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            browserRequired
                ? 'paused — Browser required'
                : '${p.state.label} · ${job.progressSummary}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: palette.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.icon(
                key: const ValueKey('directCaptureOpenBrowser'),
                onPressed: () {
                  ref.read(shellTabRequestProvider).value = 1;
                  Navigator.of(context).maybePop();
                },
                icon: const Icon(Icons.open_in_browser, size: 18),
                label: const Text('Open Browser'),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('directCaptureStop'),
                onPressed: job.stop,
                child: const Text('Stop'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.task, required this.queue, this.job});

  final QueueTask task;
  final TaskQueueController queue;
  final CaptureJobController? job;

  /// A running capture that is holding for the Browser is not "downloading" —
  /// it needs the user, and says so with the way back.
  bool get _browserRequired =>
      task.state == QueueTaskState.running.name &&
      job != null &&
      job!.pauseReason == kPauseBrowserHidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final state = queueTaskStateFromName(task.state);
    final type = queueTaskTypeFromName(task.taskType);
    if (_browserRequired) return _browserRequiredRow(context, ref);
    final (icon, color) = switch (state) {
      QueueTaskState.running =>
        type == QueueTaskType.removeOfflineFiles
            ? (Icons.delete_sweep, palette.inkMuted)
            : (Icons.downloading, palette.primary),
      QueueTaskState.queued => (Icons.schedule, palette.inkMuted),
      QueueTaskState.failed => (
        type == QueueTaskType.seriesCheck ||
                type == QueueTaskType.checkAllSeries
            ? Icons.sync_problem
            : Icons.error,
        palette.danger,
      ),
      QueueTaskState.cancelled => (Icons.do_not_disturb_on, palette.inkFaint),
      QueueTaskState.completed => (
        switch (type) {
          QueueTaskType.seriesCheck ||
          QueueTaskType.checkAllSeries => Icons.update,
          QueueTaskType.removeOfflineFiles => Icons.cleaning_services,
          _ => Icons.download_for_offline,
        },
        palette.primary,
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(type, task),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontVariations: wght(500),
                    fontWeight: FontWeight.w500,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle(state, task),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          for (final control in _controls(state))
            IconButton(
              tooltip: control.$2,
              icon: Icon(control.$1, size: 20),
              color: palette.inkMuted,
              onPressed: control.$3,
            ),
        ],
      ),
    );
  }

  String _title(QueueTaskType type, QueueTask task) => switch (type) {
    QueueTaskType.chapterCapture => 'Capture · ${task.startUrl ?? 'chapter'}',
    // An until-end run's chapterLimit is the internal safety bound, not a
    // count the user chose — say what they asked for.
    QueueTaskType.multiChapterCapture when task.rangeMode == 'untilEnd' =>
      'Capture · until the end',
    QueueTaskType.multiChapterCapture =>
      'Capture · ${task.chapterLimit ?? '?'} chapters',
    QueueTaskType.seriesCheck => 'Check for updates',
    QueueTaskType.checkAllSeries => 'Check all series',
    QueueTaskType.removeOfflineFiles => 'Removing offline files',
  };

  /// The design's "paused — Browser required" row: grey, no progress bar,
  /// and one action that actually solves it.
  Widget _browserRequiredRow(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.public, size: 21, color: palette.inkMuted),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(queueTaskTypeFromName(task.taskType), task),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontVariations: wght(500),
                    fontWeight: FontWeight.w500,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'paused — Browser required',
                  style: TextStyle(fontSize: 12, color: palette.inkMuted),
                ),
                if (job != null && job!.progressSummary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    job!.progressSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(size: 11, color: palette.inkFaint),
                  ),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    ref.read(shellTabRequestProvider).value = 1;
                    Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.open_in_browser, size: 18),
                  label: const Text('Open Browser to resume'),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Stop',
            icon: const Icon(Icons.close, size: 20),
            color: palette.inkMuted,
            onPressed: () => queue.cancelTask(task.id),
          ),
        ],
      ),
    );
  }

  String _subtitle(QueueTaskState state, QueueTask task) {
    final when = switch (state) {
      QueueTaskState.queued => 'queued ${formatRelative(task.queuedAt)}',
      QueueTaskState.running => 'started ${formatRelative(task.startedAt)}',
      _ => formatRelative(task.finishedAt ?? task.queuedAt),
    };
    final detail = task.lastError ?? task.outcome;
    // Where the run came from is part of reading its history: a direct
    // capture never waited in the queue, so "queued 2h ago" would be a lie.
    final source = isDirectOriginTask(task)
        ? 'started from the Browser · '
        : '';
    return detail == null ? '$source$when' : '$source$detail · $when';
  }

  List<(IconData, String, VoidCallback)> _controls(QueueTaskState state) =>
      switch (state) {
        QueueTaskState.running => [
          (Icons.close, 'Cancel', () => queue.cancelTask(task.id)),
        ],
        QueueTaskState.queued => [
          (Icons.close, 'Remove', () => queue.cancelTask(task.id)),
        ],
        QueueTaskState.failed || QueueTaskState.cancelled => [
          (Icons.refresh, 'Retry', () => queue.retryTask(task.id)),
        ],
        QueueTaskState.completed => const [],
      };
}

/// The counts a batch is actually made of.
///
/// Counts, never a percentage: an until-end run does not know how many
/// chapters it will find, and a progress bar that invents a denominator is a
/// lie the user cannot check.
class _BatchSummary extends StatelessWidget {
  const _BatchSummary({required this.tasks});

  final List<QueueTask> tasks;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final s = QueueSummary.of(tasks);
    if (s.remaining == 0 && s.failed == 0) return const SizedBox.shrink();
    final facts = <(String, int)>[
      ('waiting', s.queuedCaptures),
      ('queued', s.queuedOther),
      ('running', s.running),
      ('done', s.completed),
      ('failed', s.failed),
      ('skipped', s.cancelled),
    ].where((f) => f.$2 > 0).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          for (final (label, count) in facts)
            Text(
              '$count $label',
              style: monoStyle(size: 12, color: palette.inkStrong),
            ),
        ],
      ),
    );
  }
}

/// Start-all / clear-all for the waiting captures.
class _QueueControls extends ConsumerWidget {
  const _QueueControls({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
    child: Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('startAllQueued'),
            onPressed: () => confirmAndStartCaptures(context, ref),
            icon: const Icon(Icons.play_arrow, size: 19),
            label: Text('Start $count capture${count == 1 ? '' : 's'}'),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          key: const ValueKey('clearQueued'),
          onPressed: () => _confirmClear(context, ref),
          child: const Text('Clear'),
        ),
      ],
    ),
  );

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear the capture queue?'),
        content: const Text(
          'The waiting capture requests are dropped. Nothing already saved '
          'is affected — no chapter, no file and no reading history is '
          'touched.',
          style: TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep them'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear queue'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final removed = await ref.read(taskQueueProvider).clearQueuedCaptures();
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          '$removed capture request${removed == 1 ? '' : 's'} removed · '
          'nothing downloaded was deleted',
        ),
      ),
    );
  }
}

/// A capture that has not started: its place in line, what it will do, and
/// the three things that can be done to it — move, start, remove.
class _QueuedCaptureRow extends ConsumerWidget {
  const _QueuedCaptureRow({
    required this.task,
    required this.queue,
    required this.position,
    required this.total,
  });

  final QueueTask task;
  final TaskQueueController queue;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final url = task.startUrl?.trim() ?? '';
    final uri = Uri.tryParse(url);
    final knowsSource = url.isNotEmpty && (uri?.host.isNotEmpty ?? false);
    final mode = switch (task.rangeMode) {
      'untilEnd' => 'until the end',
      'currentChapter' => 'this chapter',
      _ =>
        '${task.chapterLimit ?? 1} chapter'
            '${(task.chapterLimit ?? 1) == 1 ? '' : 's'}',
    };
    // `replaceAll` is what a re-fetch/re-download enqueues; anything else is
    // new material.
    final isRedownload = task.duplicatePolicy == 'replaceAll';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$position',
              textAlign: TextAlign.center,
              style: monoStyle(size: 12, color: palette.inkFaint),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  knowsSource ? (uri?.pathSegments.lastOrNull ?? url) : url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontVariations: wght(500),
                    fontWeight: FontWeight.w500,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${isRedownload ? 'Re-download' : 'Capture'} · $mode'
                  '${knowsSource ? ' · ${uri!.host}' : ''}'
                  ' · added ${formatRelative(task.queuedAt)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: palette.inkMuted,
                  ),
                ),
                if (!knowsSource) ...[
                  const SizedBox(height: 3),
                  Text(
                    'No source page — this cannot be captured automatically',
                    style: TextStyle(fontSize: 11.5, color: palette.warn),
                  ),
                ],
              ],
            ),
          ),
          _MiniAction(
            icon: Icons.arrow_upward,
            tooltip: 'Move up',
            onPressed: position == 1
                ? null
                : () => queue.moveQueued(task.id, -1),
          ),
          _MiniAction(
            icon: Icons.arrow_downward,
            tooltip: 'Move down',
            onPressed: position == total
                ? null
                : () => queue.moveQueued(task.id, 1),
          ),
          _MiniAction(
            icon: Icons.play_arrow,
            tooltip: 'Start this one',
            onPressed: !knowsSource ? null : () => _startOne(context, ref),
          ),
          _MiniAction(
            icon: Icons.close,
            tooltip: 'Remove from queue',
            onPressed: () => queue.cancelTask(task.id),
          ),
        ],
      ),
    );
  }

  Future<void> _startOne(BuildContext context, WidgetRef ref) async {
    // Starting one is still starting the Browser, so it earns the same
    // confirmation as Start All — just aimed at this row.
    await queue.moveQueuedToFront(task.id);
    if (!context.mounted) return;
    await confirmAndStartCaptures(context, ref);
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      color: palette.inkMuted,
      disabledColor: palette.inkDisabled,
      onPressed: onPressed,
    );
  }
}

class _NothingHappening extends StatelessWidget {
  const _NothingHappening();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 30, color: palette.inkFaint),
            const SizedBox(height: 10),
            Text(
              'Nothing running',
              style: TextStyle(
                fontSize: 16,
                fontVariations: wght(600),
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Captures and update checks you start show up here, with what '
              'happened and how to retry it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: palette.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

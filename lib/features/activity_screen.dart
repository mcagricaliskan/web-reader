import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/capture_job.dart';
import '../providers.dart';
import '../queue/task_queue.dart';
import '../storage/database.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';
import 'library_screen.dart' show formatRelative;

/// Everything the app is doing on the user's behalf, grouped by what the user
/// can do about it: Running (stop it), Queued (drop it), Failed (retry it),
/// Completed (nothing — it is history).
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          final groups = <(String, String, List<QueueTask>)>[
            ('RUNNING', 'active', _of(list, QueueTaskState.running)),
            ('QUEUED', 'waiting', _of(list, QueueTaskState.queued)),
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
              for (final (label, note, group) in groups)
                if (group.isNotEmpty) ...[
                  SectionLabel(
                    label,
                    trailing: Text(
                      '${group.length} $note',
                      style: monoStyle(color: const Color(0xFFA39D93)),
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF1F4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFD2E2E8)),
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
            color: const Color(0xFF133845),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Nothing has run on its own. Start it when you are ready.',
          style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF3F5A63)),
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
    final state = queueTaskStateFromName(task.state);
    final type = queueTaskTypeFromName(task.taskType);
    if (_browserRequired) return _browserRequiredRow(context, ref);
    final (icon, color) = switch (state) {
      QueueTaskState.running =>
        type == QueueTaskType.removeOfflineFiles
            ? (Icons.delete_sweep, const Color(0xFF5F5B54))
            : (Icons.downloading, const Color(0xFF35606F)),
      QueueTaskState.queued => (Icons.schedule, const Color(0xFF5F5B54)),
      QueueTaskState.failed => (
        type == QueueTaskType.seriesCheck ||
                type == QueueTaskType.checkAllSeries
            ? Icons.sync_problem
            : Icons.error,
        const Color(0xFF8E3B31),
      ),
      QueueTaskState.cancelled => (
        Icons.do_not_disturb_on,
        const Color(0xFF8C877E),
      ),
      QueueTaskState.completed => (
        switch (type) {
          QueueTaskType.seriesCheck ||
          QueueTaskType.checkAllSeries => Icons.update,
          QueueTaskType.removeOfflineFiles => Icons.cleaning_services,
          _ => Icons.download_for_offline,
        },
        const Color(0xFF35606F),
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
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle(state, task),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF5F5B54),
                  ),
                ),
              ],
            ),
          ),
          for (final control in _controls(state))
            IconButton(
              tooltip: control.$2,
              icon: Icon(control.$1, size: 20),
              color: const Color(0xFF5F5B54),
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
  Widget _browserRequiredRow(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.public, size: 21, color: Color(0xFF5F5B54)),
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
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'paused — Browser required',
                style: TextStyle(fontSize: 12, color: Color(0xFF5F5B54)),
              ),
              if (job != null && job!.progressSummary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  job!.progressSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(size: 11, color: const Color(0xFF8C877E)),
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
          color: const Color(0xFF5F5B54),
          onPressed: () => queue.cancelTask(task.id),
        ),
      ],
    ),
  );

  String _subtitle(QueueTaskState state, QueueTask task) {
    final when = switch (state) {
      QueueTaskState.queued => 'queued ${formatRelative(task.queuedAt)}',
      QueueTaskState.running => 'started ${formatRelative(task.startedAt)}',
      _ => formatRelative(task.finishedAt ?? task.queuedAt),
    };
    final detail = task.lastError ?? task.outcome;
    return detail == null ? when : '$detail · $when';
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

class _NothingHappening extends StatelessWidget {
  const _NothingHappening();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 30, color: Color(0xFF9A948A)),
          const SizedBox(height: 10),
          Text(
            'Nothing running',
            style: TextStyle(
              fontSize: 16,
              fontVariations: wght(600),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Captures and update checks you start show up here, with what '
            'happened and how to retry it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: Color(0xFF5F5B54),
            ),
          ),
        ],
      ),
    ),
  );
}

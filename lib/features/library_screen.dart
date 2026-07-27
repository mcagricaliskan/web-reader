import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../capture/capture_state.dart';
import '../library/library_sort.dart';
import '../library/series_repository.dart';
import '../providers.dart';
import '../queue/task_queue.dart';
import '../reading/reading_position.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';
import 'continue_entry.dart';
import 'series_detail_screen.dart' show sortChaptersForReading;
import '../storage/database.dart';

/// The library, grouped by series.
///
/// One row per series, not one row per chapter: chapters of the same series
/// belong together, and two series on the same host stay apart.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(seriesGroupsProvider);
    final resumable = ref.watch(resumableJobProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _LibraryHeader(),
            Expanded(
              child: groups.when(
                loading: () => const _LibrarySkeleton(),
                error: (e, _) => _LibraryError(error: '$e'),
                data: (list) {
                  final continueEntries =
                      ref.watch(continueReadingProvider).value ?? const [];
                  final resumeJob = resumable.value;

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      const _ActivityStrip(),
                      if (resumeJob != null) _ResumeCard(job: resumeJob),
                      const SectionLabel(
                        'CONTINUE READING',
                        padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                      ),
                      _ContinueRow(entries: continueEntries, allSeries: list),
                      SectionLabel(
                        'ALL SERIES · ${list.length}',
                        trailing: const _SortControl(),
                      ),
                      if (list.isEmpty)
                        const _EmptyLibrary()
                      else ...[
                        const Divider(),
                        for (final group in list) ...[
                          _SeriesRow(group: group),
                          const Divider(),
                        ],
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryHeader extends ConsumerWidget {
  const _LibraryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text('Library', style: serifStyle())),
        IconButton(
          tooltip: 'Check all series',
          icon: const Icon(Icons.sync, size: 22),
          color: const Color(0xFF5F5B54),
          onPressed: () => _checkAll(context, ref),
        ),
        IconButton(
          tooltip: 'Archived',
          icon: const Icon(Icons.inventory_2, size: 22),
          color: const Color(0xFF5F5B54),
          onPressed: () => context.push('/archived'),
        ),
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings, size: 22),
          color: const Color(0xFF5F5B54),
          onPressed: () => context.push('/settings'),
        ),
      ],
    ),
  );

  Future<void> _checkAll(BuildContext context, WidgetRef ref) async {
    final ids = await ref.read(taskQueueProvider).enqueueCheckAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ids.isEmpty
              ? 'Nothing to check yet — capture a series first.'
              : 'Checking ${ids.length} series, one at a time — metadata '
                    'only. Progress is in Activity.',
        ),
      ),
    );
  }
}

/// A live band above the library when the queue has anything to say. It is a
/// summary, not a control surface — the controls live on the activity screen.
class _ActivityStrip extends ConsumerWidget {
  const _ActivityStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(queueTasksProvider).value ?? const <QueueTask>[];
    final running = tasks
        .where((t) => t.state == QueueTaskState.running.name)
        .toList();
    final queued = tasks
        .where((t) => t.state == QueueTaskState.queued.name)
        .length;
    final failed = tasks
        .where((t) => t.state == QueueTaskState.failed.name)
        .length;
    final controller = ref.watch(captureJobProvider);
    final active = running.firstOrNull;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Visible when the queue has anything to say — or when a capture
        // (queued or direct) is holding for the Browser: that banner must
        // reach the user wherever they are.
        final waiting =
            controller.progress.state == CaptureState.waitingForBrowser;
        if (running.isEmpty && queued == 0 && failed == 0 && !waiting) {
          return const SizedBox.shrink();
        }
        return _stripBody(context, controller.progress, active, queued, failed);
      },
    );
  }

  Widget _stripBody(
    BuildContext context,
    CaptureProgress job,
    QueueTask? active,
    int queued,
    int failed,
  ) {
    final phase = active == null ? 'QUEUED' : job.state.name.toUpperCase();
    final pct = job.detectedImages > 0
        ? (job.storedImages / job.detectedImages).clamp(0.0, 1.0)
        : 0.0;

    // A capture holding on a hidden WebView needs the user, not a percent:
    // the strip becomes the banner, and its action opens the Browser.
    if (job.state == CaptureState.waitingForBrowser) {
      return Consumer(
        builder: (context, ref, _) => Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8EEDA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8D5B2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.pause_circle,
                size: 22,
                color: Color(0xFF8A5A1F),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Capture is waiting — open the Browser to continue.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF4A2F08),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => ref.read(shellTabRequestProvider).value = 1,
                child: const Text('Open Browser'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: const Color(0xFFEAF1F4),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/activity'),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 13, 10, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.downloading,
                      size: 22,
                      color: Color(0xFF35606F),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            phase,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: monoStyle(color: const Color(0xFF35606F)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            active == null
                                ? '$queued waiting'
                                : (job.chapterTitle.isEmpty
                                      ? 'Working'
                                      : job.chapterTitle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontVariations: wght(500),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(pct * 100).round()}%',
                          style: monoStyle(
                            size: 12,
                            color: const Color(0xFF133845),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$queued queued · $failed failed',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF5F5B54),
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Color(0xFF7E8B90),
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: pct,
                minHeight: 3,
                backgroundColor: const Color(0xFFD2E2E8),
                color: const Color(0xFF35606F),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortControl extends ConsumerWidget {
  const _SortControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(librarySortProvider).value ?? LibrarySort.lastRead;
    final label = sort == LibrarySort.name ? 'Name' : 'Last read';

    return Material(
      color: const Color(0xFFF3F1ED),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: Color(0xFFE7E3DC)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setLibrarySort(
          ref,
          sort == LibrarySort.name ? LibrarySort.lastRead : LibrarySort.name,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_vert, size: 16, color: Color(0xFF3E3A34)),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF3E3A34)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling continue cards. Empty states say *why* they are
/// empty — "nothing captured", "nothing opened yet" and "you finished
/// everything" are three different situations and only one is a problem.
class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.entries, required this.allSeries});

  final List<ContinueEntry> entries;
  final List<SeriesGroup> allSeries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      final anyReadable = allSeries.any((g) => g.offlineCount > 0);
      final anyOpened = allSeries.any((g) => g.item.lastReadAt != null);
      final (title, body) = !anyReadable
          ? (
              'Nothing readable yet',
              'Captures that failed or lost their files cannot be read. '
                  'Capture a chapter to start.',
            )
          : anyOpened
          ? (
              "You're up to date",
              'You have finished every chapter you have saved. Capture more '
                  'to keep going.',
            )
          : (
              'Nothing opened yet',
              'Chapters you start show up here with your exact position.',
            );

      return Container(
        margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3EF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDFDAD2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontVariations: wght(600),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF5F5B54),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 134,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _ContinueCard(entry: entries[i]),
      ),
    );
  }
}

/// One Continue card: which chapter, how far in, and how that reads as panels.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry});

  final ContinueEntry entry;

  @override
  Widget build(BuildContext context) {
    final pct = (entry.progress * 100).clamp(0, 100).round();

    return SizedBox(
      key: ValueKey('continueCard-${entry.chapter.id}'),
      width: 214,
      child: Material(
        color: const Color(0xFFF5F3EF),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/reader/${entry.chapter.id}'),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE7E3DC)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MonogramTile(
                      id: entry.chapter.libraryItemId,
                      title: entry.displayName,
                      size: 34,
                      radius: 10,
                      fontSize: 15,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              fontVariations: wght(600),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            entry.chapterLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: monoStyle(color: const Color(0xFF5F5B54)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: entry.progress.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: const Color(0xFFE1DDD5),
                          color: const Color(0xFF35606F),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '$pct%',
                      style: monoStyle(color: const Color(0xFF35606F)),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  entry.isPartialCapture
                      ? 'partial capture'
                      : (pct == 0 ? 'not started' : 'offline'),
                  style: TextStyle(
                    fontSize: 12,
                    color: entry.isPartialCapture
                        ? const Color(0xFF8A5A1F)
                        : const Color(0xFF5F5B54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One series row: monogram, name, update-check chip, host, counts, and — only
/// when there is one — a warning line.
class _SeriesRow extends ConsumerWidget {
  const _SeriesRow({required this.group});

  final SeriesGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checker = ref.watch(updateCheckerProvider);
    return ListenableBuilder(
      listenable: checker,
      builder: (context, _) => _row(
        context,
        ref,
        checking: checker.isRunning && checker.activeItemId == group.item.id,
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, {required bool checking}) {
    final chip = checkLook(
      checking: checking,
      failed: group.lastCheckFailed,
      checkedAt: group.lastCheckedAt,
      newCount: group.knownRemoteCount,
      checkedLabel: formatRelative(group.lastCheckedAt),
    );
    final warning = group.warningLine;

    return Stack(
      key: ValueKey('seriesRow-${group.item.id}'),
      children: [
        InkWell(
          onTap: () => context.push('/series/${group.item.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 48, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonogramTile(id: group.item.id, title: group.displayName),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              group.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.3,
                                fontVariations: wght(600),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            icon: chip.icon,
                            label: chip.label,
                            bg: chip.bg,
                            fg: chip.fg,
                            border: chip.border,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(group.item.host, style: monoStyle()),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.download_for_offline,
                            size: 15,
                            color: Color(0xFF35606F),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${group.offlineCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF35606F),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.circle,
                            size: 9,
                            color: Color(0xFF35606F),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${group.unreadOfflineCount} unread',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5F5B54),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              group.item.lastReadAt == null
                                  ? 'never opened'
                                  : formatRelative(group.item.lastReadAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFA39D93),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (warning != null) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(warning.icon, size: 15, color: warning.color),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                warning.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: warning.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 4,
          child: Center(
            child: IconButton(
              tooltip: 'Series actions',
              icon: const Icon(Icons.more_vert, size: 20),
              color: const Color(0xFF8C877E),
              onPressed: () => showSeriesMenu(context, ref, group),
            ),
          ),
        ),
      ],
    );
  }
}

/// The per-series overflow sheet. Check and rules are wired; rename lives on
/// the series detail screen, and archive arrives with the lifecycle column.
Future<void> showSeriesMenu(
  BuildContext context,
  WidgetRef ref,
  SeriesGroup group,
) {
  // Read once, before the sheet: the sheet outlives this build's `ref`.
  final queue = ref.read(taskQueueProvider);

  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Text(
              group.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: serifStyle(size: 20),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Check for updates'),
            subtitle: const Text('Metadata only'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              // The M8 per-series check, on the queue (M14): runs now if the
              // browser is free, waits its turn otherwise. State lands on the
              // row chip either way.
              queue.enqueueSeriesCheck(group.item.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Archive'),
            subtitle: const Text('Hidden from library · reversible'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              confirmArchiveSeries(context, ref, group);
            },
          ),
          ListTile(
            leading: const Icon(Icons.ads_click),
            title: const Text('Element rules'),
            subtitle: Text(group.item.host),
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push('/rules');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// The archive confirm dialog (M16, Q25). States exactly what happens: the
/// series leaves the library and stops being checked; pending queue tasks are
/// cancelled and the dialog says how many; nothing on disk is touched.
Future<bool> confirmArchiveSeries(
  BuildContext context,
  WidgetRef ref,
  SeriesGroup group,
) async {
  final queue = ref.read(taskQueueProvider);
  final repo = ref.read(seriesRepositoryProvider);
  final pendingCount = (await queue.pendingTasksForSeries(
    group.item.id,
  )).length;
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.inventory_2, size: 26, color: Color(0xFF35606F)),
      title: const Text('Archive this series?'),
      content: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 13,
            height: 1.55,
            color: Color(0xFF5F5B54),
          ),
          children: [
            const TextSpan(
              text:
                  'It leaves the library and stops being checked for '
                  'updates. ',
            ),
            if (pendingCount > 0)
              TextSpan(
                text:
                    'This cancels $pendingCount pending '
                    'task${pendingCount == 1 ? '' : 's'}. ',
                style: const TextStyle(
                  color: Color(0xFF4A2F08),
                  backgroundColor: Color(0xFFF8EEDA),
                ),
              ),
            const TextSpan(
              text:
                  'Downloads stay on the device and you can restore it any '
                  'time.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Archive'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  await queue.cancelTasksForSeries(group.item.id);
  await repo.archive(group.item.id);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Archived "${group.displayName}".')));
  }
  return true;
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F3EF),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFDFDAD2)),
    ),
    child: Column(
      children: [
        const Icon(Icons.travel_explore, size: 30, color: Color(0xFF9A948A)),
        const SizedBox(height: 10),
        Text(
          'Nothing saved yet',
          style: TextStyle(
            fontSize: 16,
            fontVariations: wght(600),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Open a chapter in the browser and tap Capture. The app scrolls the '
          'page, saves every panel, and the chapter shows up here — readable '
          'offline.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.55,
            color: Color(0xFF5F5B54),
          ),
        ),
      ],
    ),
  );
}

class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    children: [
      for (final w in const [0.62, 0.78, 0.54, 0.70, 0.58, 0.74])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFECE7),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FractionallySizedBox(
                      widthFactor: w,
                      child: Container(
                        height: 12,
                        color: const Color(0xFFEFECE7),
                      ),
                    ),
                    const SizedBox(height: 7),
                    FractionallySizedBox(
                      widthFactor: w * 0.6,
                      child: Container(
                        height: 10,
                        color: const Color(0xFFF3F1ED),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF7DDD8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEBC4BC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.sd_card_alert, size: 26, color: Color(0xFF8E3B31)),
            const SizedBox(height: 8),
            Text(
              "Can't read the local library",
              style: TextStyle(
                fontSize: 17,
                fontVariations: wght(600),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A140E),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'The library database did not open. Your downloaded chapters '
              'are still on the device — nothing was deleted.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF5F3730),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: monoStyle(color: const Color(0xFF7A4A42)),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ResumeCard extends ConsumerWidget {
  const _ResumeCard({required this.job});
  final CaptureJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(captureJobProvider);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8EEDA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D5B2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unfinished capture',
            style: TextStyle(
              fontSize: 13,
              fontVariations: wght(600),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4A2F08),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${job.completedChapters} of ${job.requestedChapters} chapters '
            'captured before the app closed.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF6B4A15),
            ),
          ),
          Text(
            job.currentUrl ?? job.startUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: monoStyle(color: const Color(0xFF7A6034)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: () => controller.resumeJob(job),
                child: const Text('Resume'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => controller.discardJob(job),
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The one warning a series row is allowed to show, most serious first.
class SeriesWarning {
  const SeriesWarning(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
}

/// A series plus the numbers its library row shows.
class SeriesGroup {
  const SeriesGroup({required this.item, required this.chapters});

  final LibraryItem item;
  final List<Chapter> chapters;

  String get displayName => displayNameFor(item);

  /// Chapters a capture has at least been attempted for. Discovered-but-not-
  /// captured chapters are counted separately — "12 chapters" must not
  /// quietly include ones the device does not hold.
  List<Chapter> get capturedChapters =>
      chapters.where((c) => c.captureStatus != 'knownRemote').toList();

  /// Known to exist on the source, not yet captured (from an update check).
  List<Chapter> get knownRemoteChapters =>
      chapters.where((c) => c.captureStatus == 'knownRemote').toList();

  int get chapterCount => capturedChapters.length;
  int get knownRemoteCount => knownRemoteChapters.length;

  /// The newest chapter the source is known to have, captured or not.
  String? get latestKnownLabel {
    final all = sortChaptersForReading(chapters);
    if (all.isEmpty) return null;
    final last = all.last;
    final label = last.chapterLabel;
    return (label != null && label.isNotEmpty) ? label : last.title;
  }

  int get offlineCount => chapters
      .where((c) => c.contentPath != null && c.captureStatus != 'failed')
      .length;

  /// Locally readable chapters the user has not finished. This is the number
  /// a reader actually wants on the shelf: "how much is waiting for me here".
  int get unreadOfflineCount => chapters
      .where(
        (c) =>
            c.contentPath != null &&
            (c.captureStatus == 'complete' || c.captureStatus == 'partial') &&
            c.readStatus != ReadStatus.completed.name,
      )
      .length;

  int get partialChapters =>
      chapters.where((c) => c.captureStatus == 'partial').length;
  int get failedChapters =>
      chapters.where((c) => c.captureStatus == 'failed').length;
  int get problemChapters => partialChapters + failedChapters;

  /// One line, worst first. Nothing wrong means no line at all — a row without
  /// a warning is the normal case and must not carry an empty slot.
  SeriesWarning? get warningLine {
    if (failedChapters > 0) {
      return SeriesWarning(
        Icons.error,
        '$failedChapters capture${failedChapters == 1 ? '' : 's'} failed',
        const Color(0xFF8E3B31),
      );
    }
    if (partialChapters > 0) {
      return SeriesWarning(
        Icons.arrow_circle_down,
        '$partialChapters chapter${partialChapters == 1 ? '' : 's'} partial',
        const Color(0xFF8A5A1F),
      );
    }
    return null;
  }

  /// Update-check state for the row. `null` means **never checked** — which
  /// the UI must render as "not checked yet", never as zero new chapters.
  DateTime? get lastCheckedAt => item.lastCheckSuccessAt;
  bool get lastCheckFailed => item.lastCheckError != null;

  DateTime? get lastCapturedAt {
    DateTime? latest = item.lastCapturedAt;
    for (final c in chapters) {
      final at = c.capturedAt;
      if (at == null) continue;
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    return latest;
  }

  /// The most recently captured chapter, which is what a reader coming back is
  /// most likely looking for.
  String? get latestChapterLabel {
    Chapter? newest;
    for (final c in chapters) {
      if (c.capturedAt == null) continue;
      if (newest?.capturedAt == null ||
          c.capturedAt!.isAfter(newest!.capturedAt!)) {
        newest = c;
      }
    }
    newest ??= chapters.isEmpty ? null : chapters.last;
    if (newest == null) return null;
    final label = newest.chapterLabel;
    return (label != null && label.isNotEmpty) ? label : newest.title;
  }
}

String formatRelative(DateTime? t) {
  if (t == null) return 'not captured';
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

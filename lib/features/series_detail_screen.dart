import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../capture/capture_preflight.dart';
import '../library/series_identity.dart';
import '../library/update_checker.dart';
import '../providers.dart';
import '../queue/task_queue.dart';
import '../reading/reading_repository.dart';
import '../storage/database.dart';
import '../storage/manifest.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';
import 'capture_queue_ui.dart';
import 'chapter_actions.dart';
import 'chapter_details_sheet.dart';
import 'cleanup_dialogs.dart';
import 'library_screen.dart'
    show
        SeriesGroup,
        SeriesWarning,
        confirmArchiveSeries,
        formatBytes,
        formatRelative;

/// The chapters of one series, in reading order, each opening the offline
/// reader.
class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({
    super.key,
    required this.seriesId,
    this.startInSelectionMode = false,
  });

  final String seriesId;

  /// Opened from Storage's "Choose chapters to remove" — selection mode
  /// lives HERE, never on the Storage screen itself.
  final bool startInSelectionMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(seriesGroupProvider(seriesId));

    return group.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Series')),
            body: const Center(child: Text('This series is no longer listed.')),
          );
        }
        return _SeriesDetail(
          group: data,
          startInSelectionMode: startInSelectionMode,
        );
      },
    );
  }
}

class _SeriesDetail extends ConsumerStatefulWidget {
  const _SeriesDetail({required this.group, this.startInSelectionMode = false});

  final SeriesGroup group;
  final bool startInSelectionMode;

  @override
  ConsumerState<_SeriesDetail> createState() => _SeriesDetailState();
}

class _SeriesDetailState extends ConsumerState<_SeriesDetail> {
  /// Selected chapter ids while in selection mode; null when not selecting.
  Set<String>? _selection;

  /// chapterId → why it cannot be removed right now. Computed once when
  /// selection mode opens, not per row build (each lookup consults the
  /// reader lock and the running job).
  Map<String, String> _locks = const {};

  SeriesGroup get group => widget.group;
  bool get _selecting => _selection != null;

  @override
  void initState() {
    super.initState();
    if (widget.startInSelectionMode) {
      _selection = <String>{};
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLocks());
    }
  }

  void _enterSelection() {
    setState(() => _selection = <String>{});
    unawaited(_refreshLocks());
  }

  void _exitSelection() => setState(() {
    _selection = null;
    _locks = const {};
  });

  Future<void> _refreshLocks() async {
    final cleanup = ref.read(cleanupProvider);
    final locks = <String, String>{};
    for (final c in group.chapters) {
      if (!cleanup.isRemovable(c)) continue;
      final reason = await cleanup.lockReasonFor(c);
      if (reason != null) locks[c.id] = reason;
    }
    if (mounted) setState(() => _locks = locks);
  }

  void _toggle(String id) => setState(() {
    final sel = _selection!;
    sel.contains(id) ? sel.remove(id) : sel.add(id);
  });

  Future<void> _selectAllOffline(List<Chapter> chapters) async {
    final removable = await _removableOf(chapters);
    if (!mounted) return;
    setState(() => _selection = removable.map((c) => c.id).toSet());
  }

  Future<void> _selectFinished(List<Chapter> chapters) async {
    final removable = await _removableOf(
      chapters.where((c) => c.readStatus == 'completed'),
    );
    if (!mounted) return;
    setState(() => _selection = removable.map((c) => c.id).toSet());
  }

  /// Everything this device does not currently hold — the selection a
  /// re-download batch starts from. Includes chapters whose files the user
  /// removed AND chapters only ever seen on the source (D48).
  void _selectMissing(List<Chapter> chapters) {
    setState(
      () => _selection = {
        for (final c in chapters)
          if (!isReadableOffline(c)) c.id,
      },
    );
  }

  /// Finished chapters whose files are gone: the "I read it, I freed the
  /// space, now I want it back" selection.
  void _selectRemovedFinished(List<Chapter> chapters) {
    setState(
      () => _selection = {
        for (final c in chapters)
          if (!isReadableOffline(c) && c.readStatus == 'completed') c.id,
      },
    );
  }

  /// Queue the selection for re-download, oldest first.
  ///
  /// Nothing starts here: the batch joins the capture queue and waits for an
  /// explicit start like every other capture request (D46).
  Future<void> _confirmQueueSelection(List<Chapter> all) async {
    final ids = _selection!;
    if (ids.isEmpty) return;
    final chosen = all.where((c) => ids.contains(c.id)).toList();
    final capturable = chosen.where(chapterHasCapturableUrl).toList();
    final missing = chosen.where((c) => !chapterHasCapturableUrl(c)).toList();

    // Estimate from what this series has actually cost so far, not from a
    // constant. Null when nothing has been captured yet.
    final known = all.where((c) => c.byteSize > 0).toList();
    final estimate = known.isEmpty
        ? null
        : (known.fold<int>(0, (sum, c) => sum + c.byteSize) ~/ known.length) *
              capturable.length;

    final ok = await showBatchQueueConfirm(
      context: context,
      plan: BatchQueuePlan(
        seriesName: widget.group.displayName,
        capturable: capturable,
        missingSource: missing,
        estimatedBytes: estimate,
      ),
    );
    if (!ok || !mounted) return;

    final result = await ref.read(taskQueueProvider).enqueueChapters(chosen);
    if (!mounted) return;
    _exitSelection();
    showBatchQueuedConfirmation(context, result);
  }

  /// Remove the current selection, with the design's confirmation and an
  /// undo toast. Locked chapters were filtered out of the selection already,
  /// but the service re-checks — the reader may have opened one meanwhile.
  Future<void> _confirmRemoveSelection(List<Chapter> chapters) async {
    final ids = _selection!;
    if (ids.isEmpty) return;
    final chosen = chapters.where((c) => ids.contains(c.id)).toList();
    final bytes = chosen.fold<int>(0, (sum, c) => sum + c.byteSize);
    final n = chosen.length;

    final ok = await showRemovalConfirm(
      context: context,
      summary: RemovalSummary(
        title: 'Remove offline files?',
        body: n == 1
            ? 'This chapter stays in your library — read marks, history and '
                  'source links are kept. It just will not be available '
                  'offline until captured again.'
            : 'These chapters stay in your library — read marks, history and '
                  'source links are kept. They just will not be available '
                  'offline until captured again.',
        facts: [('Chapters', '$n'), ('Space freed', '~${formatBytes(bytes)}')],
      ),
    );
    if (!ok || !mounted) return;

    final result = await ref
        .read(cleanupProvider)
        .removeOffline(chosen.map((c) => c.id).toList());
    if (!mounted) return;
    _exitSelection();
    showCleanupToast(
      context,
      text:
          '${result.removed} chapter${result.removed == 1 ? '' : 's'} removed '
          'offline · ${formatBytes(result.freedBytes)} freed'
          '${result.keptLocked.isEmpty ? '' : ' · ${result.keptLocked.length} kept (in use)'}',
      undo: result.canUndo ? result.undo.undo : null,
    );
  }

  /// Remove every offline chapter of this series, through the queue: a
  /// hundreds-of-chapters sweep deserves a visible task, not a frozen sheet.
  Future<void> _confirmRemoveSeries() async {
    final cleanup = ref.read(cleanupProvider);
    final offline = group.chapters.where(cleanup.isRemovable).toList();
    if (offline.isEmpty) return;
    final removable = await _removableOf(offline);
    final locked = offline.length - removable.length;
    final bytes = removable.fold<int>(0, (sum, c) => sum + c.byteSize);
    if (!mounted) return;

    final ok = await showRemovalConfirm(
      context: context,
      summary: RemovalSummary(
        title: 'Remove offline files?',
        body:
            'Every stored chapter of this series will no longer be available '
            'offline. The series, read marks and history stay in your '
            'library — you can capture it again later.',
        facts: [
          ('Chapters', '${removable.length}'),
          ('Space freed', '~${formatBytes(bytes)}'),
        ],
        lockNote: locked == 0
            ? null
            : '$locked chapter${locked == 1 ? ' is' : 's are'} open or being '
                  'captured right now — they will be kept.',
      ),
    );
    if (!ok || !mounted) return;

    // Small series: inline with undo. Large: a queue task with progress.
    if (removable.length <= 5) {
      final result = await cleanup.removeOffline(
        removable.map((c) => c.id).toList(),
      );
      if (!mounted) return;
      showCleanupToast(
        context,
        text:
            '${result.removed} chapter${result.removed == 1 ? '' : 's'} '
            'removed offline · ${formatBytes(result.freedBytes)} freed',
        undo: result.canUndo ? result.undo.undo : null,
      );
      return;
    }
    await ref
        .read(taskQueueProvider)
        .enqueueCleanup(libraryItemId: group.item.id);
    if (!mounted) return;
    showCleanupToast(
      context,
      text: 'Removing offline files — progress in Activity',
    );
  }

  /// Chapters whose files can actually go: offline, and not in use.
  Future<List<Chapter>> _removableOf(Iterable<Chapter> candidates) async {
    final cleanup = ref.read(cleanupProvider);
    final out = <Chapter>[];
    for (final c in candidates) {
      if (!cleanup.isRemovable(c)) continue;
      if (await cleanup.lockReasonFor(c) != null) continue;
      out.add(c);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final sort =
        ref.watch(chapterSortProvider).value ?? ChapterSort.newestFirst;
    // Reading order drives selection helpers and the reading state; the list
    // itself is presented in the user's chosen direction.
    final readingOrder = sortChaptersForReading(group.capturedChapters);
    final chapters = sortChapters(group.capturedChapters, sort);
    final knownRemote = sortChapters(group.knownRemoteChapters, sort);
    final reading = computeSeriesReadingState(group.chapters);
    final resume = reading.continueChapter;
    final checker = ref.watch(updateCheckerProvider);
    final warning = group.warningLine;
    final bytes = group.chapters.fold<int>(0, (sum, c) => sum + c.byteSize);

    return Scaffold(
      appBar: _selecting
          ? AppBar(
              backgroundColor: const Color(0xFFEAF1F4),
              foregroundColor: const Color(0xFF133845),
              leading: IconButton(
                icon: const Icon(Icons.close, size: 24),
                tooltip: 'Cancel selection',
                onPressed: _exitSelection,
              ),
              title: Text('${_selection!.length} selected'),
              actions: [
                // A menu, not four buttons: the quick-selects outgrew the
                // width of a 320pt app bar the moment re-download joined
                // removal.
                PopupMenuButton<String>(
                  icon: const Icon(Icons.checklist, size: 22),
                  tooltip: 'Select…',
                  onSelected: (choice) => switch (choice) {
                    'offline' => _selectAllOffline(readingOrder),
                    'finished' => _selectFinished(readingOrder),
                    'missing' => _selectMissing(readingOrder),
                    'removedFinished' => _selectRemovedFinished(readingOrder),
                    _ => setState(() => _selection = <String>{}),
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'offline', child: Text('All offline')),
                    PopupMenuItem(value: 'finished', child: Text('Finished')),
                    PopupMenuItem(
                      value: 'missing',
                      child: Text('Not downloaded'),
                    ),
                    PopupMenuItem(
                      value: 'removedFinished',
                      child: Text('Finished · files removed'),
                    ),
                    PopupMenuItem(value: 'none', child: Text('Clear')),
                  ],
                ),
              ],
            )
          : AppBar(
              title: Text(group.displayName, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 22),
                  tooltip: 'Series actions',
                  onPressed: () => _showMenu(context, ref),
                ),
              ],
            ),
      bottomNavigationBar: _selecting
          ? _SelectionBar(
              selected: _selection!,
              chapters: chapters,
              onCancel: _exitSelection,
              onRemove: () => _confirmRemoveSelection(chapters),
              onQueue: () => _confirmQueueSelection(chapters),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonogramTile(
                  id: group.item.id,
                  title: group.displayName,
                  size: 56,
                  radius: 14,
                  fontSize: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.displayName, style: serifStyle(size: 22)),
                      const SizedBox(height: 5),
                      Text(group.item.host, style: monoStyle()),
                      if (group.item.userTitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Renamed by you · source title: ${group.item.title}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8C877E),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.download_for_offline,
                  iconColor: const Color(0xFF35606F),
                  label: '${group.offlineCount} offline',
                  bg: const Color(0xFFEAF1F4),
                  fg: const Color(0xFF133845),
                ),
                _MetaChip(
                  icon: Icons.circle,
                  iconSize: 9,
                  iconColor: const Color(0xFF35606F),
                  label: '${group.unreadOfflineCount} unread',
                  bg: const Color(0xFFF3F1ED),
                  fg: const Color(0xFF3E3A34),
                ),
                if (bytes > 0)
                  _MetaChip(
                    icon: Icons.folder,
                    iconColor: const Color(0xFF7A756C),
                    label: formatBytes(bytes),
                    bg: const Color(0xFFF3F1ED),
                    fg: const Color(0xFF3E3A34),
                  ),
              ],
            ),
          ),
          if (warning != null) _WarningCard(group: group, warning: warning),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: resume == null
                        ? null
                        : () => context.push('/reader/${resume.id}'),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    label: Text(
                      resume == null
                          ? 'Nothing to read yet'
                          : '${reading.currentChapter != null ? 'Continue' : 'Read'} '
                                '· ${resume.chapterLabel ?? resume.title}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (group.item.lifecycle == 'archived')
            _ArchivedBanner(group: group)
          else
            _UpdateCheckCard(group: group, checker: checker),
          if (knownRemote.isNotEmpty)
            _RemoteChapters(
              chapters: knownRemote,
              onCapture: () => _captureNewChapters(context, ref, knownRemote),
            ),
          SectionLabel(
            'SAVED CHAPTERS · ${chapters.length}',
            trailing: _ChapterSortToggle(sort: sort),
          ),
          const Divider(),
          for (final chapter in chapters) ...[
            _ChapterRow(
              chapter: chapter,
              selecting: _selecting,
              selected: _selection?.contains(chapter.id) ?? false,
              lockReason: _locks[chapter.id],
              onToggle: () => _toggle(chapter.id),
            ),
            const Divider(),
          ],
        ],
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                subtitle: const Text('Your name, source title kept'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _promptRename(context, ref, group);
                },
              ),
              if (group.item.lifecycle != 'archived')
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('Archive'),
                  subtitle: const Text('Hidden from library · reversible'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final archived = await confirmArchiveSeries(
                      context,
                      ref,
                      group,
                    );
                    // Back to the library: the series just left it, and
                    // staying here would imply it did not.
                    if (archived && context.mounted) context.pop();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.checklist),
                title: const Text('Manage downloads'),
                subtitle: const Text('Select chapters · remove offline files'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _enterSelection();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: const Text('Remove offline files…'),
                subtitle: const Text(
                  'Whole series · keeps history and read marks',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmRemoveSeries();
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

  /// Queue a bounded capture over the discovered chapters' own URLs (M14:
  /// all autonomous work goes through the activity queue, so it shows up in
  /// history and serializes on the shared WebView by construction).
  ///
  /// `skipComplete`, not `ask`: the user just said "capture the new ones", so
  /// walking over an already saved chapter in between should skip it quietly
  /// — that is the request, not a surprise.
  Future<void> _captureNewChapters(
    BuildContext context,
    WidgetRef ref,
    List<Chapter> knownRemote,
  ) async {
    final queue = ref.read(taskQueueProvider);
    final result = await queue.enqueueCapture(
      startUrl: knownRemote.first.sourceUrl,
      chapterLimit: knownRemote.length,
      libraryItemId: group.item.id,
      policy: DuplicatePolicy.skipComplete,
    );
    if (!context.mounted) return;
    // One walk over the chain, queued. It waits like everything else — the
    // Browser opens when the user starts the queue, not because they tapped
    // "capture new" (D46).
    showQueuedConfirmation(
      context,
      result,
      what:
          '${knownRemote.length} new chapter'
          '${knownRemote.length == 1 ? '' : 's'}',
    );
  }

  Future<void> _promptRename(
    BuildContext context,
    WidgetRef ref,
    SeriesGroup group,
  ) async {
    final controller = TextEditingController(text: group.displayName);
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename series'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only what is shown here changes. Source URLs, stored files and '
              'how future captures are matched all stay as they are.',
              style: TextStyle(fontSize: 11, color: Color(0xFF5F5B54)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (group.item.userTitle != null)
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('Reset'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref
        .read(seriesRepositoryProvider)
        .rename(group.item.id, result.trim().isEmpty ? null : result);
  }
}

/// The docked selection bar: how many, roughly how much space, and the two
/// ways out. Disabled-looking until something is selected.
/// One bar, two opposite actions, each live only when the selection actually
/// contains something it can act on — so "Remove files" cannot be pressed on
/// a selection of chapters that have none, and vice versa.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selected,
    required this.chapters,
    required this.onCancel,
    required this.onRemove,
    required this.onQueue,
  });

  final Set<String> selected;
  final List<Chapter> chapters;
  final VoidCallback onCancel;
  final VoidCallback onRemove;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final chosen = chapters.where((c) => selected.contains(c.id)).toList();
    final bytes = chosen.fold<int>(0, (sum, c) => sum + c.byteSize);
    final any = selected.isNotEmpty;
    final withFiles = chosen.where(isReadableOffline).length;
    final queueable = chosen
        .where((c) => !isReadableOffline(c) && chapterHasCapturableUrl(c))
        .length;
    final noSource = chosen
        .where((c) => !isReadableOffline(c) && !chapterHasCapturableUrl(c))
        .length;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFBFAF8),
        border: Border(top: BorderSide(color: Color(0xFFE7E3DC))),
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${selected.length} selected',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontVariations: wght(600),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  !any
                      ? 'select chapters below'
                      : [
                          if (withFiles > 0)
                            '$withFiles offline · ~${formatBytes(bytes)}',
                          if (queueable > 0) '$queueable can be queued',
                          if (noSource > 0) '$noSource have no source page',
                        ].join(' · '),
                  maxLines: 2,
                  style: monoStyle(size: 11.5, color: const Color(0xFF5F5B54)),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
          const SizedBox(width: 4),
          // Flexible + scale-down: these labels are the longest strings in
          // the bar, and the counts column beside them is what actually has
          // to stay readable.
          Flexible(
            child: queueable > 0
                ? FilledButton(
                    key: const ValueKey('queueSelectionButton'),
                    onPressed: onQueue,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Add to queue'),
                    ),
                  )
                : FilledButton(
                    key: const ValueKey('removeSelectionButton'),
                    onPressed: withFiles > 0 ? onRemove : null,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Remove files'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.iconColor,
    this.iconSize = 15,
  });

  final IconData icon;
  final String label;
  final Color bg, fg, iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: fg)),
      ],
    ),
  );
}

/// Partial and failed captures get one amber card that says which chapters and
/// what it means for reading — not a red banner that implies data loss.
class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.group, required this.warning});

  final SeriesGroup group;
  final SeriesWarning warning;

  @override
  Widget build(BuildContext context) {
    final failed = group.failedChapters > 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: failed ? const Color(0xFFF7DDD8) : const Color(0xFFF8EEDA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: failed ? const Color(0xFFEBC4BC) : const Color(0xFFE8D5B2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warning.icon, size: 20, color: warning.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontVariations: wght(600),
                    fontWeight: FontWeight.w600,
                    color: failed
                        ? const Color(0xFF4A140E)
                        : const Color(0xFF4A2F08),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  failed
                      ? 'The source layout may have changed. Capture again, '
                            'and point at the panels if it fails once more.'
                      : 'Some images are missing. Those chapters are still '
                            'readable — capture again to fill the gaps.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: failed
                        ? const Color(0xFF5F3730)
                        : const Color(0xFF6B4A15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An archived series does not get checked — the card that would offer a
/// check says so and offers the way back instead.
class _ArchivedBanner extends ConsumerWidget {
  const _ArchivedBanner({required this.group});

  final SeriesGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F6F3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE7E3DC)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.inventory_2, size: 21, color: Color(0xFF5F5B54)),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Archived',
                style: TextStyle(
                  fontSize: 13,
                  fontVariations: wght(600),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Not checked for updates while archived'
                '${group.item.archivedAt != null ? ' · archived ${formatRelative(group.item.archivedAt)}' : ''}. '
                'Everything downloaded is still readable.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Color(0xFF5F5B54),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () =>
              ref.read(seriesRepositoryProvider).restore(group.item.id),
          child: const Text('Restore'),
        ),
      ],
    ),
  );
}

/// "Check for new chapters" plus the state of the last check. Never checked is
/// its own sentence — it is not the same as "no new chapters".
class _UpdateCheckCard extends ConsumerWidget {
  const _UpdateCheckCard({required this.group, required this.checker});

  final SeriesGroup group;
  final UpdateChecker checker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: checker,
      builder: (context, _) {
        final checking =
            checker.isRunning && checker.activeItemId == group.item.id;
        final item = group.item;

        final (icon, iconColor, title, body) = switch (null) {
          _ when checking => (
            Icons.sync,
            const Color(0xFF35606F),
            'Checking the source…',
            checker.state == UpdateCheckState.needsUserInput
                ? 'Waiting for you: select the next-chapter control in the '
                      'Browser tab.'
                : (checker.message.isEmpty
                      ? 'Reading the chapter list from ${item.host}. '
                            'Metadata only — nothing is downloaded.'
                      : checker.message),
          ),
          _ when item.lastCheckError != null => (
            Icons.sync_problem,
            const Color(0xFF8E3B31),
            'Check failed',
            '${item.lastCheckError}'
                '${item.lastCheckSuccessAt != null ? ' · last success ${formatRelative(item.lastCheckSuccessAt)}' : ''}',
          ),
          _ when item.lastCheckSuccessAt == null => (
            Icons.history_toggle_off,
            const Color(0xFF5F5B54),
            'Never checked for updates',
            'This is not the same as “no new chapters”. Nothing has asked '
                'the source yet.',
          ),
          _ when group.knownRemoteCount > 0 => (
            Icons.cloud,
            const Color(0xFF35606F),
            '${group.knownRemoteCount} new '
                'chapter${group.knownRemoteCount == 1 ? '' : 's'} on source',
            'Checked ${formatRelative(item.lastCheckSuccessAt)} · metadata '
                'only, nothing downloaded yet.',
          ),
          _ => (
            Icons.update,
            const Color(0xFF5F5B54),
            'No new chapters',
            'Checked ${formatRelative(item.lastCheckSuccessAt)}'
                '${item.lastCheckResult != null ? ' · ${item.lastCheckResult}' : ''}.',
          ),
        };

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E3DC)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 21, color: iconColor),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontVariations: wght(600),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF5F5B54),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              checking
                  ? OutlinedButton(
                      onPressed: checker.cancel,
                      child: const Text('Cancel'),
                    )
                  : FilledButton(
                      // Always tappable: the queue serializes on the shared
                      // WebView, so "busy" means "queued", not "refused".
                      onPressed: () => ref
                          .read(taskQueueProvider)
                          .enqueueSeriesCheck(item.id),
                      child: Text(
                        item.lastCheckSuccessAt == null
                            ? 'Check now'
                            : 'Check again',
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

/// Chapters the source has and this device does not. Dashed, deliberately
/// unreadable-looking, and never tappable into the reader — tapping one
/// offers its source page or a capture instead.
class _RemoteChapters extends ConsumerWidget {
  const _RemoteChapters({required this.chapters, required this.onCapture});

  final List<Chapter> chapters;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('NEW ON SOURCE — NOT DOWNLOADED'),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFBF9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD7D2C9)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final chapter in chapters)
              InkWell(
                key: ValueKey('remoteRow-${chapter.id}'),
                onTap: () => showUnavailableChapterSheet(context, ref, chapter),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF1EEE9)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud,
                        size: 20,
                        color: Color(0xFFA39D93),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          chapterDisplayLabel(
                            number: chapter.chapterNumber,
                            rawLabel: chapter.chapterLabel,
                            title: chapter.title,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: monoStyle(
                            size: 13,
                            color: const Color(0xFF4A463F),
                          ),
                        ),
                      ),
                      Text(
                        'found ${formatRelative(chapter.discoveredAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8C877E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Material(
              color: const Color(0xFFEAF1F4),
              child: InkWell(
                onTap: onCapture,
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.download,
                        size: 19,
                        color: Color(0xFF133845),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Capture ${chapters.length} new '
                        'chapter${chapters.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 14,
                          fontVariations: wght(600),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF133845),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ChapterRow extends ConsumerWidget {
  const _ChapterRow({
    required this.chapter,
    this.selecting = false,
    this.selected = false,
    this.lockReason,
    this.onToggle,
  });

  final Chapter chapter;
  final bool selecting;
  final bool selected;

  /// Why this chapter cannot be selected (open in the reader, mid-capture).
  final String? lockReason;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = captureStatusFromName(chapter.captureStatus);
    final offline =
        chapter.contentPath != null &&
        (status == CaptureStatus.complete || status == CaptureStatus.partial);
    final look = captureLook(chapter);
    // Number-first: "Chapter 487", not "487. Bölüm Oku". The raw label is
    // kept on the row and shown in the details sheet.
    final displayLabel = chapterDisplayLabel(
      number: chapter.chapterNumber,
      rawLabel: chapter.chapterLabel,
      title: chapter.title,
    );
    // Selectable = not locked. Offline chapters can be removed; chapters
    // without files can be queued for re-download — both are selection work,
    // so both are pickable, and the bar decides what applies (D48). A locked
    // chapter stays visible but dimmed, so "why can't I pick that one"
    // answers itself.
    final selectable = selecting && lockReason == null;

    return Opacity(
      opacity: selecting && !selectable ? 0.45 : 1,
      child: Container(
        color: selected ? const Color(0xFFEFF4F6) : Colors.transparent,
        child: InkWell(
          key: ValueKey('chapterRow-${chapter.id}'),
          // Offline → the reader, exactly as before. Not offline → the two
          // things that can still be done with it, rather than a dead row.
          onTap: selecting
              ? (selectable ? onToggle : null)
              : offline
              ? () => context.push('/reader/${chapter.id}')
              : () => showUnavailableChapterSheet(context, ref, chapter),
          // The source page stays reachable for a chapter that IS offline,
          // without competing with reading it.
          onLongPress: selecting
              ? null
              : () => showChapterDetailsSheet(context, ref, chapter),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 16, 11),
            child: Row(
              children: [
                // Leading = capture state (download vocabulary), trailing = read
                // state (checkmark vocabulary). Two facts, two glyph families —
                // never mixed. In selection mode the leading slot becomes the
                // checkbox (or a lock).
                SizedBox(
                  width: 24,
                  child: selecting
                      ? Icon(
                          lockReason != null
                              ? Icons.lock
                              : (selected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank),
                          size: 22,
                          color: selected
                              ? const Color(0xFF35606F)
                              : (selectable
                                    ? const Color(0xFF5F5B54)
                                    : const Color(0xFFC4BFB5)),
                        )
                      : CaptureGlyph(look),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: monoStyle(
                          size: 13.5,
                          weight: FontWeight.w500,
                          color: look.dimTitle
                              ? const Color(0xFF8C877E)
                              : const Color(0xFF1B1A18),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            look.label,
                            style: TextStyle(fontSize: 11.5, color: look.color),
                          ),
                          const Text(
                            ' · ',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFCFC9BF),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              selecting && lockReason != null
                                  ? '$lockReason — kept'
                                  : _meta(chapter),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: monoStyle(
                                size: 11.5,
                                color: const Color(0xFF5F5B54),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (offline && !selecting) ReadGlyph(chapter: chapter),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _meta(Chapter chapter) {
    // A user-removed chapter has no images and no size to report; what
    // matters is that it can come back.
    if (chapter.contentPath == null && chapter.offlineRemovedAt != null) {
      return 'removed ${formatRelative(chapter.offlineRemovedAt)} · '
          'capture again to read';
    }
    final parts = <String>[
      '${chapter.storedImageCount}/${chapter.detectedImageCount} images',
      if (chapter.byteSize > 0) formatBytes(chapter.byteSize),
      if (chapter.capturedAt != null) formatRelative(chapter.capturedAt),
    ];
    return parts.join(' · ');
  }
}

/// Reading order: parsed chapter number, then capture sequence, then time.
/// Two states, so it is a toggle rather than a panel: tapping flips the list
/// and persists the choice.
class _ChapterSortToggle extends ConsumerWidget {
  const _ChapterSortToggle({required this.sort});

  final ChapterSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = sort == ChapterSort.newestFirst
        ? ChapterSort.oldestFirst
        : ChapterSort.newestFirst;
    return Semantics(
      button: true,
      label: 'Sorted ${sort.label} first. Tap for ${next.label} first.',
      excludeSemantics: true,
      child: Material(
        color: const Color(0xFFF3F1ED),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Color(0xFFE7E3DC)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('chapterSortToggle'),
          onTap: () => setChapterSort(ref, next),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  sort == ChapterSort.newestFirst
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 14,
                  color: const Color(0xFF3E3A34),
                ),
                const SizedBox(width: 5),
                Text(
                  sort.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF3E3A34),
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

/// Which way the episode list runs.
enum ChapterSort {
  /// Newest first. The default: a reader who is up to date cares about the
  /// end of the list, and a 400-chapter series should not open at chapter 1.
  newestFirst,

  /// Oldest first — reading order, for someone starting a series.
  oldestFirst;

  String get label => this == ChapterSort.newestFirst ? 'Newest' : 'Oldest';
}

const String kChapterSortKey = 'series.chapterSort';

ChapterSort chapterSortFromName(String? name) =>
    name == ChapterSort.oldestFirst.name
    ? ChapterSort.oldestFirst
    : ChapterSort.newestFirst;

/// The persisted episode-list order. One setting for every series: it is a
/// reading habit, not a per-series fact.
final chapterSortProvider = StreamProvider<ChapterSort>(
  (ref) => ref
      .watch(databaseProvider)
      .watchSetting(kChapterSortKey)
      .map(chapterSortFromName),
);

Future<void> setChapterSort(WidgetRef ref, ChapterSort sort) =>
    ref.read(databaseProvider).setSetting(kChapterSortKey, sort.name);

/// Reading order, then flipped if asked.
///
/// The comparison is always the same one — parsed chapter number first
/// (decimal-safe, so `385 < 385.5 < 386`), then capture sequence, then
/// capture time for entries that have no number at all. Descending reverses
/// that single ordering rather than being a second, subtly different one, so
/// a non-numeric `Extra` keeps the same neighbours either way.
List<Chapter> sortChapters(List<Chapter> chapters, ChapterSort sort) {
  final ordered = sortChaptersForReading(chapters);
  return sort == ChapterSort.newestFirst ? ordered.reversed.toList() : ordered;
}

List<Chapter> sortChaptersForReading(List<Chapter> chapters) {
  final sorted = [...chapters];
  sorted.sort(
    (a, b) => compareChaptersForReading(
      (number: a.chapterNumber, sequence: a.sequence, capturedAt: a.capturedAt),
      (number: b.chapterNumber, sequence: b.sequence, capturedAt: b.capturedAt),
    ),
  );
  return sorted;
}

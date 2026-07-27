import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../capture/capture_preflight.dart';
import '../library/series_identity.dart';
import '../library/update_checker.dart';
import '../providers.dart';
import '../reading/reading_repository.dart';
import '../storage/database.dart';
import '../storage/manifest.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';
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
  const SeriesDetailScreen({super.key, required this.seriesId});

  final String seriesId;

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
        return _SeriesDetail(group: data);
      },
    );
  }
}

class _SeriesDetail extends ConsumerWidget {
  const _SeriesDetail({required this.group});

  final SeriesGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = sortChaptersForReading(group.capturedChapters);
    final knownRemote = sortChaptersForReading(group.knownRemoteChapters);
    final reading = computeSeriesReadingState(group.chapters);
    final resume = reading.continueChapter;
    final first = chapters.isEmpty ? null : chapters.first;
    final checker = ref.watch(updateCheckerProvider);
    final warning = group.warningLine;
    final bytes = group.chapters.fold<int>(0, (sum, c) => sum + c.byteSize);

    return Scaffold(
      appBar: AppBar(
        title: Text(group.displayName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, size: 22),
            tooltip: 'Series actions',
            onPressed: () => _showMenu(context, ref),
          ),
        ],
      ),
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
                if (first != null && first.id != resume?.id) ...[
                  const SizedBox(width: 9),
                  OutlinedButton(
                    onPressed: () => context.push('/reader/${first.id}'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      first.chapterLabel ?? 'First',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
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
            trailing: Text(
              'reading order',
              style: monoStyle(color: const Color(0xFFA39D93)),
            ),
          ),
          const Divider(),
          for (final chapter in chapters) ...[
            _ChapterRow(chapter: chapter),
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
    final busy =
        ref.read(captureJobProvider).isRunning ||
        ref.read(updateCheckerProvider).isRunning;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          busy
              ? 'Queued ${knownRemote.length} chapter(s) — starts when the '
                    'current run finishes. Progress is in Activity.'
              : 'Capturing ${knownRemote.length} chapter(s) — progress is in '
                    'the Browser tab and Activity.',
        ),
      ),
    );
    await queue.enqueueCapture(
      startUrl: knownRemote.first.sourceUrl,
      chapterLimit: knownRemote.length,
      libraryItemId: group.item.id,
      policy: DuplicatePolicy.skipComplete,
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
/// unreadable-looking, and never tappable into the reader.
class _RemoteChapters extends StatelessWidget {
  const _RemoteChapters({required this.chapters, required this.onCapture});

  final List<Chapter> chapters;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) => Column(
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
              Container(
                key: ValueKey('remoteRow-${chapter.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1EEE9))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud, size: 20, color: Color(0xFFA39D93)),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        chapter.chapterLabel?.trim().isNotEmpty == true
                            ? chapter.chapterLabel!
                            : chapter.title,
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

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({required this.chapter});

  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final status = captureStatusFromName(chapter.captureStatus);
    final offline =
        chapter.contentPath != null &&
        (status == CaptureStatus.complete || status == CaptureStatus.partial);
    final look = captureLook(chapter);
    final label = chapter.chapterLabel?.trim();

    return InkWell(
      key: ValueKey('chapterRow-${chapter.id}'),
      onTap: offline ? () => context.push('/reader/${chapter.id}') : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 16, 11),
        child: Row(
          children: [
            // Leading = capture state (download vocabulary), trailing = read
            // state (checkmark vocabulary). Two facts, two glyph families —
            // never mixed.
            SizedBox(width: 24, child: CaptureGlyph(look)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label != null && label.isNotEmpty ? label : chapter.title,
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
                          _meta(chapter),
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
            if (offline) ReadGlyph(chapter: chapter),
          ],
        ),
      ),
    );
  }

  String _meta(Chapter chapter) {
    final parts = <String>[
      '${chapter.storedImageCount}/${chapter.detectedImageCount} images',
      if (chapter.byteSize > 0) formatBytes(chapter.byteSize),
      if (chapter.capturedAt != null) formatRelative(chapter.capturedAt),
    ];
    return parts.join(' · ');
  }
}

/// Reading order: parsed chapter number, then capture sequence, then time.
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../capture/capture_preflight.dart';
import '../core/config.dart';
import '../core/url_utils.dart';
import '../library/series_identity.dart';
import '../providers.dart';
import '../reading/reading_position.dart';
import '../storage/database.dart';
import '../ui/status_style.dart';
import 'capture_queue_ui.dart';
import 'chapter_actions.dart';
import 'cleanup_dialogs.dart';
import 'library_screen.dart' show formatBytes, formatRelative;

/// Everything known about one chapter, on long press.
///
/// A bottom sheet rather than a dialog: it is the phone-native surface for
/// "tell me about this and let me act on it", it can be dismissed by dragging,
/// and it does not fight the list underneath.
///
/// The facts here all come from the chapter row the list already holds —
/// including `byteSize`, which capture records at commit time. Nothing is
/// measured off disk when the sheet opens; a details sheet must not stat a
/// directory tree to show a size.
Future<void> showChapterDetailsSheet(
  BuildContext context,
  WidgetRef ref,
  Chapter chapter,
) {
  // Long press is a deliberate act; acknowledging it is the platform
  // convention and matches the selection-mode entry elsewhere in the app.
  unawaited(HapticFeedback.selectionClick());
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _ChapterDetails(chapter: chapter),
  );
}

class _ChapterDetails extends ConsumerWidget {
  const _ChapterDetails({required this.chapter});

  final Chapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-read from the live list so the sheet reflects a mark-as-read made
    // from inside it, without closing and reopening.
    final live =
        ref
            .watch(chaptersStreamProvider)
            .value
            ?.where((c) => c.id == chapter.id)
            .firstOrNull ??
        chapter;

    final status = readStatusFromName(live.readStatus);
    final completed = status == ReadStatus.completed;
    final progress = readProgressFor(
      readStatus: live.readStatus,
      stored: live.progressFraction,
    );
    final offline = isReadableOffline(live);
    final knowsSource = hasUsableSourceUrl(live);
    final raw = live.chapterLabel?.trim();
    final display = chapterDisplayLabel(
      number: live.chapterNumber,
      rawLabel: live.chapterLabel,
      title: live.title,
    );

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: Row(
                children: [
                  ChapterProgressRing(
                    fraction: progress,
                    completed: completed,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          display,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: monoStyle(
                            size: 15,
                            weight: FontWeight.w600,
                            color: const Color(0xFF1B1A18),
                          ),
                        ),
                        // The site's own words, but only when they add
                        // something the number does not already say.
                        if (raw != null && raw.isNotEmpty && raw != display)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              raw,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8C877E),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Column(
                children: [
                  _Fact(
                    'Read',
                    completed
                        ? 'Finished'
                        : status == ReadStatus.inProgress
                        ? '${(progress * 100).round()}% read'
                        : 'Not started',
                  ),
                  _Fact(
                    'Offline',
                    offline
                        ? 'Available · ${formatBytes(live.byteSize)}'
                        : live.offlineRemovedAt != null
                        ? 'Removed ${formatRelative(live.offlineRemovedAt)}'
                        : 'Not downloaded',
                  ),
                  _Fact('Capture', _captureLine(live)),
                  if (live.capturedAt != null)
                    _Fact('Captured', formatRelative(live.capturedAt)),
                  if (live.lastReadAt != null)
                    _Fact('Last read', formatRelative(live.lastReadAt)),
                  if (live.discoveredAt != null)
                    _Fact(
                      'Discovered',
                      '${formatRelative(live.discoveredAt)}'
                          '${live.discoveryBasis != null ? ' · ${live.discoveryBasis}' : ''}',
                    ),
                  _Fact(
                    'Source',
                    knowsSource ? hostOf(live.sourceUrl) : 'Unknown',
                  ),
                  if (knowsSource)
                    _Fact('URL', live.sourceUrl, mono: true, wrap: true),
                ],
              ),
            ),
            const Divider(height: 18),
            if (offline)
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: const Text('Open episode'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/reader/${live.id}');
                },
              ),
            openOnWebsiteTile(
              context,
              ref,
              live,
              beforeOpen: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: Icon(
                completed ? Icons.remove_done : Icons.done_all,
                color: const Color(0xFF3E3A34),
              ),
              title: Text(completed ? 'Mark as unread' : 'Mark as read'),
              onTap: () async {
                final reading = ref.read(readingRepositoryProvider);
                if (completed) {
                  await reading.markUnread(live.id);
                } else {
                  await reading.markRead(live.id);
                }
              },
            ),
            if (knowsSource)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(offline ? 'Re-fetch' : 'Add to capture queue'),
                subtitle: Text(
                  offline
                      ? 'Queues a replacement · keeps your place and read state'
                      : 'Waits until you start the queue',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _refetch(context, ref, live);
                },
              ),
            if (offline)
              ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: const Text('Remove offline files'),
                subtitle: const Text('Keeps history and read marks'),
                onTap: () {
                  Navigator.of(context).pop();
                  _removeOffline(context, ref, live);
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _captureLine(Chapter c) {
    final stored = c.storedImageCount;
    final detected = c.detectedImageCount;
    return switch (c.captureStatus) {
      'complete' => '$stored image${stored == 1 ? '' : 's'}',
      'partial' => 'Partial · $stored of $detected images',
      'knownRemote' => 'Known on the source, never captured',
      'failed' =>
        'Failed${c.captureError != null ? ' · ${c.captureError}' : ''}',
      final other => other,
    };
  }

  /// Re-fetch goes through the ordinary queued capture with the replace
  /// policy, which is the flow that already guarantees what matters: the same
  /// chapter row, an atomic file swap, and reading state carried over
  /// verbatim. Nothing bespoke here — a second path would be a second set of
  /// bugs.
  Future<void> _refetch(
    BuildContext context,
    WidgetRef ref,
    Chapter chapter,
  ) async {
    final result = await ref
        .read(taskQueueProvider)
        .enqueueCapture(
          startUrl: chapter.sourceUrl,
          chapterLimit: 1,
          libraryItemId: chapter.libraryItemId,
          policy: DuplicatePolicy.replaceAll,
          range: CaptureRangeMode.currentChapter,
        );
    if (!context.mounted) return;
    showQueuedConfirmation(context, result);
  }

  Future<void> _removeOffline(
    BuildContext context,
    WidgetRef ref,
    Chapter chapter,
  ) async {
    final cleanup = ref.read(cleanupProvider);
    final lock = await cleanup.lockReasonFor(chapter);
    if (!context.mounted) return;
    if (lock != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kept — $lock.')));
      return;
    }
    final label = chapterDisplayLabel(
      number: chapter.chapterNumber,
      rawLabel: chapter.chapterLabel,
      title: chapter.title,
    );
    final confirmed = await showRemovalConfirm(
      context: context,
      summary: RemovalSummary(
        title: 'Remove offline files?',
        body:
            'The images for $label go. The chapter stays in your library '
            'with your reading history, and can be captured again.',
        facts: [
          ('Chapter', label),
          ('Space freed', formatBytes(chapter.byteSize)),
        ],
      ),
    );
    if (!confirmed || !context.mounted) return;
    final result = await cleanup.removeOffline([chapter.id]);
    if (!context.mounted) return;
    showCleanupToast(
      context,
      text: '$label removed offline · ${formatBytes(result.freedBytes)} freed',
      undo: result.canUndo ? result.undo.undo : null,
    );
  }
}

/// One label/value line. Kept dumb so the sheet stays a list of facts.
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.mono = false, this.wrap = false});

  final String label;
  final String value;
  final bool mono;
  final bool wrap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: monoStyle(size: 11.5, color: const Color(0xFF8C877E)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: wrap ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: mono
                ? monoStyle(size: 11.5, color: const Color(0xFF3E3A34))
                : const TextStyle(fontSize: 13, color: Color(0xFF3E3A34)),
          ),
        ),
      ],
    ),
  );
}

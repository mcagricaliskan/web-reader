import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/capture_preflight.dart';
import '../core/config.dart';
import '../core/connectivity.dart';
import '../core/url_utils.dart';
import '../providers.dart';
import 'capture_queue_ui.dart';
import 'open_in_browser.dart';
import '../storage/database.dart';
import '../ui/palette.dart';
import '../ui/status_style.dart';

/// Injectable so a widget test can say "this device is offline" without one.
final connectivityProvider = Provider<Connectivity>(
  (ref) => const Connectivity(),
);

/// Whether a chapter still knows where it came from.
///
/// `sourceUrl` is non-null in the schema, but a row written by an older build
/// (or repaired from a manifest that lacked one) can hold an empty string, and
/// a blank URL must disable the action rather than navigate somewhere wrong.
bool hasUsableSourceUrl(Chapter chapter) {
  final url = chapter.sourceUrl.trim();
  if (url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty;
}

/// Is this chapter readable from local files right now?
bool isReadableOffline(Chapter chapter) =>
    chapter.contentPath != null &&
    (chapter.captureStatus == 'complete' || chapter.captureStatus == 'partial');

/// Open a chapter's own page in the app's Browser.
///
/// Kept as the name every chapter surface calls, but the navigation itself
/// lives in [openChapterInBrowser] — one coordinator, because the previous
/// version did half of it (told the controller, switched the shell's tab) and
/// the user, standing on a route pushed *above* the shell, saw nothing
/// change.
///
/// The guarantee that stays here: **the stored URL or nothing.** No fallback
/// to the series page and no guess from a sibling chapter — sending someone
/// to a different chapter of a different series is worse than not moving at
/// all (D42).
///
/// Returns true when the Browser was actually sent somewhere.
Future<bool> openChapterOnWebsite(
  BuildContext context,
  WidgetRef ref,
  Chapter chapter,
) => openChapterInBrowser(context, ref, chapter);

/// What tapping a chapter with no offline files offers.
///
/// The reader is deliberately not opened: there is nothing to read, and an
/// "unavailable" screen the user has to back out of is a worse answer than
/// the two things they might actually want.
Future<void> showUnavailableChapterSheet(
  BuildContext context,
  WidgetRef ref,
  Chapter chapter,
) async {
  final knowsSource = hasUsableSourceUrl(chapter);
  final removed = chapter.offlineRemovedAt != null;
  final label = chapter.chapterLabel?.trim().isNotEmpty == true
      ? chapter.chapterLabel!.trim()
      : chapter.title;

  await showModalBottomSheet<void>(
    context: context,
    // A two-line header plus three actions does not fit in the default
    // 9/16-height sheet on a short screen, and the bottom action is the one
    // that gets clipped.
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(
                      size: 14,
                      weight: FontWeight.w500,
                      color: AppPalette.of(context).ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    removed
                        ? 'Not available offline — you removed its files. '
                              'Your reading history is still here.'
                        : 'Not available offline yet.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppPalette.of(context).inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 18),
            ListTile(
              enabled: knowsSource,
              leading: Icon(
                Icons.public,
                color: knowsSource ? null : AppPalette.of(context).inkDisabled,
              ),
              title: const Text('Open on website'),
              subtitle: Text(
                knowsSource
                    ? hostOf(chapter.sourceUrl)
                    : 'The original page is unknown for this chapter',
              ),
              onTap: knowsSource
                  ? () {
                      Navigator.of(sheetContext).pop();
                      unawaitedOpen(context, ref, chapter);
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Add to capture queue'),
              subtitle: const Text('Waits until you start the queue'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _captureAgain(context, ref, chapter);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Fire-and-forget wrapper: the sheet is already closing, and awaiting inside
/// its `onTap` would hold a dead context.
void unawaitedOpen(BuildContext context, WidgetRef ref, Chapter chapter) {
  openChapterOnWebsite(context, ref, chapter);
}

Future<void> _captureAgain(
  BuildContext context,
  WidgetRef ref,
  Chapter chapter,
) async {
  if (!hasUsableSourceUrl(chapter)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "This chapter's original page is unknown, so it can't be captured "
          'again.',
        ),
      ),
    );
    return;
  }
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
  // Queued, not started: the user stays exactly where they are (D46).
  showQueuedConfirmation(context, result);
}

/// "Open on website" as a row for an *available* chapter's overflow sheet.
///
/// Offered, never promoted: tapping an offline chapter still opens the
/// reader. This is for going back to the source — comments, a correction, the
/// page as the site renders it.
Widget openOnWebsiteTile(
  BuildContext context,
  WidgetRef ref,
  Chapter chapter, {
  VoidCallback? beforeOpen,
}) {
  final knowsSource = hasUsableSourceUrl(chapter);
  return ListTile(
    enabled: knowsSource,
    leading: Icon(
      Icons.public,
      color: knowsSource ? null : AppPalette.of(context).inkDisabled,
    ),
    title: const Text('Open on website'),
    subtitle: Text(
      knowsSource
          ? hostOf(chapter.sourceUrl)
          : 'The original page is unknown for this chapter',
    ),
    onTap: knowsSource
        ? () {
            beforeOpen?.call();
            unawaitedOpen(context, ref, chapter);
          }
        : null,
  );
}

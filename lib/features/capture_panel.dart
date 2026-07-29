import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/capture_job.dart';
import '../capture/capture_state.dart';
import '../ui/palette.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';

/// Status and controls for the running capture job, docked under the WebView.
///
/// Layout follows the design's capture panel: phase chip + chapter counter +
/// log toggle on one line, a progress bar with mono image/scroll counters
/// under it, a dark log drawer, and a horizontal strip of pill controls.
class CapturePanel extends StatelessWidget {
  const CapturePanel({
    super.key,
    required this.job,
    required this.expanded,
    required this.onToggle,
  });

  final CaptureJobController job;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final p = job.progress;
    if (p.state == CaptureState.idle && !expanded) {
      return const SizedBox.shrink();
    }

    final pct = p.detectedImages > 0
        ? (p.storedImages / p.detectedImages).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _PhaseChip(state: p.state),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'chapter ${p.chapterIndex}/${p.requestedChapters}'
                  ' · ${p.storedChapters} stored'
                  '${p.skippedChapters > 0 ? ' · ${p.skippedChapters} skipped' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(size: 11.5, color: palette.inkMuted),
                ),
              ),
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        expanded ? 'Hide log' : 'Log',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontVariations: wght(500),
                          fontWeight: FontWeight.w500,
                          color: palette.primary,
                        ),
                      ),
                      Icon(
                        expanded ? Icons.expand_more : Icons.expand_less,
                        size: 16,
                        color: palette.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (p.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              p.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: palette.inkStrong),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: p.state == CaptureState.scrolling ? null : pct,
              minHeight: 5,
              backgroundColor: palette.border,
              color: job.isPaused ? palette.inkMuted : palette.primary,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${p.storedImages} / ${p.detectedImages} images'
                '${p.failedImages > 0 ? ' · ${p.failedImages} failed' : ''}',
                style: monoStyle(
                  color: p.failedImages > 0 ? palette.danger : palette.inkMuted,
                ),
              ),
              Text(
                'scroll ${(p.scrollPercent * 100).round()}%'
                '${p.retryCount > 0 ? ' · retry ${p.retryCount}' : ''}',
                style: monoStyle(color: palette.inkMuted),
              ),
            ],
          ),
          if (p.lastError != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: palette.dangerContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.dangerBorder),
              ),
              child: Text(
                p.lastError!,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: palette.onDangerContainer,
                ),
              ),
            ),
          ],
          if (expanded && job.log.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 8),
              decoration: BoxDecoration(
                color: palette.toastSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 96),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in job.log.take(40))
                            Text(
                              line,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                fontSize: 10.5,
                                height: 1.7,
                                color: line.contains('fail')
                                    ? AppPalette.dark.danger
                                    : palette.toastInk,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _copyLog(context, job),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.content_copy,
                          size: 14,
                          color: palette.toastAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Copy log',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.toastAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (job.isRunning) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (job.isPaused)
                    _PrimaryCtl('Resume', Icons.play_arrow, job.resume)
                  else
                    _PrimaryCtl('Pause', Icons.pause, job.pause),
                  const SizedBox(width: 7),
                  _PillCtl('Stop', Icons.stop, job.stop),
                  const SizedBox(width: 7),
                  _PillCtl('Retry', Icons.refresh, job.retryCurrentChapter),
                  const SizedBox(width: 7),
                  _PillCtl('Skip', Icons.skip_next, job.skipCurrentChapter),
                  const SizedBox(width: 7),
                  _PillCtl(
                    'Pick reader',
                    Icons.ads_click,
                    job.requestReaderAreaSelection,
                  ),
                  const SizedBox(width: 7),
                  _PillCtl(
                    'Pick next',
                    Icons.low_priority,
                    job.requestNextLinkSelection,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What a finished run did, for the page it happened on.
///
/// Deliberately a *result*, not a state (D59): it is dismissible, it never
/// disables anything, and it goes away the moment the Browser shows another
/// page. The durable copy of this outcome is the Activity row.
class CaptureResultBanner extends StatelessWidget {
  const CaptureResultBanner({
    super.key,
    required this.result,
    required this.onDismiss,
    required this.onViewActivity,
  });

  final CaptureRunRecord result;
  final VoidCallback onDismiss;
  final VoidCallback onViewActivity;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final ok = result.succeeded;
    final (bg, border, ink, icon) = ok
        ? (
            palette.primaryContainer,
            palette.primaryBorder,
            palette.onPrimaryContainer,
            Icons.download_for_offline,
          )
        : result.state == CaptureState.cancelled
        ? (
            palette.surfaceHigh,
            palette.borderInset,
            palette.inkMuted,
            Icons.do_not_disturb_on,
          )
        : (
            palette.dangerContainer,
            palette.dangerBorder,
            palette.onDangerContainer,
            Icons.error,
          );

    return Container(
      key: const ValueKey('captureResultBanner'),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  switch (result.state) {
                    CaptureState.complete => 'Capture finished',
                    CaptureState.partial => 'Captured, with gaps',
                    CaptureState.cancelled => 'Capture stopped',
                    _ => 'Capture failed',
                  },
                  style: TextStyle(
                    fontSize: 13,
                    fontVariations: wght(600),
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.error ??
                      (result.message.isEmpty
                          ? '${result.storedChapters} chapter(s) captured'
                          : result.message),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: ink),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onViewActivity,
            child: const Text('Activity', style: TextStyle(fontSize: 12.5)),
          ),
          IconButton(
            key: const ValueKey('captureResultDismiss'),
            tooltip: 'Dismiss',
            iconSize: 18,
            color: ink,
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// Copy the whole log, plus the context needed to make sense of it later.
///
/// Redacted the same way the log itself is: cookies and tokens never reach it,
/// so this is safe to paste into an issue. That property is what a future
/// "Report site" button would depend on.
Future<void> _copyLog(BuildContext context, CaptureJobController job) async {
  final p = job.progress;
  final buffer = StringBuffer()
    ..writeln('Web Reader capture log')
    ..writeln('state: ${p.state.name}  (${p.state.label})')
    ..writeln('url: ${p.currentUrl}')
    ..writeln(
      'chapter: ${p.chapterIndex}/${p.requestedChapters}  '
      'stored: ${p.storedChapters}',
    )
    ..writeln(
      'images: ${p.storedImages}/${p.detectedImages}  '
      'failed: ${p.failedImages}  retries: ${p.retryCount}',
    );
  if (p.lastError != null) buffer.writeln('error: ${p.lastError}');
  buffer.writeln('---');
  for (final line in job.log.reversed) {
    buffer.writeln(line);
  }

  await Clipboard.setData(ClipboardData(text: buffer.toString()));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Copied ${job.log.length} log lines'),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// The run-phase chip: icon + uppercase mono label. Terminal states carry
/// their own colours so "SAVED" and "FAILED" cannot be confused at a glance.
class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.state});
  final CaptureState state;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    // Three vocabularies, and only three: neutral for "not running", accent
    // for "working", and the warn/danger containers for the two outcomes that
    // need to be told apart at a glance.
    final neutral = (palette.surfaceHigh, palette.inkMuted, palette.border);
    final accent = (
      palette.primaryContainer,
      palette.onPrimaryContainer,
      palette.primaryBorder,
    );
    final (icon, bg, fg, bd) = switch (state) {
      CaptureState.paused => (
        Icons.pause_circle,
        neutral.$1,
        neutral.$2,
        neutral.$3,
      ),
      CaptureState.complete => (
        Icons.download_for_offline,
        accent.$1,
        accent.$2,
        accent.$3,
      ),
      CaptureState.partial => (
        Icons.arrow_circle_down,
        palette.warnContainer,
        palette.onWarnContainer,
        palette.warnBorder,
      ),
      CaptureState.failed => (
        Icons.error,
        palette.dangerContainer,
        palette.onDangerContainer,
        palette.dangerBorder,
      ),
      CaptureState.cancelled => (
        Icons.do_not_disturb_on,
        neutral.$1,
        neutral.$2,
        neutral.$3,
      ),
      CaptureState.scrolling => (
        Icons.swipe_vertical,
        accent.$1,
        accent.$2,
        accent.$3,
      ),
      CaptureState.inspecting || CaptureState.navigating => (
        Icons.travel_explore,
        accent.$1,
        accent.$2,
        accent.$3,
      ),
      _ => (Icons.downloading, accent.$1, accent.$2, accent.$3),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            state.label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'IBM Plex Mono',
              fontSize: 11.5,
              letterSpacing: 0.35,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCtl extends StatelessWidget {
  const _PrimaryCtl(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(label, style: const TextStyle(fontSize: 12.5)),
    style: FilledButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    ),
  );
}

class _PillCtl extends StatelessWidget {
  const _PillCtl(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(label, style: const TextStyle(fontSize: 12.5)),
    style: OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      foregroundColor: AppPalette.of(context).inkStrong,
      side: BorderSide(color: AppPalette.of(context).borderStrong),
    ),
  );
}

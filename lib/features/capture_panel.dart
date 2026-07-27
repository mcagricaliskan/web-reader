import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../capture/capture_job.dart';
import '../capture/capture_state.dart';
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
    final p = job.progress;
    if (p.state == CaptureState.idle && !expanded) {
      return const SizedBox.shrink();
    }

    final pct = p.detectedImages > 0
        ? (p.storedImages / p.detectedImages).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFBFAF8),
        border: Border(top: BorderSide(color: Color(0xFFDFDAD2))),
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
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 11.5,
                    color: Color(0xFF5F5B54),
                  ),
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
                          color: const Color(0xFF35606F),
                        ),
                      ),
                      Icon(
                        expanded ? Icons.expand_more : Icons.expand_less,
                        size: 16,
                        color: const Color(0xFF35606F),
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
              style: const TextStyle(fontSize: 12, color: Color(0xFF3E3A34)),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: p.state == CaptureState.scrolling ? null : pct,
              minHeight: 5,
              backgroundColor: const Color(0xFFE7E3DC),
              color: job.isPaused
                  ? const Color(0xFF5F5B54)
                  : const Color(0xFF35606F),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${p.storedImages} / ${p.detectedImages} images'
                '${p.failedImages > 0 ? ' · ${p.failedImages} failed' : ''}',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  fontSize: 11,
                  color: p.failedImages > 0
                      ? const Color(0xFF8E3B31)
                      : const Color(0xFF5F5B54),
                ),
              ),
              Text(
                'scroll ${(p.scrollPercent * 100).round()}%'
                '${p.retryCount > 0 ? ' · retry ${p.retryCount}' : ''}',
                style: const TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  fontSize: 11,
                  color: Color(0xFF5F5B54),
                ),
              ),
            ],
          ),
          if (p.lastError != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF7DDD8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEBC4BC)),
              ),
              child: Text(
                p.lastError!,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: Color(0xFF4A140E),
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
                color: const Color(0xFF201F1C),
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
                                    ? const Color(0xFFE0A79E)
                                    : const Color(0xFFC9C4BC),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _copyLog(context, job),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.content_copy,
                          size: 14,
                          color: Color(0xFF9FC3CE),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Copy log',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9FC3CE),
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
    final (icon, bg, fg, bd) = switch (state) {
      CaptureState.paused => (
        Icons.pause_circle,
        const Color(0xFFF3F1ED),
        const Color(0xFF5F5B54),
        const Color(0xFFE4E0D8),
      ),
      CaptureState.complete => (
        Icons.download_for_offline,
        const Color(0xFFEAF1F4),
        const Color(0xFF133845),
        const Color(0xFFD2E2E8),
      ),
      CaptureState.partial => (
        Icons.arrow_circle_down,
        const Color(0xFFF8EEDA),
        const Color(0xFF4A2F08),
        const Color(0xFFE8D5B2),
      ),
      CaptureState.failed => (
        Icons.error,
        const Color(0xFFF7DDD8),
        const Color(0xFF4A140E),
        const Color(0xFFEBC4BC),
      ),
      CaptureState.cancelled => (
        Icons.do_not_disturb_on,
        const Color(0xFFF3F1ED),
        const Color(0xFF5F5B54),
        const Color(0xFFE4E0D8),
      ),
      CaptureState.scrolling => (
        Icons.swipe_vertical,
        const Color(0xFFEAF1F4),
        const Color(0xFF133845),
        const Color(0xFFD2E2E8),
      ),
      CaptureState.inspecting || CaptureState.navigating => (
        Icons.travel_explore,
        const Color(0xFFEAF1F4),
        const Color(0xFF133845),
        const Color(0xFFD2E2E8),
      ),
      _ => (
        Icons.downloading,
        const Color(0xFFEAF1F4),
        const Color(0xFF133845),
        const Color(0xFFD2E2E8),
      ),
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
      foregroundColor: const Color(0xFF3E3A34),
      side: const BorderSide(color: Color(0xFFC9C3B9)),
    ),
  );
}

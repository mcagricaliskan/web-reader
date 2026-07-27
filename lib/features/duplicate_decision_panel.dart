import 'package:flutter/material.dart';

import '../capture/capture_job.dart';
import '../capture/capture_preflight.dart';
import '../features/library_screen.dart' show formatRelative;
import '../ui/theme.dart';

/// Shown in place of the capture panel while the running job holds on a
/// chapter that already exists locally.
///
/// The job is paused underneath: nothing downloads and nothing navigates
/// until the user answers. Offered actions depend on the chapter's state —
/// a complete chapter cannot "retry missing files", a partial one can.
class DuplicateDecisionPanel extends StatefulWidget {
  const DuplicateDecisionPanel({
    super.key,
    required this.job,
    required this.request,
  });

  final CaptureJobController job;
  final DuplicateRequest request;

  @override
  State<DuplicateDecisionPanel> createState() => _DuplicateDecisionPanelState();
}

class _DuplicateDecisionPanelState extends State<DuplicateDecisionPanel> {
  bool _applyToSession = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final chapter = request.chapter;

    // The leading glyph speaks the capture-status vocabulary: what state the
    // existing copy is in decides both the icon and its colour.
    final (icon, iconColor) = switch (chapter?.captureStatus) {
      'partial' => (Icons.arrow_circle_down, const Color(0xFF8A5A1F)),
      'failed' => (Icons.error, const Color(0xFF8E3B31)),
      _ => (Icons.download_for_offline, const Color(0xFF35606F)),
    };

    return Material(
      color: const Color(0xFFFBFAF8),
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 430),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFDAD2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 24, color: iconColor),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.3,
                            fontVariations: wght(600),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (chapter != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${chapter.chapterLabel ?? chapter.title}'
                            ' · ${chapter.storedImageCount}/${chapter.detectedImageCount} images'
                            ' · saved ${formatRelative(chapter.capturedAt)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 11.5,
                              color: Color(0xFF5F5B54),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        const Text(
                          'Nothing has been overwritten. Choose what the run '
                          'should do.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: Color(0xFF5F5B54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final action in request.availableActions) ...[
                _ActionCard(action: action, onTap: () => _submit(action)),
                const SizedBox(height: 7),
              ],
              InkWell(
                onTap: () => setState(() => _applyToSession = !_applyToSession),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                  child: Row(
                    children: [
                      Icon(
                        _applyToSession
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 21,
                        color: _applyToSession
                            ? const Color(0xFF35606F)
                            : const Color(0xFF5F5B54),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Use this choice for every already-captured chapter '
                          'in this run',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: Color(0xFF3E3A34),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 35, top: 6),
                child: Text(
                  'Applies to this session only. Nothing is deleted either way.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFA39D93)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(DuplicateChoiceAction action) => widget.job.resolveDuplicate(
    DuplicateChoice(
      action,
      // Stop is a one-off by design: "stop" is not a policy.
      applyToSession:
          _applyToSession && action != DuplicateChoiceAction.stopCapture,
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap});

  final DuplicateChoiceAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, label, sub, highlighted) = switch (action) {
      DuplicateChoiceAction.skip => (
        Icons.skip_next,
        'Skip this chapter',
        "Keep what's on the device, move to the next",
        false,
      ),
      DuplicateChoiceAction.redownload => (
        Icons.download,
        'Download again',
        'Replaces the local copy when it finishes',
        true,
      ),
      DuplicateChoiceAction.retryMissing => (
        Icons.download,
        'Fetch only the missing images',
        'Leaves the saved images alone',
        true,
      ),
      DuplicateChoiceAction.restartChapter => (
        Icons.restart_alt,
        'Start this chapter over',
        'The earlier attempt found no images',
        true,
      ),
      DuplicateChoiceAction.stopCapture => (
        Icons.stop_circle,
        'Stop the run',
        'Keeps everything captured so far',
        false,
      ),
    };

    return Material(
      color: highlighted ? const Color(0xFFEAF1F4) : const Color(0xFFF5F3EF),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFD2E2E8)
                  : const Color(0xFFE7E3DC),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: highlighted
                    ? const Color(0xFF35606F)
                    : const Color(0xFF5F5B54),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontVariations: wght(500),
                        fontWeight: FontWeight.w500,
                        color: highlighted
                            ? const Color(0xFF133845)
                            : const Color(0xFF1B1A18),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF5F5B54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

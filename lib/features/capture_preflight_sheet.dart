import 'package:flutter/material.dart';

import '../capture/capture_preflight.dart';

/// What the user chose when told a chapter already exists.
enum PreflightChoice {
  captureNow,
  openExisting,
  captureFollowing,
  redownload,
  retryMissing,
  restartCapture,
  repair,
  removeRecord,
  resumeJob,
  discardJobAndRestart,
  cancel,
}

class PreflightDecision {
  const PreflightDecision(this.choice, {this.policy, this.chapterLimit});

  final PreflightChoice choice;
  final DuplicatePolicy? policy;
  final int? chapterLimit;
}

/// Explains what already exists and asks what to do about it.
///
/// The whole point of this screen: the app used to log "already captured" and
/// silently do nothing, which looks identical to a broken capture. Anything
/// that changes or skips the user's content should say so and offer a choice.
Future<PreflightDecision?> showCapturePreflightSheet({
  required BuildContext context,
  required ChapterPreflight preflight,
  required int requestedCount,
  RangePreflight? range,
}) {
  return showModalBottomSheet<PreflightDecision>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: _PreflightBody(
          preflight: preflight,
          requestedCount: requestedCount,
          range: range,
        ),
      ),
    ),
  );
}

class _PreflightBody extends StatelessWidget {
  const _PreflightBody({
    required this.preflight,
    required this.requestedCount,
    this.range,
  });

  final ChapterPreflight preflight;
  final int requestedCount;
  final RangePreflight? range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, body) = switch (preflight.state) {
      ChapterLocalState.complete => (
        'This chapter is already available offline.',
        'You can open it, capture what comes after it, or download it again.',
      ),
      ChapterLocalState.partial => (
        'This chapter was captured incompletely.',
        'Some images are missing. You can retry just those, start the capture '
            'over, or read what was saved.',
      ),
      ChapterLocalState.failed => (
        'This chapter failed to capture.',
        'Nothing usable was stored last time. Capturing again will start from '
            'scratch.',
      ),
      ChapterLocalState.filesMissing => (
        'The saved files for this chapter are missing.',
        'It is listed in your library, but the images are not on disk, so it '
            'cannot be read offline.',
      ),
      ChapterLocalState.inActiveJob => (
        'Another capture already covers this chapter.',
        'Running two captures over the same chapter at once would have them '
            'fight over the same files.',
      ),
      ChapterLocalState.none => ('Start capture', ''),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 12)),
        ],
        if (preflight.chapter != null) ...[
          const SizedBox(height: 8),
          Text(
            '${preflight.chapter!.chapterLabel ?? preflight.chapter!.title}  ·  '
            '${preflight.chapter!.storedImageCount}/'
            '${preflight.chapter!.detectedImageCount} images',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],

        if (range != null && range!.hasExisting) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in range!.lines)
                  Text(line, style: const TextStyle(fontSize: 12)),
                if (range!.knownCount < requestedCount)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Only ${range!.knownCount} of $requestedCount could be '
                      'checked in advance; the rest are decided as they are '
                      'reached.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),
        ..._actionsFor(context),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pop(
              context,
              const PreflightDecision(PreflightChoice.cancel),
            ),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  List<Widget> _actionsFor(BuildContext context) {
    void choose(
      PreflightChoice choice, {
      DuplicatePolicy? policy,
      int? limit,
    }) => Navigator.pop(
      context,
      PreflightDecision(choice, policy: policy, chapterLimit: limit),
    );

    switch (preflight.state) {
      case ChapterLocalState.complete:
        return [
          _Action(
            icon: Icons.menu_book,
            label: 'Open saved chapter',
            onTap: () => choose(PreflightChoice.openExisting),
          ),
          _Action(
            icon: Icons.skip_next,
            label: 'Capture following chapters',
            // The stated rule, shown rather than implied: the count is new
            // capture attempts, so an already-saved starting chapter does not
            // eat one of them.
            detail: requestedCount == 1
                ? 'Attempts the next chapter after this one.'
                : 'Attempts the next $requestedCount chapters after this one, '
                      'skipping ones already saved.',
            primary: true,
            onTap: () => choose(
              PreflightChoice.captureFollowing,
              policy: DuplicatePolicy.skipComplete,
            ),
          ),
          _Action(
            icon: Icons.refresh,
            label: 'Re-download this chapter',
            detail:
                'Keeps the current copy until the new one succeeds. '
                'Reading progress is preserved.',
            onTap: () => choose(
              PreflightChoice.redownload,
              policy: DuplicatePolicy.replaceAll,
            ),
          ),
          if (range != null && range!.hasExisting)
            _Action(
              icon: Icons.replay_circle_filled,
              label: 'Re-download all in range',
              onTap: () => choose(
                PreflightChoice.captureFollowing,
                policy: DuplicatePolicy.replaceAll,
              ),
            ),
        ];

      case ChapterLocalState.partial:
        return [
          _Action(
            icon: Icons.download_done,
            label: 'Retry missing files',
            detail: 'Keeps what was stored and re-attempts the rest.',
            primary: true,
            onTap: () => choose(
              PreflightChoice.retryMissing,
              policy: DuplicatePolicy.retryPartial,
            ),
          ),
          _Action(
            icon: Icons.restart_alt,
            label: 'Restart chapter capture',
            detail: 'Clean replacement. Reading progress is kept.',
            onTap: () => choose(
              PreflightChoice.restartCapture,
              policy: DuplicatePolicy.replaceAll,
            ),
          ),
          _Action(
            icon: Icons.menu_book,
            label: 'Open partial chapter',
            onTap: () => choose(PreflightChoice.openExisting),
          ),
        ];

      case ChapterLocalState.failed:
        return [
          _Action(
            icon: Icons.restart_alt,
            label: 'Capture this chapter',
            primary: true,
            onTap: () => choose(
              PreflightChoice.restartCapture,
              policy: DuplicatePolicy.retryPartial,
            ),
          ),
        ];

      case ChapterLocalState.filesMissing:
        return [
          _Action(
            icon: Icons.build,
            label: 'Repair capture',
            detail: 'Download the chapter again into the same library entry.',
            primary: true,
            onTap: () => choose(
              PreflightChoice.repair,
              policy: DuplicatePolicy.replaceAll,
            ),
          ),
          _Action(
            icon: Icons.delete_outline,
            label: 'Remove broken local record',
            detail: 'Deletes the library entry. Reading history goes with it.',
            danger: true,
            onTap: () async {
              final ok = await _confirmDestructive(context);
              if (ok && context.mounted) choose(PreflightChoice.removeRecord);
            },
          ),
        ];

      case ChapterLocalState.inActiveJob:
        return [
          _Action(
            icon: Icons.play_arrow,
            label: 'Resume existing capture',
            primary: true,
            onTap: () => choose(PreflightChoice.resumeJob),
          ),
          _Action(
            icon: Icons.restart_alt,
            label: 'Discard it and start over',
            danger: true,
            onTap: () => choose(PreflightChoice.discardJobAndRestart),
          ),
        ];

      case ChapterLocalState.none:
        return [
          _Action(
            icon: Icons.download,
            label: 'Capture',
            primary: true,
            onTap: () => choose(PreflightChoice.captureNow),
          ),
        ];
    }
  }

  Future<bool> _confirmDestructive(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this chapter record?'),
        content: const Text(
          'The library entry and its reading history are deleted. This cannot '
          'be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.primary = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger ? theme.colorScheme.error : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: primary
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      if (detail != null)
                        Text(
                          detail!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
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

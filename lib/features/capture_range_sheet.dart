import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/device_storage.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';

/// What the user chose in the capture range sheet.
class CaptureRangeChoice {
  const CaptureRangeChoice(this.mode, {this.count = 1});
  final CaptureRangeMode mode;

  /// Meaningful for [CaptureRangeMode.fixedCount] only.
  final int count;
}

/// The three capture ranges — exactly three, no count presets.
///
/// "Number of chapters" takes a typed positive integer (new capture
/// attempts; skipped existing chapters do not consume it). "Until the end"
/// follows the chain to a confirmed end, bounded by the internal safety
/// limit. Both show what disk space the run can expect to use.
Future<CaptureRangeChoice?> showCaptureRangeSheet({
  required BuildContext context,
  required CaptureConfig config,
  required DeviceStorage deviceStorage,
  String currentTitle = '',
}) async {
  final free = await deviceStorage.freeBytes();
  if (!context.mounted) return null;

  // Not enough room for even one chapter: say so and refuse here, before a
  // job exists — the job would refuse anyway, but a dead-on-arrival queue
  // entry teaches the user nothing.
  if (free != null && free < config.minFreeSpaceToStart) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.sd_card_alert, color: Color(0xFF8E3B31)),
        title: const Text('Not enough space'),
        content: Text(
          '${_gb(free)} available — capturing needs at least '
          '${_gb(config.minFreeSpaceToStart)} free. Existing downloads are '
          'not affected. Free some space, or remove offline chapters you '
          'have finished.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return null;
  }

  return showModalBottomSheet<CaptureRangeChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RangeSheet(
      config: config,
      freeBytes: free,
      currentTitle: currentTitle,
    ),
  );
}

class _RangeSheet extends StatefulWidget {
  const _RangeSheet({
    required this.config,
    required this.freeBytes,
    required this.currentTitle,
  });

  final CaptureConfig config;
  final int? freeBytes;
  final String currentTitle;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  // A harmless editable default, not a preset: the field is focused and
  // fully replaceable, and nothing is enqueued until the user confirms.
  final _countField = TextEditingController(text: '2');
  bool _countMode = false;
  String? _countError;

  @override
  void dispose() {
    _countField.dispose();
    super.dispose();
  }

  int? get _parsedCount {
    final raw = _countField.text.trim();
    final n = int.tryParse(raw);
    if (n == null || '$n' != raw) return null; // rejects decimals, junk
    return n;
  }

  void _confirmCount() {
    final n = _parsedCount;
    if (n == null || n < 1) {
      setState(() => _countError = 'Enter a whole number of 1 or more.');
      return;
    }
    if (n > widget.config.maxChaptersPerJob) {
      setState(
        () => _countError =
            'At most ${widget.config.maxChaptersPerJob} chapters per run.',
      );
      return;
    }
    Navigator.pop(
      context,
      CaptureRangeChoice(CaptureRangeMode.fixedCount, count: n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final free = widget.freeBytes;
    final n = _parsedCount;
    final estimate = (n ?? 0) * widget.config.unknownChapterEstimate;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capture chapters', style: serifStyle(size: 20)),
            if (widget.currentTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Starting from: ${widget.currentTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: monoStyle(size: 11.5, color: const Color(0xFF5F5B54)),
              ),
            ],
            const SizedBox(height: 14),
            if (!_countMode) ...[
              _RangeOption(
                icon: Icons.article,
                title: 'Current chapter',
                sub: 'Only the chapter open in the browser',
                onTap: () => Navigator.pop(
                  context,
                  const CaptureRangeChoice(CaptureRangeMode.currentChapter),
                ),
              ),
              const SizedBox(height: 7),
              _RangeOption(
                icon: Icons.tag,
                title: 'Number of chapters',
                sub: 'Capture a count of new chapters from here',
                onTap: () => setState(() => _countMode = true),
              ),
              const SizedBox(height: 7),
              _RangeOption(
                icon: Icons.all_inclusive,
                title: 'Until the end',
                sub:
                    'Follow next-chapter links to the end of the series '
                    '(safety limit: ${widget.config.untilEndSafetyLimit})',
                onTap: () => Navigator.pop(
                  context,
                  const CaptureRangeChoice(CaptureRangeMode.untilEnd),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                free == null
                    ? 'Free space could not be checked — it will be checked '
                          'again before each chapter.'
                    : 'Available: ${_gb(free)}. Space is re-checked before '
                          'every chapter.',
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: Color(0xFF8C877E),
                ),
              ),
            ] else ...[
              TextField(
                controller: _countField,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() => _countError = null),
                onSubmitted: (_) => _confirmCount(),
                decoration: InputDecoration(
                  labelText: 'How many new chapters?',
                  helperText:
                      'New captures only — already saved chapters that get '
                      'skipped do not use up this number.',
                  helperMaxLines: 3,
                  errorText: _countError,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              if (n != null && n >= 1 && n <= widget.config.maxChaptersPerJob)
                Text(
                  'Capture $n new chapter${n == 1 ? '' : 's'}'
                  '${widget.currentTitle.isNotEmpty ? ' starting from "${widget.currentTitle}"' : ''}. '
                  'Estimated space: up to ~${_gb(estimate)}'
                  '${free != null ? ' · available ${_gb(free)}' : ''}.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Color(0xFF5F5B54),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirmCount,
                      child: const Text('Start capture'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _countMode = false),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RangeOption extends StatelessWidget {
  const _RangeOption({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF5F3EF),
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E3DC)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF35606F)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontVariations: wght(500),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
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

String _gb(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  return '${(bytes / (1024 * 1024)).round()} MB';
}

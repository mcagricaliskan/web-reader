import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/device_storage.dart';
import '../ui/palette.dart';
import '../ui/status_style.dart';
import '../ui/theme.dart';

/// What the user asked the capture sheet to do (D58).
///
/// Both launches are offered in the sheet itself, next to the range that was
/// just chosen — there is no second drawer asking "queue or start?", because
/// that question is part of the same decision.
enum CaptureSheetAction {
  /// Save it for later. Nothing navigates, nothing starts, the user stays on
  /// the page they were reading.
  addToQueue,

  /// Capture now, in the Browser that is already on screen.
  startNow,

  /// The Browser is busy: show what is already running instead.
  viewActiveTask,
}

/// What the user chose in the capture range sheet.
class CaptureRangeChoice {
  const CaptureRangeChoice(this.mode, {this.count = 1, required this.action});

  final CaptureRangeMode mode;

  /// Meaningful for [CaptureRangeMode.fixedCount] only.
  final int count;

  /// Which of the two launches was pressed. Carried by the caller through the
  /// duplicate preflight, so "Start Capture" that turns into "Re-download"
  /// still starts, and a queued request that turns into a re-download still
  /// waits (D58).
  final CaptureSheetAction action;
}

/// The three capture ranges — exactly three, no count presets — and the two
/// things that can be done with the chosen range.
///
/// "Number of chapters" takes a typed positive integer (new capture
/// attempts; skipped existing chapters do not consume it). "Until the end"
/// follows the chain to a confirmed end, bounded by the internal safety
/// limit. Both show what disk space the run can expect to use.
///
/// [busyLabel] names whatever already owns the Browser. When it is set, direct
/// start is not on offer at all — queueing still is, because queueing starts
/// nothing and so cannot conflict with anything.
Future<CaptureRangeChoice?> showCaptureRangeSheet({
  required BuildContext context,
  required CaptureConfig config,
  required DeviceStorage deviceStorage,
  String currentTitle = '',
  String? busyLabel,
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
        icon: Icon(Icons.sd_card_alert, color: AppPalette.of(context).danger),
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
      busyLabel: busyLabel,
    ),
  );
}

class _RangeSheet extends StatefulWidget {
  const _RangeSheet({
    required this.config,
    required this.freeBytes,
    required this.currentTitle,
    required this.busyLabel,
  });

  final CaptureConfig config;
  final int? freeBytes;
  final String currentTitle;
  final String? busyLabel;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  // A harmless editable default, not a preset: the field is focused and
  // fully replaceable, and nothing is enqueued until the user confirms.
  final _countField = TextEditingController(text: '2');
  CaptureRangeMode _mode = CaptureRangeMode.currentChapter;
  String? _countError;

  /// Set the moment an action is taken, so a second tap on either button
  /// cannot launch the same request twice while the first is being handled.
  bool _busy = false;

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

  /// Validate the typed count when it is the chosen range. Returns null and
  /// leaves the error on screen when the sheet must stay open.
  int? _validatedCount() {
    if (_mode != CaptureRangeMode.fixedCount) return 1;
    final n = _parsedCount;
    if (n == null || n < 1) {
      setState(() => _countError = 'Enter a whole number of 1 or more.');
      return null;
    }
    if (n > widget.config.maxChaptersPerJob) {
      setState(
        () => _countError =
            'At most ${widget.config.maxChaptersPerJob} chapters per run.',
      );
      return null;
    }
    return n;
  }

  void _submit(CaptureSheetAction action) {
    if (_busy) return;
    final count = _validatedCount();
    if (count == null) return;
    setState(() => _busy = true);
    Navigator.pop(
      context,
      CaptureRangeChoice(_mode, count: count, action: action),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final free = widget.freeBytes;
    final n = _parsedCount;
    final estimate = (n ?? 0) * widget.config.unknownChapterEstimate;
    final busy = widget.busyLabel;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              Text(
                'Capture chapters',
                style: serifStyle(size: 20, color: palette.ink),
              ),
              if (widget.currentTitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Starting from: ${widget.currentTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(size: 11.5, color: palette.inkMuted),
                ),
              ],
              const SizedBox(height: 14),
              _RangeOption(
                icon: Icons.article,
                title: 'Current chapter',
                sub: 'Only the chapter open in the browser',
                selected: _mode == CaptureRangeMode.currentChapter,
                onTap: () =>
                    setState(() => _mode = CaptureRangeMode.currentChapter),
              ),
              const SizedBox(height: 7),
              _RangeOption(
                icon: Icons.tag,
                title: 'Number of chapters',
                sub: 'Capture a count of new chapters from here',
                selected: _mode == CaptureRangeMode.fixedCount,
                onTap: () => setState(() {
                  _mode = CaptureRangeMode.fixedCount;
                  _countError = null;
                }),
              ),
              if (_mode == CaptureRangeMode.fixedCount) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _countField,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() => _countError = null),
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
                if (n != null &&
                    n >= 1 &&
                    n <= widget.config.maxChaptersPerJob) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Capture $n new chapter${n == 1 ? '' : 's'}'
                    '${widget.currentTitle.isNotEmpty ? ' starting from "${widget.currentTitle}"' : ''}. '
                    'Estimated space: up to ~${_gb(estimate)}'
                    '${free != null ? ' · available ${_gb(free)}' : ''}.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: palette.inkMuted,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 7),
              _RangeOption(
                icon: Icons.all_inclusive,
                title: 'Until the end',
                sub:
                    'Follow next-chapter links to the end of the series '
                    '(safety limit: ${widget.config.untilEndSafetyLimit})',
                selected: _mode == CaptureRangeMode.untilEnd,
                onTap: () => setState(() => _mode = CaptureRangeMode.untilEnd),
              ),
              const SizedBox(height: 12),
              Text(
                free == null
                    ? 'Free space could not be checked — it will be checked '
                          'again before each chapter.'
                    : 'Available: ${_gb(free)}. Space is re-checked before '
                          'every chapter.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: palette.inkFaint,
                ),
              ),
              const SizedBox(height: 12),
              if (busy != null)
                _BusyNote(label: busy)
              else
                Text(
                  'Start Capture opens and uses the current Browser now.\n'
                  'Add to Queue saves it for later.',
                  key: const ValueKey('captureLaunchExplainer'),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: palette.inkFaint,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('captureAddToQueue'),
                      onPressed: _busy
                          ? null
                          : () => _submit(CaptureSheetAction.addToQueue),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        foregroundColor: palette.inkStrong,
                        side: BorderSide(color: palette.borderStrong),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Add to Queue',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: busy != null
                        ? FilledButton(
                            key: const ValueKey('captureViewActiveTask'),
                            onPressed: _busy
                                ? null
                                : () => _submit(
                                    CaptureSheetAction.viewActiveTask,
                                  ),
                            style: _primaryStyle,
                            child: const Text(
                              'View active task',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13.5),
                            ),
                          )
                        : FilledButton(
                            key: const ValueKey('captureStartNow'),
                            onPressed: _busy
                                ? null
                                : () => _submit(CaptureSheetAction.startNow),
                            style: _primaryStyle,
                            child: const Text(
                              'Start Capture',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13.5),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('captureSheetCancel'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final ButtonStyle _primaryStyle = FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

/// Why direct start is not on offer, without hiding the queue action behind
/// the same explanation.
class _BusyNote extends StatelessWidget {
  const _BusyNote({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      key: const ValueKey('captureBusyNote'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.warnContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.warnBorder),
      ),
      child: Text(
        '$label. Only one capture can use the Browser at a time — this '
        'request can still wait in the queue.',
        style: TextStyle(
          fontSize: 11.5,
          height: 1.45,
          color: palette.onWarnContainer,
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
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: selected ? palette.primaryContainer : palette.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? palette.primaryBorder : palette.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: palette.primary),
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
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 19, color: palette.primary),
            ],
          ),
        ),
      ),
    );
  }
}

String _gb(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  return '${(bytes / (1024 * 1024)).round()} MB';
}

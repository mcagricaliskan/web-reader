import 'package:flutter/material.dart';

import '../reading/reading_position.dart';
import '../storage/database.dart';
import 'theme.dart';

/// The two status vocabularies the design keeps strictly apart.
///
/// Capture state answers "is this on the device" and never uses a checkmark.
/// Read state owns the checkmark and nothing else does. Mixing them is the
/// single worst thing this UI could do, so they live in one file where the
/// separation is visible.

// ─── capture state ──────────────────────────────────────────────────────────

class CaptureLook {
  const CaptureLook(this.icon, this.color, this.label, {this.dimTitle = false});

  final IconData icon;
  final Color color;
  final String label;

  /// Rows whose content is not readable are greyed rather than shouted at.
  final bool dimTitle;
}

const _primary = Color(0xFF35606F);
const _warn = Color(0xFF8A5A1F);
const _error = Color(0xFF8E3B31);
const _muted = Color(0xFFB3ADA3);

/// Presentation for a chapter's capture state. [filesMissing] is decided by
/// the caller (the manifest is on disk but its images are not), because the
/// database has no such status — the files simply stopped existing.
CaptureLook captureLook(Chapter chapter, {bool filesMissing = false}) {
  if (filesMissing) {
    return const CaptureLook(
      Icons.folder_off,
      _error,
      'Files missing',
      dimTitle: true,
    );
  }
  return switch (chapter.captureStatus) {
    'knownRemote' => const CaptureLook(Icons.cloud, _muted, 'On source only'),
    'complete' => const CaptureLook(
      Icons.download_for_offline,
      _primary,
      'Saved offline',
    ),
    'partial' => const CaptureLook(Icons.arrow_circle_down, _warn, 'Partial'),
    'capturing' => const CaptureLook(Icons.downloading, _primary, 'Capturing'),
    _ => const CaptureLook(Icons.error, _error, 'Failed', dimTitle: true),
  };
}

/// The capture glyph on its own — 22px, matching the chapter rows.
class CaptureGlyph extends StatelessWidget {
  const CaptureGlyph(this.look, {super.key, this.size = 22});

  final CaptureLook look;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(look.icon, size: size, color: look.color);
}

// ─── read state ─────────────────────────────────────────────────────────────

/// Read-state indicator. Unread is a small filled dot, in-progress a partial
/// ring with its percentage beside it, finished a hollow check.
class ReadGlyph extends StatelessWidget {
  const ReadGlyph({super.key, required this.chapter});

  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final status = readStatusFromName(chapter.readStatus);
    final pct = (chapter.progressFraction * 100).clamp(0, 100).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == ReadStatus.inProgress)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              '$pct%',
              style: const TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontSize: 11,
                color: Color(0xFF5F5B54),
              ),
            ),
          ),
        switch (status) {
          ReadStatus.unread => Icon(
            Icons.circle,
            key: ValueKey('unreadDot-${chapter.id}'),
            size: 9,
            color: _primary,
          ),
          ReadStatus.inProgress => const Icon(
            Icons.incomplete_circle,
            size: 19,
            color: Color(0xFF5F5B54),
          ),
          ReadStatus.completed => const Icon(
            Icons.check_circle_outline,
            size: 19,
            color: Color(0xFFA39D93),
          ),
        },
      ],
    );
  }
}

// ─── update-check state ─────────────────────────────────────────────────────

/// How a series' update-check state reads on its library row. "Never checked"
/// is its own state and must never render as "no new chapters".
class CheckLook {
  const CheckLook(this.icon, this.label, this.bg, this.fg, this.border);

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final Color border;
}

const _pc = Color(0xFFEAF1F4);
const _pcb = Color(0xFFD2E2E8);
const _onPc = Color(0xFF133845);
const _neutralBg = Color(0xFFF3F1ED);
const _neutralBd = Color(0xFFE4E0D8);
const _osv = Color(0xFF5F5B54);

CheckLook checkLook({
  required bool checking,
  required bool failed,
  required DateTime? checkedAt,
  required int newCount,
  required String checkedLabel,
}) {
  if (checking) {
    return const CheckLook(Icons.sync, 'Checking', _pc, _onPc, _pcb);
  }
  if (failed) {
    return const CheckLook(
      Icons.sync_problem,
      'Check failed',
      Color(0xFFF7DDD8),
      Color(0xFF4A140E),
      Color(0xFFEBC4BC),
    );
  }
  if (checkedAt == null) {
    return const CheckLook(
      Icons.history_toggle_off,
      'Not checked yet',
      _neutralBg,
      _osv,
      _neutralBd,
    );
  }
  if (newCount > 0) {
    return CheckLook(Icons.cloud, '$newCount new', _pc, _onPc, _pcb);
  }
  return CheckLook(
    Icons.update,
    'Checked $checkedLabel',
    _neutralBg,
    _osv,
    _neutralBd,
  );
}

/// A small pill: icon + label, used for check state and for run phase.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
    this.iconSize = 13,
  });

  final IconData icon;
  final String label;
  final Color bg, fg, border;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: fg),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontVariations: wght(500),
            fontWeight: FontWeight.w500,
            color: fg,
          ),
        ),
      ],
    ),
  );
}

// ─── shared small pieces ────────────────────────────────────────────────────

/// The rounded monogram tile that stands in for cover art.
class MonogramTile extends StatelessWidget {
  const MonogramTile({
    super.key,
    required this.id,
    required this.title,
    this.size = 44,
    this.radius = 12,
    this.fontSize = 15,
  });

  final String id;
  final String title;
  final double size;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = monogramFor(id);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        monogramText(title),
        style: TextStyle(
          fontFamily: 'Newsreader',
          fontSize: fontSize,
          fontVariations: wght(600),
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// Uppercase section label, optionally with something on the right.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 6),
  });

  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 0.84,
              fontVariations: [FontVariation('wght', 600)],
              fontWeight: FontWeight.w600,
              color: _osv,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Monospace metadata line.
TextStyle monoStyle({
  double size = 11,
  Color color = const Color(0xFF7A756C),
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  fontFamily: 'IBM Plex Mono',
  fontSize: size,
  fontWeight: weight,
  color: color,
);

/// Serif display/title style.
TextStyle serifStyle({
  double size = 28,
  Color color = const Color(0xFF1B1A18),
}) => TextStyle(
  fontFamily: 'Newsreader',
  fontSize: size,
  height: 1.18,
  letterSpacing: -0.28,
  fontVariations: wght(500),
  fontWeight: FontWeight.w500,
  color: color,
);

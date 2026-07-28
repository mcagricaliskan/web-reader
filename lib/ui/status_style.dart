import 'dart:math' as math;

import '../core/device_storage.dart';

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
  // A chapter whose files the USER removed is not an error and not a
  // discovery — it is a known chapter that simply is not downloaded.
  if (chapter.contentPath == null && chapter.offlineRemovedAt != null) {
    return const CaptureLook(Icons.cloud, _muted, 'Not downloaded');
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
// ─── storage ────────────────────────────────────────────────────────────────

/// The colours one storage reading wears, everywhere it appears.
///
/// Driven by the **percentage of the device in use**, not by the app's own
/// share and not by free bytes alone (D51). One palette, one source, so the
/// Library pill and the Storage screen can never disagree about how worried
/// to look.
class StorageLook {
  const StorageLook({
    required this.ink,
    required this.track,
    required this.fill,
    required this.bg,
    required this.border,
    required this.label,
  });

  /// Text and glyph colour.
  final Color ink;

  /// Meter background and its filled portion.
  final Color track, fill;

  /// Card background and border, for the surfaces that have one.
  final Color bg, border;

  /// One word for what this level means.
  final String label;
}

StorageLook storageLook(StorageLevel level) => switch (level) {
  StorageLevel.critical => const StorageLook(
    ink: Color(0xFF8E3B31),
    track: Color(0xFFEBC4BC),
    fill: Color(0xFFB4483A),
    bg: Color(0xFFF7DDD8),
    border: Color(0xFFEBC4BC),
    label: 'Almost full',
  ),
  StorageLevel.warning => const StorageLook(
    ink: Color(0xFF8A5A1F),
    track: Color(0xFFE8D5B2),
    fill: Color(0xFFC08A3E),
    bg: Color(0xFFF8EEDA),
    border: Color(0xFFE8D5B2),
    label: 'Filling up',
  ),
  // Quiet by belonging: the same ink as every other header glyph.
  StorageLevel.normal => const StorageLook(
    ink: kHeaderIconColor,
    track: Color(0xFFE7E3DC),
    fill: Color(0xFF35606F),
    bg: Color(0xFFF3F1ED),
    border: Color(0xFFE7E3DC),
    label: 'Healthy',
  ),
  StorageLevel.unknown => const StorageLook(
    ink: kHeaderIconColor,
    track: Color(0xFFE7E3DC),
    fill: Color(0xFFC4BFB5),
    bg: Color(0xFFF3F1ED),
    border: Color(0xFFE7E3DC),
    label: 'Unavailable',
  ),
};

// ─── screen header ──────────────────────────────────────────────────────────

/// Every action in a screen header is exactly this box, with exactly this
/// glyph inside it, in exactly this colour.
///
/// One definition, because the alternative was what the Library header had:
/// three 48pt `IconButton`s with 22pt glyphs beside a 40pt pill with a 15pt
/// glyph, bottom-aligned — so the pill's centre sat 4pt below every icon's
/// centre and its glyph read as a different family. Anything that joins this
/// row must be [kHeaderActionSize] tall and use [kHeaderIconSize].
const double kHeaderActionSize = 40;
const double kHeaderIconSize = 22;
const Color kHeaderIconColor = Color(0xFF5F5B54);

/// A header action. Deliberately tighter than a stock [IconButton] (48pt):
/// four actions plus a 28pt serif title do not fit across a 320pt screen at
/// the default size, and the title is what loses — it wrapped to three lines.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox.square(
      dimension: kHeaderActionSize,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(icon, size: kHeaderIconSize, color: kHeaderIconColor),
        ),
      ),
    ),
  );
}

/// The episode list's progress pie, driven by the real reading fraction.
///
/// A painter rather than a set of range icons: the design's pie is a
/// continuous quantity, and bucketing it into "quarter / half / three
/// quarters" would show 51% and 74% as the same picture. One filled wedge from
/// twelve o'clock clockwise, on a quiet ring.
///
/// Cheap by construction — two `drawArc` calls, no animation, no layout — so
/// it costs nothing to have one per row in a long list.
class ChapterProgressRing extends StatelessWidget {
  const ChapterProgressRing({
    super.key,
    required this.fraction,
    required this.completed,
    this.size = 18,
  });

  /// 0..1. Callers pass [readProgressFor]'s output, so a completed chapter is
  /// already pinned at 1 (D39).
  final double fraction;

  /// Drawn as a full disc with a check, whatever [fraction] says. The two
  /// always agree in practice; if they ever disagree, "finished" is the fact
  /// the user asserted and the fraction is the one that drifted.
  final bool completed;

  final double size;

  @override
  Widget build(BuildContext context) {
    final value = completed ? 1.0 : fraction.clamp(0.0, 1.0);
    final percent = (value * 100).round();
    return Semantics(
      label: completed
          ? 'Read · 100%'
          : percent == 0
          ? 'Unread · 0%'
          : 'Reading progress $percent%',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _ProgressRingPainter(
            fraction: value,
            completed: completed,
            track: _ringTrack,
            fill: _ringFill,
          ),
        ),
      ),
    );
  }
}

/// The unfilled part of the ring: present at 0% so an unread chapter reads as
/// "nothing yet", not as "no indicator".
const Color _ringTrack = Color(0xFFD7D2C9);

/// The filled wedge. Near-black, per the design.
const Color _ringFill = Color(0xFF1B1A18);

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.fraction,
    required this.completed,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final bool completed;
  final Color track;
  final Color fill;

  static const double _twelveOClock = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final stroke = math.max(1.2, side * 0.1);
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (side - stroke) / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    if (completed || fraction >= 1) {
      // Finished: a solid disc. Unmistakably different from 99%.
      canvas.drawCircle(centre, radius, Paint()..color = fill);
      return;
    }
    if (fraction <= 0) return;

    // The wedge is inset by half a stroke so it sits inside the ring rather
    // than straddling it.
    final inner = radius - stroke / 2;
    if (inner <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: inner),
      _twelveOClock,
      fraction * 2 * math.pi,
      true,
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.fraction != fraction ||
      old.completed != completed ||
      old.track != track ||
      old.fill != fill;
}

class ReadGlyph extends StatelessWidget {
  const ReadGlyph({super.key, required this.chapter});

  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final status = readStatusFromName(chapter.readStatus);
    final pct =
        (readProgressFor(
                  readStatus: chapter.readStatus,
                  stored: chapter.progressFraction,
                ) *
                100)
            .round();

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
        // One component for all three states: the ring IS the state, so an
        // unread chapter cannot render as finished by picking a wrong icon.
        ChapterProgressRing(
          key: ValueKey('progressRing-${chapter.id}'),
          fraction: readProgressFor(
            readStatus: chapter.readStatus,
            stored: chapter.progressFraction,
          ),
          completed: status == ReadStatus.completed,
        ),
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

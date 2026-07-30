/// Where the reader is inside an entry, and how that survives the entry
/// changing underneath it.
///
/// Pure Dart: the restore maths is the part most likely to be subtly wrong,
/// so it is tested directly rather than only through a running reader.
library;

/// Whether the reader has finished an entry. Separate from save state —
/// an entry can be re-downloaded and stay completed.
enum ReadStatus { unread, inProgress, completed }

ReadStatus readStatusFromName(String? name) => ReadStatus.values.firstWhere(
  (s) => s.name == name,
  orElse: () => ReadStatus.unread,
);

/// The one rule for what "how far through" means: **a completed entry is
/// 100%, always.**
///
/// Reading a finished entry again scrolls its stored fraction back down —
/// the scroll position is genuinely where the reader is — but "finished" is a
/// statement about the entry, not about the current scroll. Without this,
/// re-opening a finished entry and scrolling up makes it report 40% read.
///
/// Applied on both sides: writes store 1.0 for a completed entry, and every
/// display goes through here so rows written before this rule existed read
/// correctly too.
double readProgressFor({required String? readStatus, required double stored}) =>
    readStatusFromName(readStatus) == ReadStatus.completed
    ? 1
    : stored.clamp(0.0, 1.0);

/// A hybrid position: an anchor for precision, a fraction for durability.
///
/// The anchor (`imageIndex` + `offsetInImage`) restores the exact spot but goes
/// stale when an entry is re-downloaded with a different panel count. The
/// fraction is approximate but content-independent, so it always means
/// something. Both are stored; restore prefers the anchor and falls back.
class ReadingPosition {
  const ReadingPosition({
    this.fraction = 0,
    this.imageIndex = 0,
    this.offsetInImage = 0,
  });

  /// 0..1 through the whole entry. Drives the progress bar and completion.
  final double fraction;

  /// Zero-based index of the panel at the top of the viewport.
  final int imageIndex;

  /// 0..1 down that panel.
  final double offsetInImage;

  static const ReadingPosition start = ReadingPosition();

  bool get isAtStart => fraction <= 0 && imageIndex == 0 && offsetInImage <= 0;

  @override
  String toString() =>
      'panel $imageIndex +${(offsetInImage * 100).round()}% '
      '(${(fraction * 100).round()}% of entry)';
}

/// Geometry of an entry laid out at a given width.
///
/// Panel heights come from the manifest's stored dimensions, so the list's
/// geometry is known before a single image decodes. That is what lets the
/// reader open *at* the saved position instead of jumping there after layout.
class EntryLayout {
  EntryLayout._(this.viewportWidth, this.heights, this._offsets, this.total);

  factory EntryLayout({
    required double viewportWidth,
    required List<({int? width, int? height})> panels,
    double fallbackAspectRatio = kFallbackAspectRatio,
  }) {
    final heights = <double>[];
    final offsets = <double>[];
    var running = 0.0;

    for (final panel in panels) {
      final w = panel.width ?? 0;
      final h = panel.height ?? 0;
      // A panel with no recorded size still needs a place to stand.
      final ratio = (w > 0 && h > 0) ? h / w : fallbackAspectRatio;
      final height = viewportWidth * ratio;
      offsets.add(running);
      heights.add(height);
      running += height;
    }
    return EntryLayout._(viewportWidth, heights, offsets, running);
  }

  /// Height/width used when the manifest recorded no dimensions. Tall rather
  /// than square: a tall content page is far more often long than wide, and
  /// guessing short makes the restore land past the intended spot.
  static const double kFallbackAspectRatio = 1.5;

  final double viewportWidth;
  final List<double> heights;
  final List<double> _offsets;

  /// Total scrollable content height.
  final double total;

  int get panelCount => heights.length;
  bool get isEmpty => heights.isEmpty || total <= 0;

  double heightOf(int index) =>
      (index >= 0 && index < heights.length) ? heights[index] : 0;

  double offsetOf(int index) =>
      (index >= 0 && index < _offsets.length) ? _offsets[index] : 0;

  /// Scroll offset for a saved position.
  ///
  /// Uses the anchor when the panel still exists, else maps the fraction onto
  /// the current content height — which is why a re-download with a different
  /// panel count still lands somewhere sensible.
  double offsetForPosition(ReadingPosition position) {
    if (isEmpty) return 0;
    if (position.imageIndex >= 0 && position.imageIndex < panelCount) {
      final base = offsetOf(position.imageIndex);
      final within =
          heightOf(position.imageIndex) *
          position.offsetInImage.clamp(0.0, 1.0);
      return (base + within).clamp(0.0, total);
    }
    return (position.fraction.clamp(0.0, 1.0) * total).clamp(0.0, total);
  }

  /// The inverse: turn a live scroll offset back into a saved position.
  ReadingPosition positionForOffset(
    double offset, {
    double viewportHeight = 0,
  }) {
    if (isEmpty) return ReadingPosition.start;
    final clamped = offset.clamp(0.0, total);

    var index = 0;
    while (index + 1 < panelCount && _offsets[index + 1] <= clamped) {
      index++;
    }
    final within = heights[index] <= 0
        ? 0.0
        : ((clamped - _offsets[index]) / heights[index]).clamp(0.0, 1.0);

    // Progress counts the *bottom* of the viewport: a reader who can see the
    // last panel in full has finished, even though the scroll offset stops one
    // screen short of the content height.
    final scrollable = (total - viewportHeight);
    final fraction = scrollable <= 0
        ? 1.0
        : (clamped / scrollable).clamp(0.0, 1.0);

    return ReadingPosition(
      fraction: fraction,
      imageIndex: index,
      offsetInImage: within,
    );
  }
}

/// Rules for when an entry counts as finished.
class CompletionPolicy {
  const CompletionPolicy({
    this.threshold = 0.97,
    this.dwell = const Duration(milliseconds: 800),
  });

  /// How far through counts as the end. Not 1.0: a trailing comments section
  /// or a last panel taller than the viewport would otherwise make an entry
  /// impossible to finish.
  final double threshold;

  /// How long the reader must stay past the threshold. Stops a fast fling to
  /// the bottom from silently marking an entry read.
  final Duration dwell;

  bool reachedEnd(double fraction) => fraction >= threshold;
}

const kDefaultCompletionPolicy = CompletionPolicy();

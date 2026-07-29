import '../reading/reading_position.dart';
import '../reading/reading_repository.dart';
import '../storage/database.dart';
import 'library_screen.dart' show SeriesGroup;

/// One row of Continue Reading / Recently Read: which series, which chapter to
/// open, and the reading state behind that choice.
class ContinueEntry {
  const ContinueEntry({
    required this.group,
    required this.chapter,
    required this.state,
  });

  final SeriesGroup group;

  /// The chapter tapping this opens — the unfinished one, else the next
  /// unread, else (for Recently Read) the last completed.
  final Chapter chapter;
  final SeriesReadingState state;

  String get displayName => group.displayName;

  String get chapterLabel {
    final label = chapter.chapterLabel;
    return (label != null && label.isNotEmpty) ? label : chapter.title;
  }

  double get progress => readProgressFor(
    readStatus: chapter.readStatus,
    stored: chapter.progressFraction,
  );
  bool get isCompleted => chapter.readStatus == 'completed';
  bool get isPartialCapture => chapter.captureStatus == 'partial';
  DateTime? get lastReadAt => state.lastReadAt;

  /// Readable chapters that come *after* [chapter] in reading order.
  ///
  /// Deliberately not "how many are left in the series". A series can be added
  /// from the middle, so the local count is no evidence of what the source
  /// published; the only honest number is how much more this device holds.
  /// [SeriesReadingState.chapters] is already the readable set in reading
  /// order, so this is a position lookup, not a second filter.
  int get laterChapterCount {
    final index = state.chapters.indexWhere((c) => c.id == chapter.id);
    return index < 0 ? 0 : state.chapters.length - index - 1;
  }

  /// How [laterChapterCount] reads on a card. Nothing after this chapter is a
  /// state, not a zero — "0 chapters remaining" reads as a defect.
  String get laterChaptersLabel => switch (laterChapterCount) {
    0 => 'Latest available chapter',
    1 => '1 chapter remaining',
    final n => '$n chapters remaining',
  };
}

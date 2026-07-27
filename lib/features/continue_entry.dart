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
}

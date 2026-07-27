import 'package:drift/drift.dart' show Value;

import '../features/series_detail_screen.dart' show sortChaptersForReading;
import '../storage/database.dart';
import 'reading_position.dart';

/// Reads and writes reading state, and keeps the series pointers honest.
///
/// The invariant everything else leans on: **capture never touches reading
/// state, and reading never touches capture state.** A chapter can be
/// re-downloaded and stay exactly where the user was.
class ReadingRepository {
  ReadingRepository(this.db);

  final AppDatabase db;

  /// All writes go through one queue.
  ///
  /// Every write here is read-modify-write, and the reader flushes from four
  /// places (debounce, dwell completion, lifecycle change, dispose) without
  /// awaiting each other. Unserialized, a stale in-flight save could read
  /// "not completed", lose the race, and write over a completion that had
  /// already landed. The queue makes the outcome the call order, always —
  /// which is also what guarantees a pending write cannot clobber a newer one.
  ///
  /// Null when idle, and an idle write starts *synchronously* in the caller's
  /// zone. Not an optimisation: an unconditional `.then` hop deadlocks under
  /// a widget test's fake-async zone when awaited before the first pump.
  Future<void>? _writeQueue;

  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _writeQueue;
    final result = previous == null ? action() : previous.then((_) => action());
    Future<void>? entry;
    // Keep the chain alive even when a write fails, and let it drain so the
    // next uncontended write starts synchronously again.
    entry = result.then<void>((_) {}, onError: (_) {})
      ..whenComplete(() {
        if (identical(_writeQueue, entry)) _writeQueue = null;
      });
    _writeQueue = entry;
    return result;
  }

  // --- reading a chapter ---------------------------------------------------

  /// Opening a chapter records that it was opened. It does **not** mark it
  /// read — that would make "I glanced at it" indistinguishable from "I
  /// finished it".
  Future<void> markOpened(String chapterId) => _serialized(() async {
    final chapter = await db.chapterById(chapterId);
    if (chapter == null) return;
    final now = DateTime.now();

    await db.writeChapterReading(
      chapterId,
      ChaptersCompanion(
        firstOpenedAt: Value(chapter.firstOpenedAt ?? now),
        lastReadAt: Value(now),
        // A completed chapter that is reopened stays completed until the user
        // says otherwise.
        readStatus: Value(
          chapter.readStatus == ReadStatus.completed.name
              ? chapter.readStatus
              : ReadStatus.inProgress.name,
        ),
      ),
    );
    await _refreshSeries(chapter.libraryItemId, openedChapterId: chapterId);
  });

  Future<void> saveProgress(
    String chapterId,
    ReadingPosition position, {
    bool completed = false,
  }) => _serialized(() async {
    final chapter = await db.chapterById(chapterId);
    if (chapter == null) return;
    final now = DateTime.now();

    final alreadyCompleted = chapter.readStatus == ReadStatus.completed.name;
    final becomesCompleted = completed || alreadyCompleted;

    await db.writeChapterReading(
      chapterId,
      ChaptersCompanion(
        // The anchor keeps following the scroll — resuming a finished chapter
        // still lands where the reader actually is — but the *fraction* obeys
        // the completed-is-100% rule.
        progressFraction: Value(
          becomesCompleted ? 1.0 : position.fraction.clamp(0.0, 1.0),
        ),
        progressImageIndex: Value(position.imageIndex),
        progressOffsetInImage: Value(position.offsetInImage.clamp(0.0, 1.0)),
        lastReadAt: Value(now),
        progressUpdatedAt: Value(now),
        readStatus: Value(
          becomesCompleted
              ? ReadStatus.completed.name
              : ReadStatus.inProgress.name,
        ),
        completedAt: Value(
          becomesCompleted ? (chapter.completedAt ?? now) : null,
        ),
      ),
    );
    await _refreshSeries(chapter.libraryItemId, openedChapterId: chapterId);
  });

  /// Explicit "I have read this", regardless of where the scroll is.
  Future<void> markRead(String chapterId) => _serialized(() async {
    final chapter = await db.chapterById(chapterId);
    if (chapter == null) return;
    final now = DateTime.now();
    await db.writeChapterReading(
      chapterId,
      ChaptersCompanion(
        readStatus: Value(ReadStatus.completed.name),
        completedAt: Value(chapter.completedAt ?? now),
        lastReadAt: Value(now),
        // Jump the bar to the end so a manually-read chapter does not still
        // look half finished.
        progressFraction: const Value(1),
      ),
    );
    await _refreshSeries(chapter.libraryItemId, openedChapterId: chapterId);
  });

  /// Explicit "I have not read this".
  ///
  /// Keeps the *anchor*: the user is saying it is unfinished, not that they
  /// were never there, so resuming still lands where they got to. The
  /// fraction, though, is dropped back to zero when the chapter was
  /// completed — completion had forced it to 100% (see [readProgressFor]), so
  /// leaving it there would show a full bar on a chapter marked unread.
  Future<void> markUnread(String chapterId) => _serialized(() async {
    final chapter = await db.chapterById(chapterId);
    if (chapter == null) return;
    final wasCompleted = chapter.readStatus == ReadStatus.completed.name;
    await db.writeChapterReading(
      chapterId,
      ChaptersCompanion(
        readStatus: const Value('unread'),
        completedAt: const Value(null),
        progressFraction: wasCompleted ? const Value(0) : const Value.absent(),
        // Stamped so a progress write that was already in flight when the
        // user tapped is recognisable as the older one.
        progressUpdatedAt: Value(DateTime.now()),
      ),
    );
    await _refreshSeries(chapter.libraryItemId);
  });

  /// Bring existing rows in line with the completed-is-100% rule.
  ///
  /// Rows written before the rule existed can hold a completed chapter at any
  /// fraction. Runs at boot beside [repairSeriesReadingState]; a no-op once
  /// there is nothing left to fix.
  Future<int> repairCompletedProgress() => _serialized(() async {
    var fixed = 0;
    for (final chapter in await db.allChapters()) {
      if (chapter.readStatus != ReadStatus.completed.name) continue;
      if (chapter.progressFraction >= 1) continue;
      await db.writeChapterReading(
        chapter.id,
        const ChaptersCompanion(progressFraction: Value(1)),
      );
      fixed++;
    }
    return fixed;
  });

  ReadingPosition positionOf(Chapter chapter) => ReadingPosition(
    fraction: chapter.progressFraction,
    imageIndex: chapter.progressImageIndex,
    offsetInImage: chapter.progressOffsetInImage,
  );

  // --- series pointers -----------------------------------------------------

  /// Recompute a series' denormalised reading pointers from its chapters.
  ///
  /// Cheap (one series' rows) and always correct, so it runs after every
  /// change rather than being incrementally patched — incremental pointer
  /// maths is exactly the sort of thing that drifts out of sync.
  Future<void> _refreshSeries(
    String libraryItemId, {
    String? openedChapterId,
  }) async {
    final chapters = await db.chaptersForItem(libraryItemId);
    if (chapters.isEmpty) return;

    DateTime? lastRead;
    Chapter? lastCompleted;
    for (final c in chapters) {
      final at = c.lastReadAt;
      if (at != null && (lastRead == null || at.isAfter(lastRead))) {
        lastRead = at;
      }
      if (c.readStatus == ReadStatus.completed.name) {
        final completedAt = c.completedAt;
        if (lastCompleted == null ||
            (completedAt != null &&
                (lastCompleted.completedAt == null ||
                    completedAt.isAfter(lastCompleted.completedAt!)))) {
          lastCompleted = c;
        }
      }
    }

    // The most recently opened chapter, unless this call names one.
    String? lastOpened = openedChapterId;
    if (lastOpened == null) {
      DateTime? newest;
      for (final c in chapters) {
        final at = c.lastReadAt;
        if (at == null) continue;
        // `!isBefore` rather than `isAfter`: two writes can land in the same
        // millisecond, and on a tie the later chapter in reading order is the
        // one the reader is actually on.
        if (newest == null || !at.isBefore(newest)) {
          newest = at;
          lastOpened = c.id;
        }
      }
    }

    await db.writeSeriesReading(
      libraryItemId,
      LibraryItemsCompanion(
        lastOpenedChapterId: Value(lastOpened),
        lastCompletedChapterId: Value(lastCompleted?.id),
        lastReadAt: Value(lastRead),
      ),
    );
  }

  /// Rebuild every series' pointers. Runs after a migration or a bulk change.
  Future<void> repairSeriesReadingState() async {
    for (final item in await db.allLibraryItems()) {
      await _refreshSeries(item.id);
    }
  }
}

/// What the library needs to know about one series' reading state.
///
/// Derived rather than stored, apart from the ordering pointers: counts drift
/// the moment an edge case is missed, and at these row counts deriving is free.
class SeriesReadingState {
  const SeriesReadingState({
    required this.chapters,
    this.currentChapter,
    this.nextUnread,
    this.lastCompleted,
    this.lastReadAt,
  });

  /// Chapters that are actually readable offline, in reading order.
  final List<Chapter> chapters;

  /// The unfinished chapter to resume, if any.
  final Chapter? currentChapter;

  /// The next readable chapter the user has not finished.
  final Chapter? nextUnread;
  final Chapter? lastCompleted;
  final DateTime? lastReadAt;

  /// What "Continue Reading" should open: the unfinished chapter, else the
  /// next unread one.
  Chapter? get continueChapter => currentChapter ?? nextUnread;

  bool get hasSomethingToRead => continueChapter != null;
  bool get everOpened => lastReadAt != null;

  int get unreadCount =>
      chapters.where((c) => c.readStatus != ReadStatus.completed.name).length;

  bool get allCompleted => chapters.isNotEmpty && unreadCount == 0;

  double get currentProgress {
    final c = currentChapter;
    return c == null
        ? 0
        : readProgressFor(readStatus: c.readStatus, stored: c.progressFraction);
  }
}

/// Work out a series' reading state from its chapters.
///
/// Only locally readable chapters count. A chapter known to exist on the
/// source but not stored cannot be continued into, so offering it would send
/// the reader somewhere it cannot go.
SeriesReadingState computeSeriesReadingState(List<Chapter> allChapters) {
  final readable = sortChaptersForReading(
    allChapters
        .where(
          (c) =>
              c.contentPath != null &&
              (c.captureStatus == 'complete' || c.captureStatus == 'partial'),
        )
        .toList(),
  );

  if (readable.isEmpty) return const SeriesReadingState(chapters: []);

  DateTime? lastReadAt;
  Chapter? lastCompleted;
  for (final c in readable) {
    final at = c.lastReadAt;
    if (at != null && (lastReadAt == null || at.isAfter(lastReadAt))) {
      lastReadAt = at;
    }
    if (c.readStatus == ReadStatus.completed.name) lastCompleted = c;
  }

  // An unfinished chapter the user actually started. Most recently read wins,
  // so jumping back to an earlier chapter resumes there.
  Chapter? current;
  DateTime? currentRead;
  for (final c in readable) {
    if (c.readStatus != ReadStatus.inProgress.name) continue;
    final at = c.lastReadAt;
    if (current == null ||
        (at != null && (currentRead == null || at.isAfter(currentRead)))) {
      current = c;
      currentRead = at;
    }
  }

  // Otherwise the earliest chapter not yet finished — which after completing
  // chapter 1 is chapter 2.
  Chapter? nextUnread;
  for (final c in readable) {
    if (c.readStatus == ReadStatus.completed.name) continue;
    if (identical(c, current)) continue;
    nextUnread = c;
    break;
  }

  return SeriesReadingState(
    chapters: readable,
    currentChapter: current,
    nextUnread: nextUnread,
    lastCompleted: lastCompleted,
    lastReadAt: lastReadAt,
  );
}

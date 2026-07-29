import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/features/continue_entry.dart';
import 'package:web_reader/features/library_screen.dart' show SeriesGroup;
import 'package:web_reader/reading/reading_repository.dart';
import 'package:web_reader/storage/database.dart';

/// What a Continue card says about how much is left.
///
/// The number is always "readable chapters after this one on this device" —
/// never a series total, because a series added from the middle has no local
/// evidence of what the source published.
void main() {
  Chapter chapter(
    int n, {
    String captureStatus = 'complete',
    bool offline = true,
    String readStatus = 'unread',
    double progress = 0,
  }) => Chapter(
    id: 'c$n',
    libraryItemId: 's1',
    title: 'Series Chapter $n',
    sourceUrl: 'https://x.example/manga/s1/$n',
    urlKey: 'https://x.example/manga/s1/$n',
    captureStatus: captureStatus,
    contentPath: offline ? 'library/s1/chapters/c$n' : null,
    capturedAt: DateTime(2026, 7, 20),
    detectedImageCount: 6,
    storedImageCount: 6,
    sequence: n,
    byteSize: 1024,
    chapterNumber: n.toDouble(),
    chapterLabel: 'Chapter $n',
    readStatus: readStatus,
    progressFraction: progress,
    progressImageIndex: 0,
    progressOffsetInImage: 0,
  );

  final item = LibraryItem(
    lifecycle: 'active',
    id: 's1',
    title: 'Series',
    sourceUrl: 'https://x.example/manga/s1',
    host: 'x.example',
    seriesKey: '/manga/s1',
    createdAt: DateTime(2026, 7, 1),
  );

  ContinueEntry entryFor(List<Chapter> chapters) {
    final state = computeSeriesReadingState(chapters);
    return ContinueEntry(
      group: SeriesGroup(item: item, chapters: chapters),
      chapter: state.continueChapter!,
      state: state,
    );
  }

  test('counts only the chapters after the one being continued', () {
    final entry = entryFor([
      chapter(1, readStatus: 'inProgress', progress: 0.68),
      chapter(2),
      chapter(3),
    ]);

    expect(entry.laterChapterCount, 2);
    expect(entry.laterChaptersLabel, '2 chapters remaining');
  });

  test('one later chapter is singular', () {
    final entry = entryFor([
      chapter(1, readStatus: 'inProgress', progress: 0.1),
      chapter(2),
    ]);

    expect(entry.laterChaptersLabel, '1 chapter remaining');
  });

  test('the newest readable chapter is a state, not "0 remaining"', () {
    final entry = entryFor([
      chapter(1, readStatus: 'completed', progress: 1),
      chapter(2, readStatus: 'inProgress', progress: 0.5),
    ]);

    expect(entry.laterChapterCount, 0);
    expect(entry.laterChaptersLabel, 'Latest available chapter');
  });

  test('chapters before the current one are not counted', () {
    // Resuming an earlier chapter: the two after it are what is left, and the
    // finished one before it is not.
    final entry = entryFor([
      chapter(1, readStatus: 'inProgress', progress: 0.3),
      chapter(2, readStatus: 'completed', progress: 1),
      chapter(3),
    ]);

    expect(entry.chapter.id, 'c1');
    expect(entry.laterChaptersLabel, '2 chapters remaining');
  });

  test('chapters that cannot be opened are not "remaining"', () {
    final entry = entryFor([
      chapter(1, readStatus: 'inProgress', progress: 0.2),
      // Discovered by an update check, never captured.
      chapter(2, captureStatus: 'knownRemote', offline: false),
      // The user freed up its space (D35).
      chapter(3, offline: false),
      chapter(4, captureStatus: 'failed', offline: false),
      chapter(5),
    ]);

    expect(entry.laterChapterCount, 1);
    expect(entry.laterChaptersLabel, '1 chapter remaining');
  });

  test('a partially captured chapter still counts — it can be read', () {
    final entry = entryFor([
      chapter(1, readStatus: 'inProgress', progress: 0.4),
      chapter(2, captureStatus: 'partial'),
    ]);

    expect(entry.laterChaptersLabel, '1 chapter remaining');
  });
}

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser/browser_controller.dart';
import 'capture/capture_job.dart';
import 'capture/rule_repository.dart';
import 'features/continue_entry.dart';
import 'features/library_screen.dart' show SeriesGroup;
import 'library/library_sort.dart';
import 'library/series_repository.dart';
import 'library/update_checker.dart';
import 'queue/task_queue.dart';
import 'reading/reading_repository.dart';
import 'capture/site_rule.dart';
import 'storage/database.dart';
import 'storage/file_store.dart';

/// Set once during bootstrap, before `runApp`.
class AppServices {
  AppServices({
    required this.db,
    required this.fileStore,
    required this.browser,
    required this.captureJob,
    UpdateChecker? updateChecker,
    TaskQueueController? taskQueue,
  }) : updateChecker =
           updateChecker ?? UpdateChecker(browser: browser, db: db) {
    this.taskQueue =
        taskQueue ??
        TaskQueueController(
          db: db,
          browser: browser,
          captureJob: captureJob,
          checker: this.updateChecker,
        );
  }

  final AppDatabase db;
  final FileStore fileStore;
  final BrowserController browser;
  final CaptureJobController captureJob;
  final UpdateChecker updateChecker;
  late final TaskQueueController taskQueue;
}

final appServicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

final databaseProvider = Provider<AppDatabase>(
  (ref) => ref.watch(appServicesProvider).db,
);

final fileStoreProvider = Provider<FileStore>(
  (ref) => ref.watch(appServicesProvider).fileStore,
);

final browserProvider = Provider<BrowserController>(
  (ref) => ref.watch(appServicesProvider).browser,
);

final captureJobProvider = Provider<CaptureJobController>(
  (ref) => ref.watch(appServicesProvider).captureJob,
);

final updateCheckerProvider = Provider<UpdateChecker>(
  (ref) => ref.watch(appServicesProvider).updateChecker,
);

final taskQueueProvider = Provider<TaskQueueController>(
  (ref) => ref.watch(appServicesProvider).taskQueue,
);

/// The queue as the UI sees it (activity strip + manager, M14 UI).
final queueTasksProvider = StreamProvider<List<QueueTask>>(
  (ref) => ref.watch(databaseProvider).watchQueueTasks(),
);

/// Reactive library: the list updates the moment a chapter commits, with no
/// manual invalidation.
final chaptersStreamProvider = StreamProvider<List<Chapter>>(
  (ref) => ref.watch(databaseProvider).watchAllChapters(),
);

final libraryItemsStreamProvider = StreamProvider<List<LibraryItem>>(
  (ref) => ref.watch(databaseProvider).watchLibraryItems(),
);

final readingRepositoryProvider = Provider<ReadingRepository>(
  (ref) => ReadingRepository(ref.watch(databaseProvider)),
);

final seriesRepositoryProvider = Provider<SeriesRepository>(
  (ref) => SeriesRepository(ref.watch(databaseProvider)),
);

/// The persisted All Series sort (Q26: defaults to last-read).
final librarySortProvider = StreamProvider<LibrarySort>(
  (ref) => ref
      .watch(databaseProvider)
      .watchSetting(kLibrarySortSettingKey)
      .map(librarySortFromName),
);

/// Change and persist the sort; the groups provider reacts through the
/// settings stream — no imperative refresh anywhere.
Future<void> setLibrarySort(WidgetRef ref, LibrarySort sort) =>
    ref.read(databaseProvider).setSetting(kLibrarySortSettingKey, sort.name);

/// Series groups with their chapters, recomputed whenever either table
/// changes — so a capture that commits mid-run shows up immediately.
/// Ordered by the persisted [LibrarySort].
/// Every series with chapters, archived included — the source both the
/// library (active) and the Archived screen filter from, so a series can
/// never fall through the gap between them.
final allSeriesGroupsProvider = StreamProvider<List<SeriesGroup>>((ref) {
  final db = ref.watch(databaseProvider);
  final sort = ref.watch(librarySortProvider).value ?? LibrarySort.lastRead;
  return db.watchLibraryItems().asyncMap((items) async {
    final chapters = await db.allChapters();
    final byItem = <String, List<Chapter>>{};
    for (final c in chapters) {
      byItem.putIfAbsent(c.libraryItemId, () => []).add(c);
    }
    final groups = [
      for (final item in items)
        SeriesGroup(item: item, chapters: byItem[item.id] ?? const []),
    ]..removeWhere((g) => g.chapters.isEmpty);
    return sortSeriesGroups(groups, sort);
  });
});

/// The library: active series only (M16 — archived ones live on their own
/// screen and are excluded from checks).
final seriesGroupsProvider = Provider<AsyncValue<List<SeriesGroup>>>(
  (ref) => ref
      .watch(allSeriesGroupsProvider)
      .whenData(
        (groups) =>
            groups.where((g) => g.item.lifecycle != 'archived').toList(),
      ),
);

/// Archived series, most recently archived first.
final archivedGroupsProvider = Provider<AsyncValue<List<SeriesGroup>>>(
  (ref) => ref
      .watch(allSeriesGroupsProvider)
      .whenData(
        (groups) =>
            groups.where((g) => g.item.lifecycle == 'archived').toList()..sort(
              (a, b) => (b.item.archivedAt ?? DateTime(0)).compareTo(
                a.item.archivedAt ?? DateTime(0),
              ),
            ),
      ),
);

/// One series' chapters, deduplicated by value.
///
/// Drift invalidates streams per table, so every chapter write re-emits every
/// per-series stream; `.distinct` on row equality stops the ripple — a
/// progress write for series A produces no new emission for series B. This is
/// what per-series widgets watch so one chapter's change cannot rebuild the
/// whole library (M13 backend; the M17 acceptance test rides on it).
final seriesChaptersProvider = StreamProvider.family<List<Chapter>, String>(
  (ref, libraryItemId) => ref
      .watch(databaseProvider)
      .watchChaptersForItem(libraryItemId)
      .distinct(const ListEquality<Chapter>().equals),
);

/// One group, derived from the same stream so the two never disagree.
/// Looks across active AND archived: the detail screen must keep working for
/// a series the user just archived.
final seriesGroupProvider = Provider.family<AsyncValue<SeriesGroup?>, String>(
  (ref, seriesId) => ref
      .watch(allSeriesGroupsProvider)
      .whenData(
        (groups) => groups.where((g) => g.item.id == seriesId).firstOrNull,
      ),
);

/// Series with an unfinished or next-unread local chapter, most recently read
/// first. Derived from the same stream as the library, so the two can never
/// disagree and a capture or a page turn updates both without a restart.
final continueReadingProvider = Provider<AsyncValue<List<ContinueEntry>>>(
  (ref) => ref.watch(seriesGroupsProvider).whenData((groups) {
    final entries = <ContinueEntry>[];
    for (final group in groups) {
      final state = computeSeriesReadingState(group.chapters);
      final chapter = state.continueChapter;
      if (chapter == null) continue;
      entries.add(ContinueEntry(group: group, chapter: chapter, state: state));
    }
    entries.sort((a, b) {
      final at = a.state.lastReadAt;
      final bt = b.state.lastReadAt;
      if (at != null && bt != null) return bt.compareTo(at);
      // Never opened sorts after anything actually read.
      if (at != null) return -1;
      if (bt != null) return 1;
      return a.group.displayName.toLowerCase().compareTo(
        b.group.displayName.toLowerCase(),
      );
    });
    return entries;
  }),
);

/// Anything ever opened, most recent first — including series that are fully
/// completed and so no longer appear under Continue Reading.
final recentlyReadProvider = Provider<AsyncValue<List<ContinueEntry>>>(
  (ref) => ref.watch(seriesGroupsProvider).whenData((groups) {
    final entries = <ContinueEntry>[];
    for (final group in groups) {
      final state = computeSeriesReadingState(group.chapters);
      if (state.lastReadAt == null) continue;
      // Reopen where they were: the chapter to continue, else the last one
      // they finished.
      final chapter = state.continueChapter ?? state.lastCompleted;
      if (chapter == null) continue;
      entries.add(ContinueEntry(group: group, chapter: chapter, state: state));
    }
    entries.sort((a, b) => b.state.lastReadAt!.compareTo(a.state.lastReadAt!));
    return entries;
  }),
);

final seriesReadingStateProvider =
    Provider.family<AsyncValue<SeriesReadingState>, String>(
      (ref, seriesId) => ref
          .watch(seriesGroupProvider(seriesId))
          .whenData(
            (group) => group == null
                ? const SeriesReadingState(chapters: [])
                : computeSeriesReadingState(group.chapters),
          ),
    );

final siteRulesStreamProvider = StreamProvider<List<SiteRule>>(
  (ref) => ref
      .watch(databaseProvider)
      .watchAllRules()
      .map((rows) => rows.map(RuleRepository.toModel).toList()),
);

/// One-shot requests to switch the shell's bottom tab (0 = Library,
/// 1 = Browser). Written by widgets that live inside a tab (the activity
/// strip's "Open Browser" action for a capture holding on a hidden WebView);
/// consumed by the shell, which owns the index.
final shellTabRequestProvider = Provider<ValueNotifier<int?>>((ref) {
  final notifier = ValueNotifier<int?>(null);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final resumableJobProvider = StreamProvider<CaptureJob?>(
  (ref) => ref.watch(databaseProvider).watchResumableJob(),
);

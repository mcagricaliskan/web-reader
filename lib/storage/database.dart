import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// A series group: every chapter captured from one series hangs off one row.
///
/// Identity is `(host, seriesKey)`; the displayed name is separate metadata the
/// user can edit without disturbing it.
class LibraryItems extends Table {
  TextColumn get id => text()();

  /// Automatically detected series title. `title` keeps its original column
  /// name so existing rows migrate in place.
  TextColumn get title => text()();

  /// User-chosen display name. Presentation only — never part of matching,
  /// never part of a storage path.
  TextColumn get userTitle => text().nullable()();

  TextColumn get sourceUrl => text()();
  TextColumn get host => text()();

  /// Series-path fingerprint, or a `title:`/`host:` fallback key. Unique per
  /// host: this is what future captures match against.
  TextColumn get seriesKey => text().nullable()();

  /// A stable URL for the series index page, when the page offered one.
  TextColumn get seriesUrl => text().nullable()();

  /// How the key was derived, kept so a bad grouping is explainable.
  TextColumn get identityBasis => text().nullable()();
  TextColumn get identityConfidence => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  DateTimeColumn get lastCapturedAt => dateTime().nullable()();

  /// Denormalised reading pointers. Derivable, but every library query orders
  /// on them, and recomputing a per-series aggregate for each row on every
  /// stream emission is the difference between a snappy list and a stuttery
  /// one. Written in the same transaction as the chapter change that causes
  /// them, and rebuildable by `repairSeriesReadingState`.
  TextColumn get lastOpenedChapterId => text().nullable()();
  TextColumn get lastCompletedChapterId => text().nullable()();
  DateTimeColumn get lastReadAt => dateTime().nullable()();

  // --- update checking ------------------------------------------------------
  // Outcome of the last "check for new chapters". Latest-known / uncaptured
  // counts are deliberately NOT denormalised — they derive from the chapters
  // table, where a stale copy would be a lie the UI repeats.

  /// When a check last ran, successful or not.
  DateTimeColumn get lastCheckAt => dateTime().nullable()();

  /// When a check last finished successfully.
  DateTimeColumn get lastCheckSuccessAt => dateTime().nullable()();

  /// Why the last check failed, when it did.
  TextColumn get lastCheckError => text().nullable()();

  /// Terminal state of the last check: upToDate / updatesAvailable / failed /
  /// cancelled / needsUserInput.
  TextColumn get lastCheckResult => text().nullable()();

  // --- lifecycle (M16) --------------------------------------------------

  /// `active` | `archived`. Archiving hides a series from the library and
  /// excludes it from checks; it never touches chapters or files — restore
  /// brings everything back exactly as it was.
  TextColumn get lifecycle => text().withDefault(const Constant('active'))();

  /// When the series was archived; null while active. Presentation only
  /// ("archived 2 weeks ago") — [lifecycle] is the source of truth.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get libraryItemId => text().references(LibraryItems, #id)();
  TextColumn get title => text()();
  TextColumn get sourceUrl => text()();

  /// Normalised URL — identity. Unique per library item, which is what makes
  /// duplicate chapters impossible rather than merely unlikely.
  TextColumn get urlKey => text()();
  TextColumn get captureStatus => text()();

  /// Relative to the FileStore root. Never absolute.
  TextColumn get contentPath => text().nullable()();
  DateTimeColumn get capturedAt => dateTime().nullable()();
  IntColumn get detectedImageCount =>
      integer().withDefault(const Constant(0))();
  IntColumn get storedImageCount => integer().withDefault(const Constant(0))();
  TextColumn get nextSourceUrl => text().nullable()();
  IntColumn get sequence => integer().withDefault(const Constant(0))();
  TextColumn get captureError => text().nullable()();
  IntColumn get byteSize => integer().withDefault(const Constant(0))();

  /// Parsed chapter number. `REAL` so `12.5` works; null for identifiers that
  /// are not numeric at all, which fall back to capture order.
  RealColumn get chapterNumber => real().nullable()();

  /// Short display identifier: "Bölüm 883", "Chapter 101".
  TextColumn get chapterLabel => text().nullable()();

  // --- reading state ------------------------------------------------------
  // Deliberately separate from capture state: a chapter can be re-downloaded
  // and stay completed, and a capture must never reset where the user was.

  TextColumn get readStatus => text().withDefault(const Constant('unread'))();

  /// 0..1 through the chapter. The durable half of the position — content
  /// independent, so it still means something after a re-download.
  RealColumn get progressFraction => real().withDefault(const Constant(0))();

  /// Anchor: panel index plus how far down it. Precise but goes stale if the
  /// panel count changes, which is what the fraction covers.
  IntColumn get progressImageIndex =>
      integer().withDefault(const Constant(0))();
  RealColumn get progressOffsetInImage =>
      real().withDefault(const Constant(0))();

  DateTimeColumn get firstOpenedAt => dateTime().nullable()();
  DateTimeColumn get lastReadAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get progressUpdatedAt => dateTime().nullable()();

  // --- discovery ------------------------------------------------------------
  // A chapter found by an update check is a real row with
  // `captureStatus = 'knownRemote'` and no `contentPath` — known to exist on
  // the source, holding nothing locally. It is never a fake offline chapter:
  // everything that means "readable" keys off contentPath + complete/partial.

  /// When an update check first saw this chapter on the source.
  DateTimeColumn get discoveredAt => dateTime().nullable()();

  /// Which discovery strategy found it (chapterList / nextChain / savedRule).
  TextColumn get discoveryBasis => text().nullable()();

  /// Confidence of that discovery (high / medium / low).
  TextColumn get discoveryConfidence => text().nullable()();

  /// When the USER removed this chapter's offline files ("free up space").
  /// Distinct from files the system lost: a removed chapter renders as
  /// "not available offline — capture again", never as an error. Cleared on
  /// re-capture.
  DateTimeColumn get offlineRemovedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {libraryItemId, urlKey},
  ];
}

/// Just enough to recognise and resume an interrupted multi-chapter run.
class CaptureJobs extends Table {
  TextColumn get id => text()();
  TextColumn get libraryItemId => text().nullable()();
  TextColumn get startUrl => text()();
  TextColumn get currentUrl => text().nullable()();
  IntColumn get requestedChapters => integer()();
  IntColumn get completedChapters => integer().withDefault(const Constant(0))();
  TextColumn get state => text()();
  TextColumn get lastError => text().nullable()();

  /// Newline-separated normalised URLs already walked in this job.
  TextColumn get visitedUrls => text().withDefault(const Constant(''))();

  /// The duplicate policy the job was started with, so a resume applies the
  /// same one instead of silently reverting to the default.
  TextColumn get duplicatePolicy => text().nullable()();

  /// Session-scoped answers to "this chapter is already saved". Persisted on
  /// the job — they survive an interrupted-session resume — and reset when a
  /// new job starts. Never a global preference.
  TextColumn get sessionDuplicateDecision => text().nullable()();
  TextColumn get sessionPartialDecision => text().nullable()();

  /// currentChapter | fixedCount | untilEnd — how the range was chosen, so a
  /// resume continues the same mode (an interrupted until-end run must not
  /// come back as "capture 1 chapter").
  TextColumn get rangeMode =>
      text().withDefault(const Constant('fixedCount'))();

  /// Why a running job is paused (`browserHidden` today; null otherwise).
  /// Lets Activity say "paused — Browser required" instead of a bare
  /// "paused", and survives a restart.
  TextColumn get pauseReason => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per user preference. A tiny key-value store rather than columns:
/// preferences arrive one at a time (library sort first, appearance next) and
/// none of them deserve a migration each.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The persistent activity queue (M14).
///
/// Deliberately a **separate table** from `capture_jobs`: that table is the
/// capture loop's own resume record with its own lifecycle (deleted on
/// completion, drives the resumable-job card and the preflight's
/// `inActiveJob` state). Queue entries outlive their run — they *are* the
/// history — so overloading one table would force every existing query to
/// re-learn which rows are which. The queue schedules; the existing
/// controllers still do the work.
class QueueTasks extends Table {
  TextColumn get id => text()();

  /// chapterCapture | multiChapterCapture | seriesCheck | checkAllSeries
  TextColumn get taskType => text()();
  TextColumn get libraryItemId => text().nullable()();
  TextColumn get startUrl => text().nullable()();
  IntColumn get chapterLimit => integer().nullable()();
  TextColumn get duplicatePolicy => text().nullable()();

  /// currentChapter | fixedCount | untilEnd (null on rows from before v8 —
  /// read as fixedCount).
  TextColumn get rangeMode => text().nullable()();

  /// queued | running | completed | failed | cancelled
  TextColumn get state => text().withDefault(const Constant('queued'))();

  /// Short human summary of how it ended ("3 captured, 1 skipped").
  TextColumn get outcome => text().nullable()();
  TextColumn get lastError => text().nullable()();

  /// FIFO order within the queue.
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get queuedAt => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A locally-saved rule created when automatic detection was not confident and
/// the user pointed at the real control. Local-first: no account, no sync.
class SiteRuleRows extends Table {
  TextColumn get id => text()();
  TextColumn get host => text()();

  /// Series fingerprint, or a path shape for `pathPattern` scope.
  /// Null only for host-wide rules.
  TextColumn get seriesPath => text().nullable()();
  TextColumn get scope => text()();
  TextColumn get kind => text()();

  /// Serialised [DomLocator] — a bag of independent signals, not one selector.
  TextColumn get locatorJson => text()();
  TextColumn get exampleSourceUrl => text().nullable()();
  TextColumn get exampleTargetUrl => text().nullable()();
  BoolColumn get sameHostOnly => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  IntColumn get successCount => integer().withDefault(const Constant(0))();
  IntColumn get failureCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per *manual* page visit in the Browser (M18).
///
/// Deliberately a separate table from [SavedSites]: history is a log the user
/// clears by time range, saved sites are a curated list they order by hand.
/// Storing one as a flavour of the other would make "clear the last hour"
/// able to delete a bookmark.
///
/// Only navigation the user performed themselves is written here — see
/// [NavigationSource]. Capture automation and update checks move the same
/// WebView and must never appear (D53).
class BrowsingHistory extends Table {
  TextColumn get id => text()();

  /// The address as the user would read it back.
  TextColumn get url => text()();

  /// [normalizeUrl] of [url]. Grouping, dedup-within-a-window and
  /// "remove every visit to this page" all key off this, never the raw text.
  TextColumn get urlKey => text()();
  TextColumn get host => text()();
  TextColumn get title => text()();

  /// Where the visit came from. Persisted even though the UI only ever shows
  /// `manual`: a row that says how it got here is debuggable, and a filter is
  /// cheaper to widen than a lost column is to reconstruct.
  TextColumn get source => text().withDefault(const Constant('manual'))();

  /// The address the load actually settled on, when a redirect moved it.
  /// Null when nothing redirected.
  TextColumn get finalUrl => text().nullable()();

  /// Only completed, user-visible destinations are recorded, so this is true
  /// for every row written today. Kept because "the load finished" is the
  /// property the recording rule turns on, and an explicit column is what
  /// makes that rule inspectable rather than implied by absence.
  BoolColumn get completed => boolean().withDefault(const Constant(true))();

  DateTimeColumn get visitedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The user's own list of sites (M18). User-controlled, hand-ordered, and
/// never written by automation.
class SavedSites extends Table {
  TextColumn get id => text()();
  TextColumn get url => text()();

  /// Identity for duplicate detection. Two saved sites may share a host; they
  /// may not share a normalised URL.
  TextColumn get urlKey => text()();
  TextColumn get host => text()();

  /// The title as captured from the page (or derived from the host).
  TextColumn get title => text()();

  /// What the user typed instead. Presentation only — [title] is kept so
  /// clearing a rename falls back to something real.
  TextColumn get userTitle => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  /// Hand-ordered position. Ties fall back to [createdAt], so a row that was
  /// never reordered still has a stable place.
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  /// True for the Google row seeded on a clean install. Only meaningful to
  /// the seeder: the user may rename, re-point, reorder or remove it exactly
  /// like any other row, and it is never recreated afterwards (D54).
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A tiny per-host icon cache. Optional by construction: a miss renders the
/// hostname-initial fallback and nothing upstream waits on it (D55).
class FaviconCache extends Table {
  TextColumn get host => text()();

  /// The icon bytes, or null when the last attempt failed. A null row is a
  /// *negative* cache entry — it stops every list rebuild from re-requesting
  /// an icon the site does not have.
  BlobColumn get bytes => blob().nullable()();

  /// Where the bytes came from, for debugging a wrong icon.
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {host};
}

@DriftDatabase(
  tables: [
    LibraryItems,
    Chapters,
    CaptureJobs,
    SiteRuleRows,
    Settings,
    QueueTasks,
    BrowsingHistory,
    SavedSites,
    FaviconCache,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// [name] exists for integration tests, which give every test file its own
  /// database so no state leaks between them. The app always uses the
  /// default.
  AppDatabase({String name = 'webread'}) : super(driftDatabase(name: name));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // Additive only: user-created rules, captured files and capture states
      // must survive. Nothing here drops or rewrites existing data — the
      // regrouping itself runs afterwards, in Dart, as a backfill.
      if (from < 2) await m.createTable(siteRuleRows);
      if (from < 3) {
        await m.addColumn(libraryItems, libraryItems.userTitle);
        await m.addColumn(libraryItems, libraryItems.seriesKey);
        await m.addColumn(libraryItems, libraryItems.seriesUrl);
        await m.addColumn(libraryItems, libraryItems.identityBasis);
        await m.addColumn(libraryItems, libraryItems.identityConfidence);
        await m.addColumn(libraryItems, libraryItems.lastCapturedAt);
        await m.addColumn(chapters, chapters.chapterNumber);
        await m.addColumn(chapters, chapters.chapterLabel);
      }
      if (from < 4) {
        // Reading state. Additive: existing captures keep their files and
        // capture status and simply start out unread.
        await m.addColumn(chapters, chapters.readStatus);
        await m.addColumn(chapters, chapters.progressFraction);
        await m.addColumn(chapters, chapters.progressImageIndex);
        await m.addColumn(chapters, chapters.progressOffsetInImage);
        await m.addColumn(chapters, chapters.firstOpenedAt);
        await m.addColumn(chapters, chapters.lastReadAt);
        await m.addColumn(chapters, chapters.completedAt);
        await m.addColumn(chapters, chapters.progressUpdatedAt);
        await m.addColumn(libraryItems, libraryItems.lastOpenedChapterId);
        await m.addColumn(libraryItems, libraryItems.lastCompletedChapterId);
        await m.addColumn(libraryItems, libraryItems.lastReadAt);
      }
      if (from < 5) {
        // Update checking (M8) and session duplicate decisions. Additive:
        // existing rows get nulls, which mean "never checked" and "no
        // session decision" respectively.
        await m.addColumn(chapters, chapters.discoveredAt);
        await m.addColumn(chapters, chapters.discoveryBasis);
        await m.addColumn(chapters, chapters.discoveryConfidence);
        await m.addColumn(libraryItems, libraryItems.lastCheckAt);
        await m.addColumn(libraryItems, libraryItems.lastCheckSuccessAt);
        await m.addColumn(libraryItems, libraryItems.lastCheckError);
        await m.addColumn(libraryItems, libraryItems.lastCheckResult);
        await m.addColumn(captureJobs, captureJobs.duplicatePolicy);
        await m.addColumn(captureJobs, captureJobs.sessionDuplicateDecision);
        await m.addColumn(captureJobs, captureJobs.sessionPartialDecision);
      }
      if (from < 6) {
        // Settings store (M13) and the activity queue (M14). New tables
        // only; nothing existing is touched.
        await m.createTable(settings);
        await m.createTable(queueTasks);
      }
      if (from < 7) {
        // Series lifecycle (M16). Additive: every existing series comes out
        // `active`, exactly as it was.
        await m.addColumn(libraryItems, libraryItems.lifecycle);
        await m.addColumn(libraryItems, libraryItems.archivedAt);
      }
      if (from < 8) {
        // Capture range modes (current / fixed count / until end). Additive:
        // old rows read as fixedCount, which is what they were.
        await m.addColumn(captureJobs, captureJobs.rangeMode);
        await m.addColumn(queueTasks, queueTasks.rangeMode);
      }
      if (from < 9) {
        // Storage cleanup + browser-leave (post-design-v2). Additive.
        await m.addColumn(chapters, chapters.offlineRemovedAt);
        await m.addColumn(captureJobs, captureJobs.pauseReason);
      }
      if (from < 10) {
        // The Browser's own state (M18): history, saved sites, favicons. New
        // tables only — no existing row is read or rewritten, and the default
        // saved site is seeded in Dart afterwards so it can check for an
        // equivalent entry first.
        await m.createTable(browsingHistory);
        await m.createTable(savedSites);
        await m.createTable(faviconCache);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // --- site rules ---------------------------------------------------------

  Future<List<SiteRuleRow>> rulesForHost(String host) =>
      (select(siteRuleRows)..where((t) => t.host.equals(host))).get();

  Stream<List<SiteRuleRow>> watchAllRules() => (select(
    siteRuleRows,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<void> upsertRule(SiteRuleRow rule) =>
      into(siteRuleRows).insertOnConflictUpdate(rule);

  Future<void> deleteRule(String id) =>
      (delete(siteRuleRows)..where((t) => t.id.equals(id))).go();

  Future<void> recordRuleUse(String id, {required bool success}) async {
    final row = await (select(
      siteRuleRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (update(siteRuleRows)..where((t) => t.id.equals(id))).write(
      SiteRuleRowsCompanion(
        lastUsedAt: Value(success ? DateTime.now() : row.lastUsedAt),
        successCount: Value(success ? row.successCount + 1 : row.successCount),
        failureCount: Value(success ? row.failureCount : row.failureCount + 1),
      ),
    );
  }

  // --- library items ------------------------------------------------------

  Future<LibraryItem?> findLibraryItemBySourceUrl(String sourceUrl) => (select(
    libraryItems,
  )..where((t) => t.sourceUrl.equals(sourceUrl))).getSingleOrNull();

  Future<void> upsertLibraryItem(LibraryItem item) =>
      into(libraryItems).insertOnConflictUpdate(item);

  /// The group a future capture should join: matched on identity, never on
  /// display name.
  Future<LibraryItem?> findSeriesGroup(String host, String seriesKey) =>
      (select(libraryItems)
            ..where((t) => t.host.equals(host) & t.seriesKey.equals(seriesKey)))
          .getSingleOrNull();

  Future<LibraryItem?> libraryItemById(String id) =>
      (select(libraryItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> renameLibraryItem(String id, String? userTitle) =>
      (update(libraryItems)..where((t) => t.id.equals(id))).write(
        LibraryItemsCompanion(
          userTitle: Value(
            userTitle == null || userTitle.trim().isEmpty
                ? null
                : userTitle.trim(),
          ),
        ),
      );

  Future<void> markSeriesCaptured(String id, DateTime at) =>
      (update(libraryItems)..where((t) => t.id.equals(id))).write(
        LibraryItemsCompanion(lastCapturedAt: Value(at)),
      );

  /// Remove groups nothing points at. Only ever empty ones — a group with
  /// chapters is never deleted here.
  Future<int> deleteEmptyLibraryItems() async {
    final used =
        await (selectOnly(chapters, distinct: true)
              ..addColumns([chapters.libraryItemId]))
            .map((r) => r.read(chapters.libraryItemId)!)
            .get();
    return (delete(libraryItems)..where((t) => t.id.isNotIn(used))).go();
  }

  Future<List<Chapter>> allChapters() => select(chapters).get();

  Future<void> reassignChapter(String chapterId, String libraryItemId) =>
      (update(chapters)..where((t) => t.id.equals(chapterId))).write(
        ChaptersCompanion(libraryItemId: Value(libraryItemId)),
      );

  Future<void> setChapterOrdering(
    String chapterId, {
    double? number,
    String? label,
  }) => (update(chapters)..where((t) => t.id.equals(chapterId))).write(
    ChaptersCompanion(chapterNumber: Value(number), chapterLabel: Value(label)),
  );

  // --- reading state ------------------------------------------------------

  /// Reading-only write. Deliberately narrow: capture code has no DAO method
  /// that can reach these columns, so a capture cannot reset progress.
  Future<void> writeChapterReading(String id, ChaptersCompanion values) =>
      (update(chapters)..where((t) => t.id.equals(id))).write(values);

  /// Narrow writer for the chapter's source address. Separate from every
  /// other update so that "where did this come from" can only ever be
  /// changed deliberately.
  Future<void> writeChapterSource(String id, String sourceUrl) =>
      (update(chapters)..where((t) => t.id.equals(id))).write(
        ChaptersCompanion(sourceUrl: Value(sourceUrl)),
      );

  Future<void> writeSeriesReading(String id, LibraryItemsCompanion values) =>
      (update(libraryItems)..where((t) => t.id.equals(id))).write(values);

  /// Update-check outcome for a series. Narrow like [writeChapterReading]:
  /// nothing else can reach the check columns by accident.
  Future<void> writeSeriesCheck(String id, LibraryItemsCompanion values) =>
      (update(libraryItems)..where((t) => t.id.equals(id))).write(values);

  Stream<List<Chapter>> watchChaptersForItem(String libraryItemId) =>
      (select(chapters)
            ..where((t) => t.libraryItemId.equals(libraryItemId))
            ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
          .watch();

  /// One-shot read. Repair and backfill routines use this rather than taking
  /// the first emission of a stream: under a widget test's fake clock a
  /// stream's first event never arrives until frames are pumped, so awaiting
  /// one deadlocks.
  Future<List<LibraryItem>> allLibraryItems() => select(libraryItems).get();

  Stream<List<LibraryItem>> watchLibraryItems() => (select(
    libraryItems,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Future<void> touchLibraryItem(String id) =>
      (update(libraryItems)..where((t) => t.id.equals(id))).write(
        LibraryItemsCompanion(lastOpenedAt: Value(DateTime.now())),
      );

  /// M16: flip a series between `active` and `archived`. Rows only — never
  /// chapters, never files.
  Future<void> setSeriesLifecycle(String id, String lifecycle) =>
      (update(libraryItems)..where((t) => t.id.equals(id))).write(
        LibraryItemsCompanion(
          lifecycle: Value(lifecycle),
          archivedAt: Value(lifecycle == 'archived' ? DateTime.now() : null),
        ),
      );

  // --- chapters -----------------------------------------------------------

  /// Look up a chapter by URL alone, across every series.
  ///
  /// The preflight runs before the series is resolved, so it cannot scope the
  /// lookup — and a chapter that exists under a different group is still an
  /// existing chapter as far as the user is concerned.
  Future<Chapter?> findChapterByUrlKeyAnywhere(String urlKey) =>
      (select(chapters)
            ..where((t) => t.urlKey.equals(urlKey))
            ..limit(1))
          .getSingleOrNull();

  Future<Chapter?> findChapterByUrlKey(String libraryItemId, String urlKey) =>
      (select(chapters)..where(
            (t) =>
                t.libraryItemId.equals(libraryItemId) & t.urlKey.equals(urlKey),
          ))
          .getSingleOrNull();

  /// Upsert a chapter row.
  ///
  /// Note the drift semantic this rests on: `insertOnConflictUpdate` treats a
  /// null field on the data class as *absent*, so nullable columns keep their
  /// previous value. Anything that must be actively cleared needs its own
  /// narrow writer — see [clearOfflineRemovedMark].
  Future<void> upsertChapter(Chapter chapter) =>
      into(chapters).insertOnConflictUpdate(chapter);

  /// A capture just put files back: the chapter is no longer "removed by the
  /// user". Without this the marker would outlive the removal and a later
  /// system-side file loss would be reported as a deliberate removal.
  Future<void> clearOfflineRemovedMark(String id) =>
      (update(chapters)..where((t) => t.id.equals(id))).write(
        const ChaptersCompanion(offlineRemovedAt: Value(null)),
      );

  Future<List<Chapter>> chaptersForItem(String libraryItemId) =>
      (select(chapters)
            ..where((t) => t.libraryItemId.equals(libraryItemId))
            ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
          .get();

  /// Reader ordering and the library list both key off `sequence`, which is
  /// capture-chain order — more reliable than any parsed chapter number.
  Stream<List<Chapter>> watchAllChapters() =>
      (select(chapters)..orderBy([
            (t) => OrderingTerm.asc(t.libraryItemId),
            (t) => OrderingTerm.asc(t.sequence),
          ]))
          .watch();

  Future<Chapter?> chapterById(String id) =>
      (select(chapters)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> markChapterContentMissing(String id) =>
      (update(chapters)..where((t) => t.id.equals(id))).write(
        const ChaptersCompanion(
          contentPath: Value(null),
          captureStatus: Value('failed'),
          captureError: Value('local files missing'),
        ),
      );

  Future<void> deleteChapter(String id) =>
      (delete(chapters)..where((t) => t.id.equals(id))).go();

  /// Startup recovery: a chapter left mid-flight is reset, never promoted.
  Future<int> resetInFlightChapters() =>
      (update(
        chapters,
      )..where((t) => t.captureStatus.equals('capturing'))).write(
        const ChaptersCompanion(
          captureStatus: Value('failed'),
          captureError: Value('interrupted by app restart'),
        ),
      );

  // --- capture jobs -------------------------------------------------------

  /// Clear a job's pause reason. Needed for the same reason as
  /// [clearOfflineRemovedMark]: `upsertJob` leaves nullable columns alone
  /// when the data class carries null, so a resumed job would keep looking
  /// "paused — Browser required" forever.
  Future<void> clearJobPauseReason(String id) =>
      (update(captureJobs)..where((t) => t.id.equals(id))).write(
        const CaptureJobsCompanion(pauseReason: Value(null)),
      );

  Future<void> upsertJob(CaptureJob job) =>
      into(captureJobs).insertOnConflictUpdate(job);

  Future<CaptureJob?> findResumableJob() =>
      (select(captureJobs)
            ..where((t) => t.state.isNotIn(['complete', 'cancelled', 'failed']))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  Stream<CaptureJob?> watchResumableJob() =>
      (select(captureJobs)
            ..where((t) => t.state.isNotIn(['complete', 'cancelled', 'failed']))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
            ..limit(1))
          .watchSingleOrNull();

  Future<void> deleteJob(String id) =>
      (delete(captureJobs)..where((t) => t.id.equals(id))).go();

  // --- settings -------------------------------------------------------------

  Future<String?> getSetting(String key) async => (await (select(
    settings,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(Setting(key: key, value: value));

  /// One-shot read. Boot paths and tests want the value now, not the first
  /// emission of a stream.
  Future<String?> setting(String key) async => (await (select(
    settings,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Stream<String?> watchSetting(String key) =>
      (select(settings)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  // --- activity queue -------------------------------------------------------

  Future<void> upsertQueueTask(QueueTask task) =>
      into(queueTasks).insertOnConflictUpdate(task);

  Future<QueueTask?> queueTaskById(String id) =>
      (select(queueTasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<QueueTask>> pendingQueueTasks() =>
      (select(queueTasks)
            ..where((t) => t.state.isIn(['queued', 'running']))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  Stream<List<QueueTask>> watchQueueTasks() => (select(
    queueTasks,
  )..orderBy([(t) => OrderingTerm.asc(t.orderIndex)])).watch();

  Future<int> nextQueueOrderIndex() async {
    final max = await (selectOnly(
      queueTasks,
    )..addColumns([queueTasks.orderIndex.max()])).getSingle();
    return (max.read(queueTasks.orderIndex.max()) ?? 0) + 1;
  }

  /// Keep only the newest [keep] terminal entries. History is bounded; the
  /// queue rows are never the content — deleting them deletes nothing else.
  Future<int> pruneQueueHistory({int keep = 50}) async {
    final terminal =
        await (select(queueTasks)
              ..where((t) => t.state.isIn(['completed', 'failed', 'cancelled']))
              ..orderBy([(t) => OrderingTerm.desc(t.finishedAt)]))
            .get();
    if (terminal.length <= keep) return 0;
    final doomed = terminal.skip(keep).map((t) => t.id).toList();
    return (delete(queueTasks)..where((t) => t.id.isIn(doomed))).go();
  }

  /// Clear terminal history only — queued/running rows and, above all,
  /// captured content are untouched.
  Future<int> clearQueueHistory() => (delete(
    queueTasks,
  )..where((t) => t.state.isIn(['completed', 'failed', 'cancelled']))).go();

  // --- browsing history (M18) -----------------------------------------------
  //
  // Every read here filters on `source` explicitly rather than relying on the
  // writer to have kept automation out. Two independent guards, because a
  // capture flooding the user's history is the failure mode that matters.

  Future<void> insertVisit(BrowsingHistoryData visit) =>
      into(browsingHistory).insertOnConflictUpdate(visit);

  /// The most recent visit to [urlKey], if it happened within [window].
  ///
  /// Repeated visits are stored as individual rows — that is what keeps
  /// "clear the last hour" honest — but reloading the same chapter four times
  /// in a minute is one visit as far as the user is concerned, so a recent
  /// row is refreshed in place instead of stacking.
  Future<BrowsingHistoryData?> recentVisitTo(
    String urlKey, {
    required String source,
    required Duration window,
    DateTime? now,
  }) {
    final since = (now ?? DateTime.now()).subtract(window);
    return (select(browsingHistory)
          ..where(
            (t) =>
                t.urlKey.equals(urlKey) &
                t.source.equals(source) &
                t.visitedAt.isBiggerThanValue(since),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.visitedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Newest-first manual visits, bounded. The Browser Home's "recently
  /// visited" strip and the History screen both come through here, so neither
  /// can accidentally read the whole table.
  Stream<List<BrowsingHistoryData>> watchVisits({
    String source = 'manual',
    int limit = 200,
  }) =>
      (select(browsingHistory)
            ..where((t) => t.source.equals(source))
            ..orderBy([(t) => OrderingTerm.desc(t.visitedAt)])
            ..limit(limit))
          .watch();

  Future<List<BrowsingHistoryData>> visits({
    String source = 'manual',
    int limit = 200,
  }) =>
      (select(browsingHistory)
            ..where((t) => t.source.equals(source))
            ..orderBy([(t) => OrderingTerm.desc(t.visitedAt)])
            ..limit(limit))
          .get();

  /// Case-insensitive match on title, URL or host. `LIKE` is ASCII-case-
  /// insensitive in SQLite, so both sides are lowered explicitly — Turkish
  /// chapter titles are the normal case here, not the exception.
  Future<List<BrowsingHistoryData>> searchVisits(
    String query, {
    String source = 'manual',
    int limit = 200,
  }) {
    final needle = '%${query.trim().toLowerCase()}%';
    return (select(browsingHistory)
          ..where(
            (t) =>
                t.source.equals(source) &
                (t.title.lower().like(needle) |
                    t.url.lower().like(needle) |
                    t.host.lower().like(needle)),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.visitedAt)])
          ..limit(limit))
        .get();
  }

  /// How many manual visits fall in `[since, now]`. Drives the counts the
  /// clear-history sheet shows *before* anything is deleted.
  Future<int> countVisitsSince(
    DateTime? since, {
    String source = 'manual',
  }) async {
    final count = browsingHistory.id.count();
    final query = selectOnly(browsingHistory)..addColumns([count]);
    query.where(
      since == null
          ? browsingHistory.source.equals(source)
          : browsingHistory.source.equals(source) &
                browsingHistory.visitedAt.isBiggerOrEqualValue(since),
    );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> deleteVisit(String id) =>
      (delete(browsingHistory)..where((t) => t.id.equals(id))).go();

  Future<int> deleteVisitsForHost(String host, {String source = 'manual'}) =>
      (delete(
        browsingHistory,
      )..where((t) => t.host.equals(host) & t.source.equals(source))).go();

  /// Clear a time range. `since == null` means all time. Scoped to [source]
  /// so clearing the user's browsing never touches an automation audit row.
  Future<int> deleteVisitsSince(DateTime? since, {String source = 'manual'}) =>
      (delete(browsingHistory)..where(
            (t) => since == null
                ? t.source.equals(source)
                : t.source.equals(source) &
                      t.visitedAt.isBiggerOrEqualValue(since),
          ))
          .go();

  /// Retention: drop anything older than [before], then anything beyond
  /// [keep] rows. Both bounds, because either alone leaves a way to grow
  /// without limit (a quiet year, or a very busy afternoon).
  Future<int> pruneHistory({
    required DateTime before,
    required int keep,
    String source = 'manual',
  }) async {
    var removed =
        await (delete(browsingHistory)..where(
              (t) =>
                  t.source.equals(source) &
                  t.visitedAt.isSmallerThanValue(before),
            ))
            .go();
    final surviving =
        await (select(browsingHistory)
              ..where((t) => t.source.equals(source))
              ..orderBy([(t) => OrderingTerm.desc(t.visitedAt)]))
            .get();
    if (surviving.length > keep) {
      final doomed = surviving.skip(keep).map((v) => v.id).toList();
      removed += await (delete(
        browsingHistory,
      )..where((t) => t.id.isIn(doomed))).go();
    }
    return removed;
  }

  // --- saved sites (M18) ----------------------------------------------------

  Stream<List<SavedSite>> watchSavedSites() =>
      (select(savedSites)..orderBy([
            (t) => OrderingTerm.asc(t.orderIndex),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
          .watch();

  Future<List<SavedSite>> allSavedSites() =>
      (select(savedSites)..orderBy([
            (t) => OrderingTerm.asc(t.orderIndex),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
          .get();

  Future<SavedSite?> savedSiteByUrlKey(String urlKey) => (select(
    savedSites,
  )..where((t) => t.urlKey.equals(urlKey))).getSingleOrNull();

  Future<SavedSite?> savedSiteById(String id) =>
      (select(savedSites)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertSavedSite(SavedSite site) =>
      into(savedSites).insertOnConflictUpdate(site);

  /// Narrow writer for the fields the rename/edit sheet owns.
  ///
  /// Needed for the same reason as [clearOfflineRemovedMark]: an upsert would
  /// read a null `userTitle` as "leave it alone", so clearing a rename would
  /// silently do nothing.
  Future<void> writeSavedSite(String id, SavedSitesCompanion values) =>
      (update(savedSites)..where((t) => t.id.equals(id))).write(values);

  Future<int> deleteSavedSite(String id) =>
      (delete(savedSites)..where((t) => t.id.equals(id))).go();

  Future<int> nextSavedSiteOrderIndex() async {
    final max = await (selectOnly(
      savedSites,
    )..addColumns([savedSites.orderIndex.max()])).getSingle();
    return (max.read(savedSites.orderIndex.max()) ?? 0) + 1;
  }

  // --- favicons (M18) -------------------------------------------------------

  Future<FaviconCacheData?> favicon(String host) => (select(
    faviconCache,
  )..where((t) => t.host.equals(host))).getSingleOrNull();

  Future<List<FaviconCacheData>> allFavicons() => select(faviconCache).get();

  Future<void> putFavicon(FaviconCacheData icon) =>
      into(faviconCache).insertOnConflictUpdate(icon);

  Future<int> clearFavicons() => delete(faviconCache).go();
}

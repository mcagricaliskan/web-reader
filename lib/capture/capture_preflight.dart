import '../core/url_utils.dart';
import '../storage/database.dart';
import '../storage/file_store.dart';

/// What already exists locally for a chapter, decided *before* any bytes move.
enum ChapterLocalState {
  /// Never captured. The ordinary case; capture straight away.
  none,

  /// Captured, verified, files present.
  complete,

  /// Captured but knowingly incomplete.
  partial,

  /// A previous attempt failed. No usable local copy.
  failed,

  /// The database says captured, but the files are gone. Must not be reported
  /// as available offline.
  filesMissing,

  /// Another job — running or interrupted — already owns this chapter.
  inActiveJob,
}

/// What to do when a bounded run meets a chapter that already exists.
///
/// Persisted on the job so the answer is given once, not per chapter.
enum DuplicatePolicy {
  /// Leave complete chapters alone and move on. The default: re-downloading
  /// something already readable costs bandwidth and gains nothing.
  skipComplete,

  /// Skip complete ones, but re-attempt partial and failed ones.
  retryPartial,

  /// Re-capture everything in range, replacing what is there.
  replaceAll,

  /// Stop and ask at each one.
  ask,
}

DuplicatePolicy duplicatePolicyFromName(String? name) =>
    DuplicatePolicy.values.firstWhere(
      (p) => p.name == name,
      orElse: () => DuplicatePolicy.skipComplete,
    );

/// Session-scoped answer to "this chapter is already saved in full".
///
/// Lives on the running job — it survives an interrupted-session resume and
/// dies with the session. Never a global preference: the right answer to
/// "re-download?" is different for a broken chapter today than for a routine
/// range capture next week.
enum SessionDuplicateDecision {
  ask,
  skipCompleteForSession,
  replaceCompleteForSession,
}

SessionDuplicateDecision sessionDuplicateDecisionFromName(String? name) =>
    SessionDuplicateDecision.values.firstWhere(
      (d) => d.name == name,
      orElse: () => SessionDuplicateDecision.ask,
    );

/// Session-scoped answer for partial / failed / files-missing chapters met
/// mid-run. Kept separate from the complete-duplicate answer: "skip what I
/// already have" and "fix what is broken" are independent choices.
enum SessionPartialDecision { ask, retryForSession, skipForSession }

SessionPartialDecision sessionPartialDecisionFromName(String? name) =>
    SessionPartialDecision.values.firstWhere(
      (d) => d.name == name,
      orElse: () => SessionPartialDecision.ask,
    );

/// What the capture loop should do with the chapter in front of it.
enum DuplicateAction {
  /// Capture it (replacing local files when some exist).
  capture,

  /// Leave it alone and walk on to the next chapter.
  skip,

  /// Hold the job and ask the user.
  promptUser,
}

/// The one place the "already captured mid-run" decision is made.
///
/// Explicit policies (chosen in the preflight sheet before the run) answer
/// without prompting. Under [DuplicatePolicy.ask] the session decisions
/// answer, and where they are still [SessionDuplicateDecision.ask] /
/// [SessionPartialDecision.ask] the user is prompted — silently skipping or
/// silently re-downloading is exactly what this exists to prevent.
DuplicateAction resolveDuplicateAction({
  required ChapterLocalState state,
  required DuplicatePolicy policy,
  SessionDuplicateDecision sessionComplete = SessionDuplicateDecision.ask,
  SessionPartialDecision sessionPartial = SessionPartialDecision.ask,
}) {
  switch (state) {
    case ChapterLocalState.none:
      return DuplicateAction.capture;
    case ChapterLocalState.inActiveJob:
      // Owned by another job. Prompting could not offer anything safe.
      return DuplicateAction.skip;
    case ChapterLocalState.complete:
      return switch (policy) {
        DuplicatePolicy.skipComplete ||
        DuplicatePolicy.retryPartial => DuplicateAction.skip,
        DuplicatePolicy.replaceAll => DuplicateAction.capture,
        DuplicatePolicy.ask => switch (sessionComplete) {
          SessionDuplicateDecision.skipCompleteForSession =>
            DuplicateAction.skip,
          SessionDuplicateDecision.replaceCompleteForSession =>
            DuplicateAction.capture,
          SessionDuplicateDecision.ask => DuplicateAction.promptUser,
        },
      };
    case ChapterLocalState.partial:
      return switch (policy) {
        DuplicatePolicy.skipComplete => DuplicateAction.skip,
        DuplicatePolicy.retryPartial ||
        DuplicatePolicy.replaceAll => DuplicateAction.capture,
        DuplicatePolicy.ask => switch (sessionPartial) {
          SessionPartialDecision.retryForSession => DuplicateAction.capture,
          SessionPartialDecision.skipForSession => DuplicateAction.skip,
          SessionPartialDecision.ask => DuplicateAction.promptUser,
        },
      };
    case ChapterLocalState.failed || ChapterLocalState.filesMissing:
      // Nothing locally readable. Explicit policies always re-attempt these;
      // under ask the partial-session answer applies.
      return switch (policy) {
        DuplicatePolicy.ask => switch (sessionPartial) {
          SessionPartialDecision.retryForSession => DuplicateAction.capture,
          SessionPartialDecision.skipForSession => DuplicateAction.skip,
          SessionPartialDecision.ask => DuplicateAction.promptUser,
        },
        _ => DuplicateAction.capture,
      };
  }
}

/// What the user can do with a duplicate met mid-run.
enum DuplicateChoiceAction {
  /// Keep the local copy, continue with the next chapter.
  skip,

  /// Replace a complete local copy (atomic replacement, reading state kept).
  redownload,

  /// Re-attempt a partial capture, keeping the row.
  retryMissing,

  /// Re-capture a failed / files-missing chapter from scratch.
  restartChapter,

  /// End the job cleanly. Never becomes a session policy.
  stopCapture,
}

/// The user's answer to a mid-run duplicate prompt.
class DuplicateChoice {
  const DuplicateChoice(this.action, {this.applyToSession = false});

  final DuplicateChoiceAction action;

  /// "Use this choice for all already captured chapters in this capture
  /// session." Ignored for [DuplicateChoiceAction.stopCapture].
  final bool applyToSession;
}

/// A mid-run duplicate the job is holding on, waiting for the user.
class DuplicateRequest {
  const DuplicateRequest({required this.preflight, required this.ordinal});

  final ChapterPreflight preflight;

  /// 1-based position in the walk, for "chapter N of this run" phrasing.
  final int ordinal;

  ChapterLocalState get state => preflight.state;
  Chapter? get chapter => preflight.chapter;

  /// Actions that make sense for this state — the sheet must not offer
  /// "retry missing files" on a chapter that is complete.
  List<DuplicateChoiceAction> get availableActions => switch (preflight.state) {
    ChapterLocalState.complete => const [
      DuplicateChoiceAction.skip,
      DuplicateChoiceAction.redownload,
      DuplicateChoiceAction.stopCapture,
    ],
    ChapterLocalState.partial => const [
      DuplicateChoiceAction.retryMissing,
      DuplicateChoiceAction.restartChapter,
      DuplicateChoiceAction.skip,
      DuplicateChoiceAction.stopCapture,
    ],
    _ => const [
      DuplicateChoiceAction.restartChapter,
      DuplicateChoiceAction.skip,
      DuplicateChoiceAction.stopCapture,
    ],
  };

  String get title => switch (preflight.state) {
    ChapterLocalState.complete => 'This chapter is already available offline.',
    ChapterLocalState.partial =>
      'This chapter is saved, but incomplete — some images are missing.',
    ChapterLocalState.filesMissing =>
      'This chapter is listed, but its local files are gone.',
    _ => 'A previous capture of this chapter failed.',
  };
}

class ChapterPreflight {
  const ChapterPreflight({
    required this.state,
    required this.url,
    this.chapter,
    this.blockingJob,
  });

  final ChapterLocalState state;
  final String url;
  final Chapter? chapter;

  /// The job that already owns this chapter, when [state] is `inActiveJob`.
  final CaptureJob? blockingJob;

  bool get existsLocally =>
      state == ChapterLocalState.complete || state == ChapterLocalState.partial;

  bool get needsUserDecision => state != ChapterLocalState.none;

  /// Whether this chapter should be captured under [policy], with no user
  /// present to ask.
  bool shouldCaptureUnder(DuplicatePolicy policy) => switch (state) {
    ChapterLocalState.none => true,
    ChapterLocalState.failed || ChapterLocalState.filesMissing => true,
    ChapterLocalState.partial => policy != DuplicatePolicy.skipComplete,
    ChapterLocalState.complete => policy == DuplicatePolicy.replaceAll,
    ChapterLocalState.inActiveJob => false,
  };
}

/// Summary of a bounded range, so the user can decide once for the whole run.
class RangePreflight {
  const RangePreflight({required this.entries, required this.requestedCount});

  final List<ChapterPreflight> entries;
  final int requestedCount;

  int get savedCount =>
      entries.where((e) => e.state == ChapterLocalState.complete).length;
  int get partialCount =>
      entries.where((e) => e.state == ChapterLocalState.partial).length;
  int get brokenCount => entries
      .where(
        (e) =>
            e.state == ChapterLocalState.failed ||
            e.state == ChapterLocalState.filesMissing,
      )
      .length;

  /// How much of the range we could actually see ahead of time. The rest is
  /// only discoverable by visiting each page, so the job applies the chosen
  /// policy chapter by chapter.
  int get knownCount => entries.length;
  int get newCount => (requestedCount - savedCount - partialCount - brokenCount)
      .clamp(0, requestedCount);

  bool get hasExisting => savedCount + partialCount + brokenCount > 0;

  /// Human summary, only listing what is actually true.
  List<String> get lines => [
    if (savedCount > 0)
      '$savedCount chapter${savedCount == 1 ? ' is' : 's are'} already saved.',
    if (partialCount > 0)
      '$partialCount saved chapter${partialCount == 1 ? ' is' : 's are'} '
          'partial.',
    if (brokenCount > 0)
      '$brokenCount saved chapter${brokenCount == 1 ? ' has' : 's have'} '
          'missing or failed files.',
    if (newCount > 0)
      '$newCount chapter${newCount == 1 ? ' is' : 's are'} new.',
  ];
}

/// Decides what already exists before a capture starts.
///
/// Nothing here downloads: the point is that the decision is made — and the
/// user asked — before a single byte moves.
class CapturePreflight {
  CapturePreflight({required this.db, required this.fileStore});

  final AppDatabase db;
  final FileStore fileStore;

  Future<ChapterPreflight> inspect(
    String url, {
    String? libraryItemId,
    String? ignoreJobId,
  }) async {
    final key = normalizeUrl(url);

    // A job that already owns this chapter wins over anything else: starting a
    // second capture of the same page would race the first for the same files.
    //
    // `ignoreJobId` is the running job's own id. Without it a job collides with
    // itself the moment it persists its first state — its own row is
    // non-terminal and its own start URL matches — and skips every chapter it
    // was asked to capture.
    final job = await db.findResumableJob();
    if (job != null && job.id != ignoreJobId) {
      final visited = job.visitedUrls.split('\n').where((s) => s.isNotEmpty);
      final owns =
          visited.contains(key) ||
          normalizeUrl(job.currentUrl ?? '') == key ||
          normalizeUrl(job.startUrl) == key;
      if (owns) {
        return ChapterPreflight(
          state: ChapterLocalState.inActiveJob,
          url: url,
          blockingJob: job,
        );
      }
    }

    final chapter = libraryItemId == null
        ? await db.findChapterByUrlKeyAnywhere(key)
        : await db.findChapterByUrlKey(libraryItemId, key);

    if (chapter == null) {
      return ChapterPreflight(state: ChapterLocalState.none, url: url);
    }

    final path = chapter.contentPath;
    final onDisk = path != null && fileStore.chapterExists(path);

    // The database claiming a capture is not the same as the files being
    // there. Reporting a chapter as offline when it is not is the failure this
    // check exists to prevent.
    if (!onDisk &&
        (chapter.captureStatus == 'complete' ||
            chapter.captureStatus == 'partial')) {
      return ChapterPreflight(
        state: ChapterLocalState.filesMissing,
        url: url,
        chapter: chapter,
      );
    }

    return ChapterPreflight(
      state: switch (chapter.captureStatus) {
        'complete' => ChapterLocalState.complete,
        'partial' => ChapterLocalState.partial,
        // Known to exist on the source, never attempted locally: free to
        // capture, no decision needed — this is not a failed capture.
        'knownRemote' => ChapterLocalState.none,
        _ => ChapterLocalState.failed,
      },
      url: url,
      chapter: chapter,
    );
  }

  /// Look ahead over a bounded range using the next-URL chain already stored
  /// from previous captures.
  ///
  /// Only reaches as far as the chain is known — the rest of a range is not
  /// discoverable without visiting each page, which is why the job also
  /// applies the policy per chapter.
  Future<RangePreflight> inspectRange(String startUrl, int count) async {
    final entries = <ChapterPreflight>[];
    var url = startUrl;
    final seen = <String>{};

    for (var i = 0; i < count; i++) {
      final key = normalizeUrl(url);
      if (!seen.add(key)) break;

      final entry = await inspect(url);
      entries.add(entry);

      final next = entry.chapter?.nextSourceUrl;
      if (next == null) break;
      url = next;
    }
    return RangePreflight(entries: entries, requestedCount: count);
  }
}

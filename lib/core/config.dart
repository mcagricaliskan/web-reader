/// Tuning constants for autonomous capture.
///
/// Every value here is a starting point measured on the iOS Simulator against
/// the local fixture. The Simulator's network and disk are the host Mac's, so
/// these are optimistic — re-measure on a device before trusting them.
class CaptureConfig {
  const CaptureConfig({
    this.scrollStepFraction = 0.8,
    this.scrollDelay = const Duration(milliseconds: 300),
    this.fastScrollStepViewports = 3.5,
    this.fastScrollDelay = const Duration(milliseconds: 70),
    this.fastModeAfterStableProbes = 2,
    this.lookaheadViewports = 2.0,
    this.quietPeriod = const Duration(milliseconds: 900),
    this.requiredStableChecks = 3,
    this.maxScrollIterations = 300,
    this.maxScrollPasses = 2,
    this.maxCaptureDuration = const Duration(seconds: 150),
    this.maxAssetWait = const Duration(seconds: 30),
    this.domReadyTimeout = const Duration(seconds: 20),
    this.downloadRetries = 2,
    this.downloadConcurrency = 3,
    this.minImageEdge = 300,
    this.maxAspectRatio = 4.0,
    this.minCandidates = 3,
    this.minClusterSize = 3,
    this.widthClusterTolerance = 0.12,
    this.minAssetBytes = 512,
    this.cooldownBetweenChapters = const Duration(milliseconds: 1200),
    this.maxChaptersPerJob = 100,
    this.untilEndSafetyLimit = 150,
    this.maxJobDuration = const Duration(minutes: 20),
    this.untilEndJobDuration = const Duration(minutes: 45),
    this.maxSkippedPerJob = 50,
    this.minFreeSpaceToStart = 500 * 1024 * 1024,
    this.emergencyReserve = 200 * 1024 * 1024,
    this.unknownChapterEstimate = 50 * 1024 * 1024,
  });

  /// Fraction of the viewport height to advance per scroll step. Below 1.0 so
  /// consecutive steps overlap and no lazy-load trigger is jumped over.
  /// This is the CAREFUL pace, used near unloaded content.
  final double scrollStepFraction;
  final Duration scrollDelay;

  // --- adaptive traversal ---------------------------------------------------
  // The audit measured scrolling at 90–98% of real capture time while the
  // page content was often already loaded. When everything within
  // [lookaheadViewports] below the position is resolved and the document
  // height is not moving, the engine jumps [fastScrollStepViewports] per step
  // with [fastScrollDelay] between steps; any pending image nearby, height
  // growth, or non-moving scroll drops it straight back to the careful pace.

  /// Step size in fast mode, in viewport heights.
  final double fastScrollStepViewports;

  /// Delay between fast-mode steps.
  final Duration fastScrollDelay;

  /// Consecutive fully-resolved probes required before fast mode engages.
  final int fastModeAfterStableProbes;

  /// How far below the current position must be resolved for fast mode.
  final double lookaheadViewports;

  /// How long the page must stay unchanged before it counts as settled.
  final Duration quietPeriod;

  /// Consecutive unchanged probes required at the bottom of the page.
  final int requiredStableChecks;
  final int maxScrollIterations;

  /// A second downward pass catches lazy loaders that only fire when an
  /// element is scrolled *into* view from above.
  final int maxScrollPasses;
  final Duration maxCaptureDuration;
  final Duration maxAssetWait;
  final Duration domReadyTimeout;

  final int downloadRetries;
  final int downloadConcurrency;

  /// Images smaller than this on either edge are chrome, not content.
  final int minImageEdge;

  /// Wider-than-tall beyond this ratio is a banner, not a webtoon panel.
  final double maxAspectRatio;

  /// Below this many candidates the page did not yield a chapter.
  final int minCandidates;

  /// A width cluster must hold at least this many images to be trusted as
  /// "the content column".
  final int minClusterSize;

  /// Relative width tolerance when grouping images into the content column.
  final double widthClusterTolerance;

  final int minAssetBytes;
  final Duration cooldownBetweenChapters;

  /// Upper bound on a user-entered fixed chapter count. Input validation, not
  /// a preset: the range sheet refuses anything above this.
  final int maxChaptersPerJob;

  /// Hard safety bound for "until the end" — high enough to never masquerade
  /// as a chapter count, low enough that a navigation loop the validator
  /// misses cannot crawl a site forever. Hitting it reports its own distinct
  /// result ("stopped at the safety limit"), never a quiet "complete".
  final int untilEndSafetyLimit;
  final Duration maxJobDuration;

  /// Until-end runs are legitimately long; they get a wider (still hard)
  /// duration bound than fixed-count jobs.
  final Duration untilEndJobDuration;

  /// The requested chapter count means *new capture attempts*; chapters
  /// skipped as already saved do not consume it. This caps how many skips a
  /// run may walk through so a fully-captured series cannot turn a small
  /// request into an unbounded crawl.
  final int maxSkippedPerJob;

  // --- disk-space policy ------------------------------------------------
  // Centralised here on purpose: widgets and the job read the same numbers.

  /// A capture refuses to start below this much free space (bytes).
  final int minFreeSpaceToStart;

  /// Never write into the last [emergencyReserve] bytes — a chapter that
  /// would cross it stops with a distinct disk-full error instead.
  final int emergencyReserve;

  /// Planning estimate for a chapter whose size is unknown (bytes).
  final int unknownChapterEstimate;
}

/// How the user chose the capture range. Persisted (v8) so resume continues
/// the same mode.
enum CaptureRangeMode { currentChapter, fixedCount, untilEnd }

CaptureRangeMode captureRangeModeFromName(String? name) =>
    CaptureRangeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => CaptureRangeMode.fixedCount,
    );

const kDefaultCaptureConfig = CaptureConfig();

/// What the Browser's WebView holds before the user goes anywhere.
///
/// Blank on purpose. The alternatives are both worse: a search engine makes
/// the app's first act a network request to a third party, and silently
/// re-loading the last page the user was on would look like a fresh manual
/// visit — a history row nobody created (§17, D57). Instead, a cold start
/// shows Browser Home, where the last page is one tap away under Recently
/// visited.
const String kBrowserStartUrl = 'about:blank';

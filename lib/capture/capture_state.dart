/// Where a capture is, right now. Exposed in the UI so a long autonomous run
/// is observable rather than a spinner.
enum CaptureState {
  idle,
  inspecting,
  scrolling,
  waitingForAssets,
  verifying,
  extracting,
  downloading,
  saving,
  detectingNext,
  navigating,
  paused,

  /// Automatic detection was not confident. The job is holding while the user
  /// points at the real control — a prompt is better than a wrong guess that
  /// walks the job into another series.
  awaitingSelection,

  /// The WebView surface is not rendered (hidden tab: zero viewport, frozen
  /// scroll). The job is holding until the Browser is visible again — an
  /// unrendered page measures garbage, and capturing garbage is worse than
  /// waiting.
  waitingForBrowser,
  complete,
  partial,
  failed,
  cancelled;

  bool get isTerminal =>
      this == complete ||
      this == partial ||
      this == failed ||
      this == cancelled;

  bool get isRunning =>
      !isTerminal &&
      this != idle &&
      this != paused &&
      this != awaitingSelection &&
      this != waitingForBrowser;

  String get label => switch (this) {
    CaptureState.idle => 'Idle',
    CaptureState.inspecting => 'Inspecting page',
    CaptureState.scrolling => 'Scrolling',
    CaptureState.waitingForAssets => 'Waiting for images',
    CaptureState.verifying => 'Verifying',
    CaptureState.extracting => 'Extracting',
    CaptureState.downloading => 'Downloading',
    CaptureState.saving => 'Saving',
    CaptureState.detectingNext => 'Finding next chapter',
    CaptureState.navigating => 'Opening next chapter',
    CaptureState.paused => 'Paused',
    CaptureState.awaitingSelection => 'Waiting for your selection',
    CaptureState.waitingForBrowser => 'Open the Browser to continue',
    CaptureState.complete => 'Complete',
    CaptureState.partial => 'Partial',
    CaptureState.failed => 'Failed',
    CaptureState.cancelled => 'Cancelled',
  };
}

/// Legal transitions. Enforced by the engine so an impossible state pair is a
/// test failure, not a UI oddity.
const Map<CaptureState, Set<CaptureState>> kAllowedTransitions = {
  CaptureState.idle: {CaptureState.inspecting, CaptureState.cancelled},
  CaptureState.inspecting: {
    CaptureState.waitingForBrowser,
    CaptureState.scrolling,
    CaptureState.verifying,
    // A run whose every chapter was already saved ends without capturing.
    CaptureState.complete,
    CaptureState.partial,
    CaptureState.navigating,
    CaptureState.paused,
    // The very first chapter of a run can already be saved — the duplicate
    // prompt holds the job before anything else happens.
    CaptureState.awaitingSelection,
    CaptureState.failed,
    CaptureState.cancelled,
  },
  CaptureState.scrolling: {
    CaptureState.waitingForBrowser,
    CaptureState.scrolling,
    CaptureState.waitingForAssets,
    CaptureState.verifying,
    CaptureState.paused,
    CaptureState.failed,
    CaptureState.cancelled,
  },
  CaptureState.waitingForAssets: {
    CaptureState.waitingForBrowser,
    CaptureState.scrolling,
    CaptureState.verifying,
    CaptureState.paused,
    CaptureState.failed,
    CaptureState.cancelled,
  },
  CaptureState.verifying: {
    CaptureState.waitingForBrowser,
    CaptureState.extracting,
    CaptureState.awaitingSelection,
    CaptureState.paused,
    CaptureState.failed,
    CaptureState.cancelled,
  },
  CaptureState.extracting: {
    CaptureState.downloading,
    CaptureState.paused,
    CaptureState.failed,
    CaptureState.cancelled,
  },
  CaptureState.downloading: {
    // The next link is read while we are still on the page, before the
    // chapter is committed — leaving the page first would lose it.
    CaptureState.detectingNext,
    CaptureState.saving,
    CaptureState.paused,
    CaptureState.failed,
    CaptureState.cancelled,
  },
  CaptureState.detectingNext: {
    CaptureState.saving,
    CaptureState.awaitingSelection,
    CaptureState.navigating,
    CaptureState.complete,
    CaptureState.partial,
    CaptureState.paused,
    CaptureState.failed,
    CaptureState.cancelled,
  },
  CaptureState.saving: {
    CaptureState.complete,
    CaptureState.partial,
    CaptureState.detectingNext,
    CaptureState.failed,
    CaptureState.cancelled,
  },
  CaptureState.navigating: {
    CaptureState.waitingForBrowser,
    CaptureState.inspecting,
    CaptureState.paused,
    // A skip walked onto a chapter that needs a duplicate decision.
    CaptureState.awaitingSelection,
    // A run can end while walking: skipped chapters ran out of chain, or a
    // bound was reached between captures.
    CaptureState.complete,
    CaptureState.partial,
    CaptureState.failed,
    CaptureState.cancelled,
  },
  // The WebView went unrendered mid-phase; resumes into whatever it
  // interrupted once the Browser surface is visible again.
  CaptureState.waitingForBrowser: {
    CaptureState.inspecting,
    CaptureState.scrolling,
    CaptureState.waitingForAssets,
    CaptureState.verifying,
    CaptureState.extracting,
    CaptureState.navigating,
    CaptureState.detectingNext,
    CaptureState.paused,
    CaptureState.failed,
    CaptureState.cancelled,
  },
  // Resumes into whatever it interrupted, or ends if the user gives up.
  CaptureState.awaitingSelection: {
    CaptureState.inspecting,
    CaptureState.detectingNext,
    CaptureState.verifying,
    CaptureState.extracting,
    CaptureState.navigating,
    CaptureState.saving,
    CaptureState.complete,
    CaptureState.partial,
    CaptureState.failed,
    CaptureState.cancelled,
  },
  CaptureState.paused: {
    CaptureState.inspecting,
    CaptureState.scrolling,
    CaptureState.waitingForAssets,
    CaptureState.verifying,
    CaptureState.extracting,
    CaptureState.downloading,
    CaptureState.saving,
    CaptureState.detectingNext,
    CaptureState.navigating,
    CaptureState.cancelled,
  },
  // A chapter ending is not the job ending: the loop moves on to the next one.
  CaptureState.complete: {
    CaptureState.idle,
    CaptureState.inspecting,
    CaptureState.navigating,
    CaptureState.detectingNext,
    // The chapter is saved; the *next* link is what is ambiguous.
    CaptureState.awaitingSelection,
  },
  CaptureState.partial: {
    CaptureState.idle,
    CaptureState.inspecting,
    CaptureState.navigating,
    CaptureState.detectingNext,
    CaptureState.awaitingSelection,
    CaptureState.complete,
  },
  CaptureState.failed: {
    CaptureState.idle,
    CaptureState.inspecting,
    CaptureState.navigating,
    // Extraction failed -> ask the user to point at the reader area.
    CaptureState.awaitingSelection,
  },
  CaptureState.cancelled: {CaptureState.idle, CaptureState.inspecting},
};

bool isTransitionAllowed(CaptureState from, CaptureState to) =>
    from == to || (kAllowedTransitions[from]?.contains(to) ?? false);

/// Live snapshot for the capture UI.
class CaptureProgress {
  const CaptureProgress({
    this.state = CaptureState.idle,
    this.currentUrl = '',
    this.chapterTitle = '',
    this.chapterIndex = 0,
    this.requestedChapters = 1,
    this.storedChapters = 0,
    this.skippedChapters = 0,
    this.detectedImages = 0,
    this.storedImages = 0,
    this.failedImages = 0,
    this.scrollPercent = 0,
    this.retryCount = 0,
    this.lastError,
    this.message = '',
  });

  final CaptureState state;
  final String currentUrl;
  final String chapterTitle;

  /// 1-based position of the chapter being captured within this job.
  final int chapterIndex;
  final int requestedChapters;
  final int storedChapters;

  /// Chapters left alone because they already existed. Surfaced so "nothing
  /// downloaded" is distinguishable from "nothing happened".
  final int skippedChapters;
  final int detectedImages;
  final int storedImages;
  final int failedImages;
  final double scrollPercent;
  final int retryCount;
  final String? lastError;
  final String message;

  CaptureProgress copyWith({
    CaptureState? state,
    String? currentUrl,
    String? chapterTitle,
    int? chapterIndex,
    int? requestedChapters,
    int? storedChapters,
    int? skippedChapters,
    int? detectedImages,
    int? storedImages,
    int? failedImages,
    double? scrollPercent,
    int? retryCount,
    String? lastError,
    bool clearError = false,
    String? message,
  }) => CaptureProgress(
    state: state ?? this.state,
    currentUrl: currentUrl ?? this.currentUrl,
    chapterTitle: chapterTitle ?? this.chapterTitle,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    requestedChapters: requestedChapters ?? this.requestedChapters,
    storedChapters: storedChapters ?? this.storedChapters,
    skippedChapters: skippedChapters ?? this.skippedChapters,
    detectedImages: detectedImages ?? this.detectedImages,
    storedImages: storedImages ?? this.storedImages,
    failedImages: failedImages ?? this.failedImages,
    scrollPercent: scrollPercent ?? this.scrollPercent,
    retryCount: retryCount ?? this.retryCount,
    lastError: clearError ? null : (lastError ?? this.lastError),
    message: message ?? this.message,
  );
}

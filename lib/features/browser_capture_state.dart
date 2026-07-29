import '../capture/capture_job.dart';
import '../capture/capture_preflight.dart';
import '../capture/capture_state.dart';

/// What the Browser's capture control is, for the page that is on screen.
///
/// The rule this file exists to enforce (D59): **the Browser's capture state is
/// page state, not job state.** It is derived from the page identity currently
/// showing, the work that genuinely matches it, and what that page already has
/// locally. A run that finished — however recently, whatever it did — is a
/// *result*, and a result belongs to the page it happened on. It is never the
/// standing state of the next page the user opens.
enum BrowserCaptureStatus {
  /// Nothing here yet.
  capture,

  /// This page is already saved locally.
  availableOffline,

  /// A pending queue task covers this page. It has not started.
  queued,

  /// The active run is working on this page and needs the rendered surface.
  capturing,

  /// The active run is on this page but only moving bytes now.
  downloading,

  /// The active run is holding until the Browser is visible again.
  waitingForBrowser,

  /// The active run is asking the user something.
  needsInput,

  /// Something else owns the Browser, and it is not this page's work.
  busyElsewhere,
}

/// The resolved control state, plus what the capture sheet may offer.
class BrowserCaptureState {
  const BrowserCaptureState({
    required this.status,
    required this.label,
    this.detail,
    this.busyLabel,
    this.canStartDirect = false,
    this.canQueue = false,
    this.result,
  });

  final BrowserCaptureStatus status;

  /// The control's own words ("Capture", "Capturing…").
  final String label;

  /// One short line under it, when there is something worth saying.
  final String? detail;

  /// Why **Start Capture** is not on offer, when it is not.
  final String? busyLabel;

  /// Whether a direct start may be offered for this page right now.
  final bool canStartDirect;

  /// Whether queueing may be offered. Queueing is almost always available:
  /// it starts nothing, so nothing can conflict with it.
  final bool canQueue;

  /// The finished run this page is entitled to show, or null. Already
  /// page-scoped — the resolver only passes one through when it belongs here.
  final CaptureRunRecord? result;

  /// True while the run panel (phase, counters, controls) is the right thing
  /// to show under the page.
  bool get showsRunPanel => switch (status) {
    BrowserCaptureStatus.capturing ||
    BrowserCaptureStatus.downloading ||
    BrowserCaptureStatus.waitingForBrowser ||
    BrowserCaptureStatus.needsInput => true,
    _ => false,
  };

  /// True when tapping the control should start the capture flow rather than
  /// take the user to the work that is already happening.
  bool get opensCaptureSheet => switch (status) {
    BrowserCaptureStatus.capture ||
    BrowserCaptureStatus.availableOffline ||
    BrowserCaptureStatus.busyElsewhere => true,
    _ => false,
  };
}

/// Resolve the capture control for the page on screen.
///
/// Every input is about *now*: which page is showing, what is genuinely
/// active, what this page already has. Nothing here reads a previous run's
/// progress — that is the bug this replaces.
BrowserCaptureState resolveBrowserCaptureState({
  /// Canonical identity of the page on screen (empty when there is no page).
  required String pageKey,

  /// The Browser's page-session counter for that page.
  required int pageSession,

  /// True while a capture run exists that owns or is holding the WebView.
  required bool hasActiveRun,

  /// Canonical identity of the page the active run is working on.
  required String activePageKey,

  /// The active run's phase.
  required CaptureState activeState,

  /// True while the active run needs the rendered surface.
  required bool needsRenderedBrowser,

  /// True while the active run is holding on the user (selection, duplicate).
  required bool awaitingUser,

  /// True while the run is paused because the Browser was hidden.
  required bool pausedForBrowser,

  /// True while an update check owns the WebView.
  required bool checkerRunning,

  /// Whether the user is what put this page on screen. False when automation
  /// navigated here — in which case the run that navigated here owns the page,
  /// whatever the two keys say about each other mid-hop.
  bool pageEnteredManually = true,

  /// The last finished run, whatever page it belonged to.
  required CaptureRunRecord? lastRun,

  /// What this page already has locally, when it has been looked up.
  required ChapterLocalState? pageChapterState,

  /// True when a queued (not started) capture task covers this page.
  required bool pageIsQueued,
}) {
  if (hasActiveRun) {
    // Three ways this page can be the run's page, and all three are needed:
    // the keys agree; the run is *between* pages, where they are supposed to
    // disagree; or automation put this page here, which only the run does.
    final isThisPage =
        (activePageKey.isNotEmpty && activePageKey == pageKey) ||
        activeState == CaptureState.navigating ||
        !pageEnteredManually;
    if (isThisPage) {
      if (awaitingUser) {
        return const BrowserCaptureState(
          status: BrowserCaptureStatus.needsInput,
          label: 'Needs you',
          detail: 'This capture is waiting for your answer',
        );
      }
      if (pausedForBrowser || activeState == CaptureState.waitingForBrowser) {
        return const BrowserCaptureState(
          status: BrowserCaptureStatus.waitingForBrowser,
          label: 'Waiting for Browser',
          detail: 'Stay on this page to continue',
        );
      }
      if (needsRenderedBrowser) {
        return const BrowserCaptureState(
          status: BrowserCaptureStatus.capturing,
          label: 'Capturing…',
        );
      }
      return const BrowserCaptureState(
        status: BrowserCaptureStatus.downloading,
        label: 'Downloading…',
        detail: 'Images are still being saved',
      );
    }
    // Active, but somewhere else. Queueing still works — it starts nothing.
    return const BrowserCaptureState(
      status: BrowserCaptureStatus.busyElsewhere,
      label: 'Capture',
      busyLabel: 'Another capture is running',
      canQueue: true,
    );
  }

  if (checkerRunning) {
    return const BrowserCaptureState(
      status: BrowserCaptureStatus.busyElsewhere,
      label: 'Capture',
      busyLabel: 'An update check is using the Browser',
      canQueue: true,
    );
  }

  // Nothing is running. Only a result that belongs to *this* page session may
  // be shown — a completed job from the page before it is history, not state.
  final result =
      lastRun != null &&
          lastRun.pageSession == pageSession &&
          lastRun.urlKey == pageKey &&
          pageKey.isNotEmpty
      ? lastRun
      : null;

  final hasPage = pageKey.isNotEmpty;
  if (pageIsQueued) {
    return BrowserCaptureState(
      status: BrowserCaptureStatus.queued,
      label: 'Queued',
      detail: 'Waiting to start',
      canQueue: false,
      canStartDirect: hasPage,
      result: result,
    );
  }

  final saved =
      pageChapterState == ChapterLocalState.complete ||
      pageChapterState == ChapterLocalState.partial;
  if (saved) {
    return BrowserCaptureState(
      status: BrowserCaptureStatus.availableOffline,
      label: 'Capture again',
      detail: pageChapterState == ChapterLocalState.partial
          ? 'Saved, but incomplete'
          : 'Already available offline',
      canStartDirect: hasPage,
      canQueue: hasPage,
      result: result,
    );
  }

  return BrowserCaptureState(
    status: BrowserCaptureStatus.capture,
    label: 'Capture',
    canStartDirect: hasPage,
    canQueue: hasPage,
    result: result,
  );
}

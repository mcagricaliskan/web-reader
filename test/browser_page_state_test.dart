import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/browser/history_repository.dart'
    show NavigationSource;
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_preflight.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/core/url_utils.dart';
import 'package:web_reader/features/browser_capture_state.dart';
import 'package:web_reader/core/device_storage.dart';
import 'package:web_reader/queue/task_queue.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

import 'helpers/fake_browser.dart';

/// The Browser's capture state is **page** state (D59).
///
/// The bug this file exists to prevent: a capture completes, and the Browser
/// goes on showing "complete" on every page the user opens afterwards, with
/// Capture looking blocked. The fix is not to hide the widget — it is that the
/// state is derived from the page on screen and the work that genuinely
/// matches it.
void main() {
  const pageA = 'https://x.example/manga/foo/350';
  const pageB = 'https://x.example/manga/foo/351';
  final keyA = pageIdentityKey(pageA);
  final keyB = pageIdentityKey(pageB);

  CaptureRunRecord finished({
    required int session,
    String url = pageA,
    CaptureState state = CaptureState.complete,
    CaptureOrigin origin = CaptureOrigin.direct,
  }) => CaptureRunRecord(
    jobId: 'job-1',
    origin: origin,
    state: state,
    urlKey: pageIdentityKey(url),
    pageSession: session,
    storedChapters: 1,
    skippedChapters: 0,
    message: 'Captured 1 chapter(s)',
  );

  BrowserCaptureState resolve({
    String pageKey = '',
    int pageSession = 2,
    bool hasActiveRun = false,
    String activePageKey = '',
    CaptureState activeState = CaptureState.idle,
    bool needsRenderedBrowser = false,
    bool awaitingUser = false,
    bool pausedForBrowser = false,
    bool checkerRunning = false,
    bool pageEnteredManually = true,
    CaptureRunRecord? lastRun,
    ChapterLocalState? pageChapterState,
    bool pageIsQueued = false,
  }) => resolveBrowserCaptureState(
    pageKey: pageKey,
    pageSession: pageSession,
    hasActiveRun: hasActiveRun,
    activePageKey: activePageKey,
    activeState: activeState,
    needsRenderedBrowser: needsRenderedBrowser,
    awaitingUser: awaitingUser,
    pausedForBrowser: pausedForBrowser,
    checkerRunning: checkerRunning,
    pageEnteredManually: pageEnteredManually,
    lastRun: lastRun,
    pageChapterState: pageChapterState,
    pageIsQueued: pageIsQueued,
  );

  group('page session identity', () {
    test('a main-frame page change starts a new session', () {
      final browser = BrowserController();
      addTearDown(browser.dispose);

      browser.onLoadStart(pageA);
      final first = browser.pageSession;
      expect(first, greaterThan(0));
      expect(browser.pageSessionKey, keyA);

      browser.onLoadStart(pageB);
      expect(browser.pageSession, first + 1);
      expect(browser.pageSessionKey, keyB);
    });

    test('a hash jump is the same page, not a new one', () async {
      final browser = BrowserController();
      addTearDown(browser.dispose);

      browser.onLoadStart(pageA);
      final session = browser.pageSession;
      browser.onUrlChanged('$pageA#comments');
      await browser.onLoadStop('$pageA#comments');
      expect(browser.pageSession, session);
    });

    test('the same page reloading is the same page', () async {
      final browser = BrowserController();
      addTearDown(browser.dispose);

      browser.onLoadStart(pageA);
      final session = browser.pageSession;
      // Load start, progress, stop — one page, several callbacks.
      await browser.onLoadStop(pageA);
      browser.onUrlChanged(pageA);
      browser.onLoadStart(pageA);
      expect(browser.pageSession, session);
    });

    test('a redirect resolves into one page, not two states', () async {
      final browser = BrowserController();
      addTearDown(browser.dispose);

      browser.onLoadStart(pageA);
      // The server sends us elsewhere; the landing page is what is on screen.
      await browser.onLoadStop(pageB);
      expect(browser.pageSessionKey, keyB);
      expect(browser.currentUrl, pageB);
    });

    test('about:blank and app schemes start no session at all', () {
      final browser = BrowserController();
      addTearDown(browser.dispose);

      browser.onLoadStart('about:blank');
      expect(browser.pageSession, 0);
      expect(browser.pageSessionKey, isEmpty);
      browser.onLoadStart('mailto:someone@example.com');
      expect(browser.pageSession, 0);
    });

    test('automation moving the page is not the user browsing', () {
      final browser = BrowserController();
      addTearDown(browser.dispose);

      browser.onLoadStart(pageA);
      expect(browser.pageSessionIsManual, isTrue);

      browser.automationOwner = 'a capture job';
      browser.navigationSource = NavigationSource.captureAutomation;
      browser.onLoadStart(pageB);
      expect(browser.pageSessionSource, NavigationSource.captureAutomation);
      expect(browser.pageSessionIsManual, isFalse);
    });
  });

  group('a finished run belongs to the page it finished on', () {
    for (final state in const [
      CaptureState.complete,
      CaptureState.failed,
      CaptureState.cancelled,
      CaptureState.partial,
    ]) {
      test('${state.name} clears when the Browser moves to another page', () {
        final run = finished(session: 2, state: state);

        // Still on the page it happened on: the result is shown.
        final onPage = resolve(pageKey: keyA, pageSession: 2, lastRun: run);
        expect(onPage.result, isNotNull);

        // The user navigates: a new session, and the result goes with the
        // page it belonged to.
        final next = resolve(pageKey: keyB, pageSession: 3, lastRun: run);
        expect(next.result, isNull);
        expect(next.status, BrowserCaptureStatus.capture);
        expect(next.label, 'Capture');
        expect(
          next.canStartDirect,
          isTrue,
          reason: 'a historical job never disables Capture',
        );
        expect(next.canQueue, isTrue);
        expect(next.showsRunPanel, isFalse);
      });
    }

    test('the same URL in a later session is still a new page', () {
      // Re-visiting the page a capture finished on is a fresh visit; the old
      // result does not come back with it.
      final run = finished(session: 2);
      final again = resolve(pageKey: keyA, pageSession: 7, lastRun: run);
      expect(again.result, isNull);
      expect(again.status, BrowserCaptureStatus.capture);
    });

    test('a completed run elsewhere never shows on this page', () {
      final run = finished(session: 2, url: pageA);
      final elsewhere = resolve(pageKey: keyB, pageSession: 2, lastRun: run);
      expect(elsewhere.result, isNull);
    });
  });

  group('active work', () {
    test('the run on this page is what this page shows', () {
      final ui = resolve(
        pageKey: keyA,
        hasActiveRun: true,
        activePageKey: keyA,
        activeState: CaptureState.scrolling,
        needsRenderedBrowser: true,
      );
      expect(ui.status, BrowserCaptureStatus.capturing);
      expect(ui.showsRunPanel, isTrue);
      expect(ui.opensCaptureSheet, isFalse);
    });

    test('automation navigating on does not end the run it belongs to', () {
      // The engine hopped to the next chapter: new page session, new page key,
      // and the job simply moved with it.
      final ui = resolve(
        pageKey: keyB,
        pageSession: 3,
        hasActiveRun: true,
        activePageKey: keyB,
        activeState: CaptureState.extracting,
        needsRenderedBrowser: true,
        pageEnteredManually: false,
      );
      expect(ui.status, BrowserCaptureStatus.capturing);
      expect(ui.showsRunPanel, isTrue);
    });

    test('mid-hop, the run is still the run', () {
      // While navigating, the job's page is the *target* and the Browser is
      // still showing the page it is leaving. They are supposed to disagree,
      // and the panel must not blink out of existence for it.
      final ui = resolve(
        pageKey: keyA,
        hasActiveRun: true,
        activePageKey: keyB,
        activeState: CaptureState.navigating,
        needsRenderedBrowser: true,
      );
      expect(ui.status, BrowserCaptureStatus.capturing);
      expect(ui.showsRunPanel, isTrue);
    });

    test('a page automation put here belongs to the run that put it there', () {
      final ui = resolve(
        pageKey: keyB,
        hasActiveRun: true,
        activePageKey: '',
        activeState: CaptureState.inspecting,
        needsRenderedBrowser: true,
        pageEnteredManually: false,
      );
      expect(ui.status, BrowserCaptureStatus.capturing);
    });

    test('a run working elsewhere is not this page state', () {
      final ui = resolve(
        pageKey: keyB,
        hasActiveRun: true,
        activePageKey: keyA,
        activeState: CaptureState.downloading,
      );
      expect(ui.status, BrowserCaptureStatus.busyElsewhere);
      expect(ui.showsRunPanel, isFalse);
      expect(ui.canQueue, isTrue, reason: 'queueing starts nothing');
      expect(ui.canStartDirect, isFalse);
      expect(ui.busyLabel, isNotNull);
    });

    test('a download-only phase on this page says so', () {
      final ui = resolve(
        pageKey: keyA,
        hasActiveRun: true,
        activePageKey: keyA,
        activeState: CaptureState.downloading,
      );
      expect(ui.status, BrowserCaptureStatus.downloading);
    });

    test('holding for the Browser is its own state', () {
      final ui = resolve(
        pageKey: keyA,
        hasActiveRun: true,
        activePageKey: keyA,
        activeState: CaptureState.scrolling,
        pausedForBrowser: true,
      );
      expect(ui.status, BrowserCaptureStatus.waitingForBrowser);
    });

    test('a question to the user outranks the phase', () {
      final ui = resolve(
        pageKey: keyA,
        hasActiveRun: true,
        activePageKey: keyA,
        activeState: CaptureState.awaitingSelection,
        awaitingUser: true,
      );
      expect(ui.status, BrowserCaptureStatus.needsInput);
    });

    test('an update check blocks the direct start, not the queue', () {
      final ui = resolve(pageKey: keyA, checkerRunning: true);
      expect(ui.status, BrowserCaptureStatus.busyElsewhere);
      expect(ui.canQueue, isTrue);
      expect(ui.canStartDirect, isFalse);
    });
  });

  group('what this page already has', () {
    test('a saved page offers to capture again, never refuses', () {
      final ui = resolve(
        pageKey: keyA,
        pageChapterState: ChapterLocalState.complete,
      );
      expect(ui.status, BrowserCaptureStatus.availableOffline);
      expect(ui.canStartDirect, isTrue);
      expect(ui.canQueue, isTrue);
      expect(ui.detail, 'Already available offline');
    });

    test('a queued page shows queued, and only its own page does', () {
      final ui = resolve(pageKey: keyA, pageIsQueued: true);
      expect(ui.status, BrowserCaptureStatus.queued);
      expect(ui.opensCaptureSheet, isFalse);

      final other = resolve(pageKey: keyB, pageIsQueued: false);
      expect(other.status, BrowserCaptureStatus.capture);
    });

    test('with no page loaded there is nothing to start', () {
      final ui = resolve(pageKey: '');
      expect(ui.canStartDirect, isFalse);
      expect(ui.canQueue, isFalse);
      expect(ui.result, isNull);
    });
  });

  group('the controller publishes a page-scoped record', () {
    late AppDatabase db;
    late Directory root;
    late FakeBrowser browser;
    late CaptureJobController job;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      root = Directory.systemTemp.createTempSync('webread_run_record');
      browser = FakeBrowser();
      job = CaptureJobController(
        browser: browser,
        db: db,
        fileStore: FileStore(root),
        deviceStorage: _NoSpace(),
      );
    });

    tearDown(() async {
      await db.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('a run that refuses to start still reports its result', () async {
      browser.debugEnterPage(pageA);
      final session = browser.pageSession;

      await job.start(chapterLimit: 1, startUrl: pageA);

      final run = job.lastRun;
      expect(run, isNotNull);
      expect(run!.state, CaptureState.failed);
      expect(run.error, 'insufficientStorage');
      expect(run.urlKey, keyA);
      expect(run.pageSession, session);
      expect(job.hasActiveRun, isFalse, reason: 'a result is not a run');

      // On its own page it is shown…
      expect(
        resolve(pageKey: keyA, pageSession: session, lastRun: run).result,
        isNotNull,
      );
      // …and the moment the Browser is somewhere else, it is not.
      browser.debugEnterPage(pageB);
      expect(
        resolve(
          pageKey: browser.pageSessionKey,
          pageSession: browser.pageSession,
          lastRun: run,
        ).result,
        isNull,
      );
    });

    test('starting again drops the previous result', () async {
      browser.debugEnterPage(pageA);
      await job.start(chapterLimit: 1, startUrl: pageA);
      expect(job.lastRun, isNotNull);

      await job.start(chapterLimit: 1, startUrl: pageB);
      expect(job.lastRun!.urlKey, keyB, reason: 'this run, not the last one');
    });

    test('dismissing a result clears it for good', () async {
      browser.debugEnterPage(pageA);
      await job.start(chapterLimit: 1, startUrl: pageA);
      job.clearLastRun();
      expect(job.lastRun, isNull);
    });

    test('a direct run is recorded as direct', () async {
      await job.start(
        chapterLimit: 1,
        startUrl: pageA,
        origin: CaptureOrigin.direct,
      );
      expect(job.lastRun!.origin, CaptureOrigin.direct);
      expect(job.origin, CaptureOrigin.direct);
    });
  });

  group('matching a queued task to a page', () {
    QueueTask task(
      String url, {
      String state = 'queued',
      String type = 'chapterCapture',
    }) => QueueTask(
      id: url,
      taskType: type,
      startUrl: url,
      state: state,
      orderIndex: 1,
      queuedAt: DateTime(2026, 7, 28),
    );

    test('a waiting task for this page matches, fragments and all', () {
      expect(pageHasQueuedCapture([task(pageA)], keyA), isTrue);
      expect(pageHasQueuedCapture([task('$pageA#top')], keyA), isTrue);
      expect(pageHasQueuedCapture([task(pageB)], keyA), isFalse);
    });

    test('running and finished rows are not "queued"', () {
      expect(
        pageHasQueuedCapture([task(pageA, state: 'running')], keyA),
        isFalse,
      );
      expect(
        pageHasQueuedCapture([task(pageA, state: 'completed')], keyA),
        isFalse,
        reason: 'history must not make a page look queued',
      );
    });

    test('a queued check is not a queued capture', () {
      expect(
        pageHasQueuedCapture([task(pageA, type: 'seriesCheck')], keyA),
        isFalse,
      );
    });

    test('an empty page matches nothing', () {
      expect(pageHasQueuedCapture([task(pageA)], ''), isFalse);
    });
  });
}

/// A device with nothing left, so a run refuses at the door — the cheapest
/// real run there is, and one with a result worth reporting.
class _NoSpace extends DeviceStorage {
  @override
  Future<int?> freeBytes() async => 1024;
}

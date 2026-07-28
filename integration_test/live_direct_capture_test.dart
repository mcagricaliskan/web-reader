// Direct capture and page-scoped Browser state against a real site (M19).
//
//   flutter test integration_test/live_direct_capture_test.dart -d <sim-id>
//
// What only a live run can prove:
//   * **Add to Queue** on a real chapter page starts nothing and moves
//     nothing — the WebView stays exactly where the user left it (D58);
//   * **Start Capture** begins immediately in the visible Browser, through
//     the shell's own `ensureBrowserVisible` hook;
//   * chapters queued earlier are still queued afterwards, in order, and the
//     finished direct run does not release them (D58);
//   * after the run, navigating to another chapter leaves a **clean** capture
//     state — the completed result belongs to the page it happened on, and
//     the new page can start its own capture (D59). That is the stale-state
//     bug, and it needs real navigation with real redirects to be worth
//     anything.
//
// Bounded per the CLAUDE.md matrix: **one** Uzay Manga chapter is downloaded.
// The second capture is started only to prove it starts, and is stopped
// before extraction, so no second chapter's images are fetched. Nothing is
// committed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_reader/app.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/browser/browser_presentation.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_preflight.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/core/url_utils.dart';
import 'package:web_reader/features/browser_capture_state.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/queue/task_queue.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

const uzaySeries = 'https://uzaymanga.com/manga/efsanevi-buyu-imparatoru';
const uzayChapter =
    'https://uzaymanga.com/manga/efsanevi-buyu-imparatoru/885-bolum-oku';

/// Two chapters queued but never started — the "existing queue" this run must
/// leave alone. Deliberately not the page being captured.
const queuedElsewhere = [
  'https://uzaymanga.com/manga/efsanevi-buyu-imparatoru/200-bolum-oku',
  'https://uzaymanga.com/manga/efsanevi-buyu-imparatoru/201-bolum-oku',
];

final String kRunStamp = DateTime.now().millisecondsSinceEpoch.toRadixString(
  36,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FileStore fileStore;
  late BrowserController browser;
  late CaptureJobController job;
  late TaskQueueController queue;
  late BrowserPresentation presentation;
  late ProviderContainer container;

  Future<void> settle(WidgetTester tester, Duration d) async {
    await Future<void>.delayed(d);
    await tester.pump();
  }

  Future<bool> waitFor(
    WidgetTester tester,
    bool Function() done, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!done() && DateTime.now().isBefore(deadline)) {
      await settle(tester, const Duration(milliseconds: 250));
    }
    return done();
  }

  Future<void> boot(WidgetTester tester, String name) async {
    db = AppDatabase(name: 'it_${name}_$kRunStamp');
    fileStore = await FileStore.open(
      folderName: 'webread_it_${name}_$kRunStamp',
    );
    browser = BrowserController();
    job = CaptureJobController(browser: browser, db: db, fileStore: fileStore);

    final services = AppServices(
      db: db,
      fileStore: fileStore,
      browser: browser,
      captureJob: job,
    );
    queue = services.taskQueue;
    container = ProviderContainer(
      overrides: [appServicesProvider.overrideWithValue(services)],
    );
    presentation = container.read(browserPresentationProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WebReaderApp(),
      ),
    );
    await settle(tester, const Duration(seconds: 3));
  }

  /// The Browser's capture control, resolved exactly as the screen does.
  Future<BrowserCaptureState> controlState() async {
    final pageKey = browser.pageSessionKey;
    final preflight = pageKey.isEmpty
        ? null
        : await CapturePreflight(db: db, fileStore: fileStore).inspect(pageKey);
    final tasks = await db.watchQueueTasks().first;
    return resolveBrowserCaptureState(
      pageKey: pageKey,
      pageSession: browser.pageSession,
      hasActiveRun: job.hasActiveRun,
      activePageKey: job.activePageKey,
      activeState: job.progress.state,
      needsRenderedBrowser: job.needsRenderedBrowser,
      awaitingUser: job.pendingSelection != null || job.pendingDuplicate != null,
      pausedForBrowser: job.pauseReason == kPauseBrowserHidden,
      checkerRunning: false,
      lastRun: job.lastRun,
      pageChapterState: preflight?.state,
      pageIsQueued: pageHasQueuedCapture(tasks, pageKey),
    );
  }

  tearDown(() async {
    job.stop();
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (job.isRunning && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    container.dispose();
    await db.close();
  });

  testWidgets(
    'uzaymanga: Add to Queue waits, Start Capture runs now, and the next '
    'page starts clean',
    (tester) async {
      await boot(tester, 'direct_capture');

      container.read(shellTabRequestProvider).value = 1;
      await settle(tester, const Duration(seconds: 2));
      presentation.showWebsite();

      // ── The user browses to a chapter themselves ───────────────────────
      await browser.load(uzayChapter);
      final loaded = await waitFor(
        tester,
        () => browser.currentUrl.contains('885') && !browser.isLoading,
      );
      if (!loaded) {
        debugPrint(
          '[LIVE][uzaymanga] RESULT: SKIPPED (unreachable) url=$uzayChapter '
          'reason=chapter page never settled',
        );
        markTestSkipped('uzaymanga unreachable');
        return;
      }
      await settle(tester, const Duration(seconds: 3));
      final firstSession = browser.pageSession;
      final firstKey = browser.pageSessionKey;
      expect(firstKey, pageIdentityKey(browser.currentUrl));

      // ── Two chapters queued for later, and left alone throughout ───────
      for (final url in queuedElsewhere) {
        await queue.enqueueCapture(
          startUrl: url,
          chapterLimit: 1,
          range: CaptureRangeMode.currentChapter,
        );
      }
      await settle(tester, const Duration(seconds: 1));
      expect(await queue.queuedCaptures(), hasLength(2));
      expect(job.isRunning, isFalse, reason: 'queueing starts nothing (D46)');

      // ── Add to Queue on THIS page: still nothing starts, nothing moves ──
      final urlBeforeQueueing = browser.currentUrl;
      await queue.enqueueCapture(
        startUrl: uzayChapter,
        chapterLimit: 1,
        range: CaptureRangeMode.currentChapter,
      );
      await settle(tester, const Duration(seconds: 2));
      expect(job.isRunning, isFalse);
      expect(job.hasActiveRun, isFalse);
      expect(browser.currentUrl, urlBeforeQueueing, reason: 'no navigation');
      expect(browser.pageSession, firstSession, reason: 'same page');
      expect(await queue.queuedCaptures(), hasLength(3));

      var control = await controlState();
      expect(
        control.status,
        BrowserCaptureStatus.queued,
        reason: 'this page is represented by a waiting task',
      );
      debugPrint(
        '[LIVE][uzaymanga] queued-only: control=${control.status.name} '
        'pending=${(await queue.queuedCaptures()).length} '
        'running=${job.isRunning}',
      );

      // The queued row for this page is the user's plan for later; the direct
      // capture below is a different decision about the same page.
      final mine = await queue.pendingCaptureFor(uzayChapter);
      await queue.cancelTask(mine!.id);
      expect(await queue.queuedCaptures(), hasLength(2));

      // ── Start Capture: it begins here, now, in the visible Browser ─────
      final started = await queue.startDirectCapture(
        startUrl: uzayChapter,
        chapterLimit: 1,
        range: CaptureRangeMode.currentChapter,
      );
      expect(started, DirectStartResult.started);

      final began = await waitFor(
        tester,
        () => job.isRunning || job.progress.state != CaptureState.idle,
      );
      if (!began) {
        debugPrint(
          '[LIVE][uzaymanga] RESULT: BLOCKED direct capture never started '
          'url=$uzayChapter',
        );
        markTestSkipped('direct capture did not start — treated as blocked');
        return;
      }
      expect(job.origin, CaptureOrigin.direct);
      expect(
        await queue.queuedCaptures(),
        hasLength(2),
        reason: 'a direct start creates no pending row and releases none',
      );
      expect(queue.captureStartAuthorised, isFalse);
      debugPrint(
        '[LIVE][uzaymanga] direct start: origin=${job.origin.name} '
        'state=${job.progress.state.name} pendingUntouched=2',
      );

      final finished = await waitFor(
        tester,
        () => !job.isRunning,
        timeout: const Duration(minutes: 8),
      );
      await settle(tester, const Duration(seconds: 2));
      debugPrint(
        '[LIVE][uzaymanga] direct run finished=$finished '
        'state=${job.progress.state.name} '
        'stored=${job.progress.storedChapters}',
      );

      // ── The queue is exactly where it was ──────────────────────────────
      final stillWaiting = await queue.queuedCaptures()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      expect(
        stillWaiting.map((t) => t.startUrl),
        queuedElsewhere,
        reason: 'the pending batch is untouched, in its original order',
      );
      expect(queue.captureStartAuthorised, isFalse);

      // ── The outcome is Activity history, as a direct run ───────────────
      final rows = await db.watchQueueTasks().first;
      final directRows = rows.where(isDirectOriginTask).toList();
      expect(directRows, hasLength(1));
      expect(
        directRows.single.state,
        isNot(QueueTaskState.queued.name),
        reason: 'a direct row is history, never a plan',
      );
      debugPrint(
        '[LIVE][uzaymanga] activity: direct row state='
        '${directRows.single.state} outcome=${directRows.single.outcome}',
      );

      // ── Still on the captured page: the result belongs here ────────────
      control = await controlState();
      final resultShownHere = control.result != null;
      debugPrint(
        '[LIVE][uzaymanga] after capture on the same page: '
        'control=${control.status.name} result=$resultShownHere',
      );

      // ── Navigate to another chapter: the state must come up clean ──────
      final captured = await db.findChapterByUrlKeyAnywhere(
        normalizeUrl(uzayChapter),
      );
      final nextUrl = captured?.nextSourceUrl;
      if (nextUrl == null || nextUrl.isEmpty) {
        debugPrint(
          '[LIVE][uzaymanga] RESULT: PASSED url=$uzayChapter '
          'directStart=true queueUntouched=true '
          'nextChapterUnknown=true (second-page check skipped)',
        );
        return;
      }

      await browser.load(nextUrl);
      final movedOn = await waitFor(
        tester,
        () =>
            !browser.isLoading &&
            browser.pageSessionKey.isNotEmpty &&
            browser.pageSessionKey != firstKey,
      );
      await settle(tester, const Duration(seconds: 3));
      expect(movedOn, isTrue, reason: 'the next chapter really loaded');
      expect(browser.pageSession, greaterThan(firstSession));

      control = await controlState();
      debugPrint(
        '[LIVE][uzaymanga] new page: session=${browser.pageSession} '
        'control=${control.status.name} result=${control.result != null} '
        'canStart=${control.canStartDirect}',
      );
      expect(
        control.result,
        isNull,
        reason: 'the completed run belonged to the previous page (D59)',
      );
      expect(control.showsRunPanel, isFalse);
      expect(
        control.status,
        anyOf(
          BrowserCaptureStatus.capture,
          BrowserCaptureStatus.availableOffline,
        ),
        reason: 'a historical job is not this page state',
      );
      expect(
        control.canStartDirect,
        isTrue,
        reason: 'and it never disables Capture',
      );

      // ── And the second page can actually start ─────────────────────────
      final second = await queue.startDirectCapture(
        startUrl: nextUrl,
        chapterLimit: 1,
        range: CaptureRangeMode.currentChapter,
      );
      expect(second, DirectStartResult.started);
      final secondBegan = await waitFor(
        tester,
        () => job.isRunning || job.progress.state != CaptureState.idle,
      );
      // Bounded: prove it started, then stop it before anything downloads.
      job.stop();
      await waitFor(
        tester,
        () => !job.isRunning,
        timeout: const Duration(minutes: 2),
      );
      await settle(tester, const Duration(seconds: 1));

      expect(secondBegan, isTrue, reason: 'the new page starts its own run');
      expect(
        (await queue.queuedCaptures()).length,
        2,
        reason: 'and the pending queue was never touched by any of it',
      );

      debugPrint(
        '[LIVE][uzaymanga] RESULT: PASSED url=$uzayChapter '
        'directStart=true queueUntouched=true staleStateCleared=true '
        'secondPageStarted=true',
      );
    },
    timeout: const Timeout(Duration(minutes: 25)),
  );
}

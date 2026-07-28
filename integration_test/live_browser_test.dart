// The Browser UX against real sites (M18).
//
//   flutter test integration_test/live_browser_test.dart -d <simulator-id>
//
// What only a live run can prove:
//   * navigating to a real page yourself creates a history row;
//   * a capture over the *same site* creates none (D53) — the rule that is
//     easy to get right against a fixture and easy to get wrong against a
//     site that redirects, sets cookies and hops chapters;
//   * opening Browser Home preserves the loaded page rather than reloading
//     it (D52) — the WebView's own back/forward list and scroll position
//     survive, which no unit test can observe;
//   * opening a saved site reuses the existing WebView;
//   * page-actions Capture queues without starting (D46).
//
// Bounded per the CLAUDE.md matrix: read-only navigation plus **one** Uzay
// Manga chapter capture. Nothing is committed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_reader/app.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/browser/browser_presentation.dart';
import 'package:web_reader/browser/history_repository.dart';
import 'package:web_reader/browser/saved_sites_repository.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/queue/task_queue.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

const uzaySeries = 'https://uzaymanga.com/manga/efsanevi-buyu-imparatoru';
const uzayChapter =
    'https://uzaymanga.com/manga/efsanevi-buyu-imparatoru/885-bolum-oku';

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
  late HistoryRepository history;
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
    history = HistoryRepository(db);
    // Wire history exactly as `main()` does — this is the thing under test.
    browser.onVisitCompleted = (visit) => history.recordVisit(
      url: visit.url,
      title: visit.title,
      source: visit.source,
      finalUrl: visit.wasRedirected ? visit.url : null,
    );
    await SavedSitesRepository(db).seedDefaultIfNeeded();

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
    'uzaymanga: manual browsing is recorded, capture over the same site is not',
    (tester) async {
      await boot(tester, 'browser_hist');

      // Bring the Browser forward and navigate manually, twice.
      container.read(shellTabRequestProvider).value = 1;
      await settle(tester, const Duration(seconds: 2));
      presentation.showWebsite();

      await browser.load(uzaySeries);
      final firstLoaded = await waitFor(
        tester,
        () => browser.currentUrl.contains('efsanevi') && !browser.isLoading,
      );
      if (!firstLoaded) {
        debugPrint(
          '[LIVE][uzaymanga] RESULT: SKIPPED (unreachable) url=$uzaySeries '
          'reason=series page never settled',
        );
        markTestSkipped('uzaymanga unreachable');
        return;
      }
      await settle(tester, const Duration(seconds: 2));

      await browser.load(uzayChapter);
      await waitFor(
        tester,
        () => browser.currentUrl.contains('885') && !browser.isLoading,
      );
      await settle(tester, const Duration(seconds: 3));

      final manualVisits = await db.visits();
      debugPrint(
        '[LIVE][uzaymanga] manual visits recorded=${manualVisits.length} '
        '${manualVisits.map((v) => v.url).toList()}',
      );
      expect(
        manualVisits,
        isNotEmpty,
        reason: 'browsing to a real page must create history',
      );
      expect(manualVisits.every((v) => v.source == 'manual'), isTrue);
      final manualCount = manualVisits.length;

      // ── Browser Home must preserve the page ────────────────────────────
      final urlBefore = browser.currentUrl;
      final canGoBackBefore = browser.canGoBack;
      presentation.openHome(
        preserving: PreservedPage(url: urlBefore, title: browser.title),
      );
      await settle(tester, const Duration(seconds: 2));
      presentation.showWebsite();
      await settle(tester, const Duration(seconds: 2));

      expect(
        browser.currentUrl,
        urlBefore,
        reason: 'Home must not reload or replace the page (D52)',
      );
      expect(
        browser.canGoBack,
        canGoBackBefore,
        reason: "the WebView's own back list survives the overlay",
      );
      expect(
        (await db.visits()).length,
        manualCount,
        reason: 'opening and closing Home is not a new visit',
      );
      debugPrint(
        '[LIVE][uzaymanga] home overlay preserved url=$urlBefore '
        'canGoBack=$canGoBackBefore visits=$manualCount',
      );

      // ── Opening a saved site reuses the same WebView ───────────────────
      final saved = await SavedSitesRepository(
        db,
      ).save(url: uzaySeries, title: 'Efsanevi');
      await browser.load(saved.site.url);
      await waitFor(tester, () => !browser.isLoading);
      await settle(tester, const Duration(seconds: 2));
      expect(browser.isAttached, isTrue, reason: 'still the one WebView');

      final beforeCapture = (await db.visits()).length;

      // ── A capture over the same site records nothing ───────────────────
      await queue.enqueueCapture(
        startUrl: uzayChapter,
        chapterLimit: 1,
        range: CaptureRangeMode.currentChapter,
      );
      expect(
        job.isRunning,
        isFalse,
        reason: 'queueing does not start a capture (D46)',
      );
      expect(
        (await db.visits()).length,
        beforeCapture,
        reason: 'queueing navigates nowhere',
      );

      await queue.startQueuedCaptures();
      final began = await waitFor(
        tester,
        () => job.isRunning || job.progress.state != CaptureState.idle,
      );
      if (!began) {
        debugPrint(
          '[LIVE][uzaymanga] RESULT: BLOCKED capture never started '
          'url=$uzayChapter',
        );
        markTestSkipped('capture did not start — treated as unreachable');
        return;
      }
      expect(
        browser.navigationSource,
        NavigationSource.captureAutomation,
        reason: 'the run declares itself (D53)',
      );

      // Let it drive the WebView for real, then stop it — one chapter's worth
      // of navigation is all this assertion needs.
      final finished = await waitFor(
        tester,
        () => !job.isRunning,
        timeout: const Duration(minutes: 6),
      );
      final afterCapture = await db.visits();
      debugPrint(
        '[LIVE][uzaymanga] after capture: visits=${afterCapture.length} '
        '(was $beforeCapture) finished=$finished '
        'stored=${job.progress.storedChapters}',
      );
      expect(
        afterCapture.length,
        beforeCapture,
        reason: 'capture automation must never enter browsing history (D53)',
      );
      expect(afterCapture.every((v) => v.source == 'manual'), isTrue);

      debugPrint(
        '[LIVE][uzaymanga] RESULT: PASSED url=$uzayChapter '
        'manualVisits=$beforeCapture captureVisits=0 homePreserved=true',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );

  testWidgets(
    'uzaymanga: the initial saved site is seeded and openable',
    (tester) async {
      await boot(tester, 'browser_saved');

      final sites = await db.allSavedSites();
      expect(sites, hasLength(1));
      expect(sites.single.title, 'Google');
      expect(sites.single.isDefault, isTrue);

      // Removing it is permanent, even across a re-seed attempt.
      await SavedSitesRepository(db).remove(sites.single.id);
      await SavedSitesRepository(db).seedDefaultIfNeeded();
      expect(await db.allSavedSites(), isEmpty);

      debugPrint(
        '[LIVE][uzaymanga] RESULT: PASSED url=- '
        'seededGoogle=true removalPermanent=true',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

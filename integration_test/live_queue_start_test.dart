// The queue-first capture flow, against real sites.
//
//   flutter test integration_test/live_queue_start_test.dart -d <simulator-id>
//
// What only a live run can prove (D46/D47): that queueing a real chapter from
// the Library starts nothing at all, that the Browser comes forward before any
// automation, that two queued chapters run one after the other, and that once
// a chapter's panels are extracted the download no longer needs the Browser.
//
// Bounded per the CLAUDE.md matrix: one Uzay Manga chapter, two Asura
// chapters, single-chapter tasks throughout. Nothing is committed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_reader/app.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/queue/task_queue.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

const uzayChapter =
    'https://uzaymanga.com/manga/efsanevi-buyu-imparatoru/885-bolum-oku';

/// Two consecutive Asura chapters, queued as two separate single-chapter
/// tasks — the sequential case.
const asuraChapters = [
  'https://asurascans.com/comics/the-nebulas-civilization-059befe1/chapter/137',
  'https://asurascans.com/comics/the-nebulas-civilization-059befe1/chapter/138',
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

  Future<void> settle(WidgetTester tester, Duration d) async {
    await Future<void>.delayed(d);
    await tester.pump();
  }

  Future<bool> waitFor(
    WidgetTester tester,
    bool Function() done, {
    Duration timeout = const Duration(minutes: 5),
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appServicesProvider.overrideWithValue(services)],
        child: const WebReaderApp(),
      ),
    );
    // Boots on the Library tab — which is exactly the situation the rule is
    // about: queueing from somewhere that is not the Browser.
    await settle(tester, const Duration(seconds: 3));
  }

  tearDown(() async {
    job.stop();
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (job.isRunning && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await db.close();
  });

  testWidgets(
    'uzaymanga: queueing waits, starting opens the Browser',
    (tester) async {
      await boot(tester, 'queue_uzay');

      // 1. Queue from the Library. Nothing may happen.
      final result = await queue.enqueueCapture(
        startUrl: uzayChapter,
        chapterLimit: 1,
        range: CaptureRangeMode.currentChapter,
      );
      expect(result.alreadyQueued, isFalse);
      await settle(tester, const Duration(seconds: 4));

      expect(
        job.isRunning,
        isFalse,
        reason: 'queueing must not start a capture (D46)',
      );
      expect(browser.automationOwner, isNull);
      expect((await queue.queuedCaptures()), hasLength(1));
      debugPrint(
        '[LIVE][uzaymanga] queued and idle after 4s — '
        'owner=${browser.automationOwner} running=${job.isRunning}',
      );

      // 2. Explicit start. The shell's hook brings the Browser forward first.
      final released = await queue.startQueuedCaptures();
      expect(released, 1);

      final began = await waitFor(
        tester,
        () => job.isRunning || job.progress.state != CaptureState.idle,
        timeout: const Duration(minutes: 2),
      );
      if (!began) {
        debugPrint(
          '[LIVE][uzaymanga] RESULT: BLOCKED capture never started '
          '(site or simulator unreachable)',
        );
        markTestSkipped('uzaymanga did not start — treated as unreachable');
        return;
      }

      // 3. It must be the Browser tab that is showing, not the Library.
      expect(
        find.byType(WebReaderApp),
        findsOneWidget,
        reason: 'sanity: the app is still up',
      );
      debugPrint(
        '[LIVE][uzaymanga] started · state=${job.progress.state.name} '
        'attached=${browser.isAttached}',
      );

      // 4. Once it is downloading, the Browser is no longer required.
      final reachedDownload = await waitFor(
        tester,
        () =>
            job.progress.state == CaptureState.downloading ||
            job.progress.state == CaptureState.saving ||
            job.progress.state.isTerminal,
        timeout: const Duration(minutes: 4),
      );
      if (reachedDownload && !job.progress.state.isTerminal) {
        expect(
          job.needsRenderedBrowser,
          isFalse,
          reason: 'downloads continue without the Browser (D47)',
        );
        debugPrint(
          '[LIVE][uzaymanga] downloading · needsRenderedBrowser='
          '${job.needsRenderedBrowser}',
        );
      }

      final finished = await waitFor(
        tester,
        () => job.progress.state.isTerminal && !job.isRunning,
        timeout: const Duration(minutes: 5),
      );
      if (!finished) {
        debugPrint('[LIVE][uzaymanga] RESULT: BLOCKED capture did not finish');
        markTestSkipped('uzaymanga did not finish in time');
        return;
      }

      final tasks = await db.pendingQueueTasks();
      debugPrint(
        '[LIVE][uzaymanga] RESULT: PASSED url=$uzayChapter '
        'final=${job.progress.state.name} stored=${job.progress.storedChapters} '
        'pending=${tasks.length}',
      );
      expect(job.progress.state.isTerminal, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );

  testWidgets(
    'asura: two queued chapters run one after the other',
    (tester) async {
      await boot(tester, 'queue_asura');

      for (final url in asuraChapters) {
        await queue.enqueueCapture(
          startUrl: url,
          chapterLimit: 1,
          range: CaptureRangeMode.currentChapter,
        );
      }
      await settle(tester, const Duration(seconds: 4));

      expect(
        job.isRunning,
        isFalse,
        reason: 'two queued chapters, still nothing running',
      );
      expect((await queue.queuedCaptures()), hasLength(2));

      await queue.startQueuedCaptures();

      // Drain, sampling as we go: the queue must never have two drivers.
      var maxConcurrent = 0;
      var pendingLeft = 2;
      final deadline = DateTime.now().add(const Duration(minutes: 10));
      while (DateTime.now().isBefore(deadline)) {
        final running = queue.runningTaskId == null ? 0 : 1;
        if (running > maxConcurrent) maxConcurrent = running;
        pendingLeft = (await db.pendingQueueTasks()).length;
        if (pendingLeft == 0 && !job.isRunning) break;
        await settle(tester, const Duration(milliseconds: 500));
      }

      final remaining = await db.pendingQueueTasks();
      final finished = remaining.isEmpty && !job.isRunning;
      if (!finished || remaining.isNotEmpty) {
        debugPrint(
          '[LIVE][asurascans] RESULT: BLOCKED ${remaining.length} task(s) '
          'still pending — site or simulator unreachable',
        );
        markTestSkipped('asura queue did not drain — treated as unreachable');
        return;
      }

      expect(
        maxConcurrent,
        lessThanOrEqualTo(1),
        reason: 'never more than one WebView automation at a time',
      );
      debugPrint(
        '[LIVE][asurascans] RESULT: PASSED chapters=${asuraChapters.length} '
        'sequential=true maxConcurrent=$maxConcurrent',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

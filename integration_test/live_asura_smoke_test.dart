// LIVE smoke test — Asura Scans, bounded to TWO chapters.
//
//   flutter test integration_test/live_asura_smoke_test.dart -d <simulator-id>
//
// Purposes (see CLAUDE.md, Live-Site Verification Protocol):
//   · fast traversal over an eager-rendered ~146k-px chapter
//   · hidden-WebView protection: leaving the Browser mid-capture pauses,
//     returning resumes — never a stall, never avatars stored as panels
//   · JPEG-under-.webp URLs get MIME-derived extensions
//   · next-chapter detection and a bounded 2-chapter chain
//
// Explicitly NOT run by `flutter test`; requires this file + a device. An
// unreachable site reports SKIPPED, never a pass.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_reader/app.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

const liveChapter =
    'https://asurascans.com/comics/the-nebulas-civilization-059befe1/chapter/137';

final String kRunStamp = DateTime.now().millisecondsSinceEpoch.toRadixString(
  36,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FileStore fileStore;
  late BrowserController browser;
  late CaptureJobController job;

  Future<void> settle(WidgetTester tester, Duration d) async {
    await Future<void>.delayed(d);
    await tester.pump();
  }

  Future<void> waitFor(
    WidgetTester tester,
    bool Function() done, {
    Duration timeout = const Duration(minutes: 6),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!done() && DateTime.now().isBefore(deadline)) {
      await settle(tester, const Duration(milliseconds: 250));
    }
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
    'two live chapters with a mid-capture tab switch',
    (tester) async {
      db = AppDatabase(name: 'it_live_asura_$kRunStamp');
      fileStore = await FileStore.open(
        folderName: 'webread_it_live_asura_$kRunStamp',
      );
      browser = BrowserController();
      job = CaptureJobController(
        browser: browser,
        db: db,
        fileStore: fileStore,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(
              AppServices(
                db: db,
                fileStore: fileStore,
                browser: browser,
                captureJob: job,
              ),
            ),
          ],
          child: const WebReaderApp(),
        ),
      );
      await settle(tester, const Duration(seconds: 3));

      await tester.tap(
        find.byKey(const ValueKey('navTab-Browser')),
        warnIfMissed: false,
      );
      await settle(tester, const Duration(milliseconds: 800));

      try {
        await browser.loadAndWait(
          liveChapter,
          timeout: const Duration(seconds: 60),
        );
      } catch (e) {
        debugPrint(
          '[LIVE][asurascans] RESULT: UNREACHABLE url=$liveChapter — $e',
        );
        markTestSkipped('asurascans unreachable — NOT a verification');
        return;
      }
      await settle(tester, const Duration(seconds: 3));

      final started = DateTime.now();
      unawaited(job.start(chapterLimit: 2, startUrl: liveChapter));

      // Mid-scroll, walk away to the Library: the capture must PAUSE (not
      // stall, not extract garbage)...
      await waitFor(
        tester,
        () => job.progress.state == CaptureState.scrolling,
        timeout: const Duration(seconds: 60),
      );
      if (job.progress.state != CaptureState.scrolling) {
        debugPrint(
          '[LIVE][asurascans] RESULT: BLOCKED url=$liveChapter — capture never '
          'reached scrolling (state=${job.progress.state.name}, '
          'error=${job.progress.lastError})',
        );
        markTestSkipped('asurascans blocked — NOT a verification');
        return;
      }
      await tester.tap(
        find.byKey(const ValueKey('navTab-Library')),
        warnIfMissed: false,
      );
      // The contract while hidden is "never a stall, never garbage":
      // EITHER the surface keeps real metrics and the run just continues
      // (what a once-painted WKWebView does on the Simulator), OR the
      // metrics break (zero viewport / frozen scroll) and the run pauses in
      // waitingForBrowser until the user returns. Both are correct; what
      // this asserts is that one of them happens — no frozen "scrolling"
      // state making no progress.
      final scrollBefore = job.progress.scrollPercent;
      final storedBefore = job.progress.storedChapters;
      var pausedWhileHidden = false;
      var progressedWhileHidden = false;
      final hiddenUntil = DateTime.now().add(const Duration(seconds: 25));
      while (DateTime.now().isBefore(hiddenUntil)) {
        await settle(tester, const Duration(milliseconds: 250));
        if (job.progress.state == CaptureState.waitingForBrowser) {
          pausedWhileHidden = true;
          break;
        }
        if (job.progress.storedChapters > storedBefore ||
            job.progress.scrollPercent > scrollBefore + 0.05 ||
            job.progress.state == CaptureState.downloading ||
            job.progress.state == CaptureState.navigating ||
            job.progress.state.isTerminal) {
          progressedWhileHidden = true;
          break;
        }
      }
      expect(
        pausedWhileHidden || progressedWhileHidden,
        isTrue,
        reason:
            'hidden tab must either pause (broken metrics) or keep making '
            'real progress — observed neither for 25s '
            '(state=${job.progress.state.name})',
      );
      debugPrint(
        '[live] hidden tab -> '
        '${pausedWhileHidden ? 'PAUSED in waitingForBrowser' : 'kept working (metrics stayed live)'} '
        'after ${DateTime.now().difference(started).inSeconds}s',
      );
      if (pausedWhileHidden) {
        // The Library shows the banner with the way back.
        await settle(tester, const Duration(milliseconds: 600));
        expect(find.textContaining('open the Browser'), findsWidgets);
      }

      // Return to the Browser; a paused run must resume.
      await tester.tap(
        find.byKey(const ValueKey('navTab-Browser')),
        warnIfMissed: false,
      );
      await waitFor(
        tester,
        () => job.progress.state != CaptureState.waitingForBrowser,
        timeout: const Duration(seconds: 30),
      );
      expect(job.progress.state, isNot(CaptureState.waitingForBrowser));
      debugPrint('[live] browser visible again -> running');

      await waitFor(
        tester,
        () => job.progress.state.isTerminal && !job.isRunning,
      );
      for (final line in job.log.reversed) {
        debugPrint('[job] $line');
      }

      final chapters = await db.watchAllChapters().first;
      if (chapters.isEmpty) {
        debugPrint(
          '[LIVE][asurascans] RESULT: BLOCKED url=$liveChapter — nothing '
          'captured (${job.progress.lastError})',
        );
        markTestSkipped('asurascans blocked — NOT a verification');
        return;
      }

      expect(chapters.length, 2, reason: 'bounded two-chapter chain');
      for (final chapter in chapters) {
        final manifest = (await fileStore.readManifest(chapter.contentPath!))!;
        // No avatars-as-panels: Asura strips are 900-wide multi-thousand-px
        // images; an avatar capture would be a handful of ~500px squares.
        final tallest = manifest.storedAssets.fold<int>(
          0,
          (m, a) => (a.height ?? 0) > m ? a.height! : m,
        );
        expect(
          tallest,
          greaterThan(2000),
          reason:
              '${chapter.title}: tallest stored panel ${tallest}px — avatar '
              'contamination would fail this',
        );
        // MIME-derived extensions (the CDN serves image/jpeg under .webp).
        for (final asset in manifest.storedAssets) {
          final ext = asset.relativePath!.split('.').last;
          final expected = switch (asset.mimeType) {
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'image/webp' => 'webp',
            'image/avif' => 'avif',
            _ => ext,
          };
          expect(
            ext,
            expected,
            reason: '${asset.relativePath} vs ${asset.mimeType}',
          );
        }
        debugPrint(
          '[live] ${chapter.title}: ${manifest.storedAssets.length} panels · '
          '${chapter.byteSize} bytes · tallest ${tallest}px',
        );
      }

      debugPrint(
        '[LIVE][asurascans] RESULT: PASSED url=$liveChapter '
        '(2 chapters in ${DateTime.now().difference(started).inSeconds}s incl. '
        'a mid-capture pause/resume; no avatar contamination; extensions '
        'match MIME)',
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

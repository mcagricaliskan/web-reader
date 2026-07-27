// End-to-end proof of M0-M3 against the controlled fixture, on a real
// WebView in the iOS Simulator.
//
//   flutter test integration_test/capture_flow_test.dart -d <simulator-id>
//
// The fixture is served in-process on the simulator (like every other
// integration test) — no external server. Delays stay ON so the slow-panel
// and lazy-load behaviour matches the real fixture site.
//
// This test performs the real thing: a live WebView loads the fixture, the
// engine scrolls it, lazy images load, bytes are downloaded to the app
// container, manifests are written and the database is updated. Nothing is
// mocked.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_reader/app.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_preflight.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/storage/manifest.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tool/fixture/fixture_site.dart';

/// In-process fixture origin, bound in `setUpAll`.
late String kFixtureBase;
const int kFixtureImagesPerChapter = 6;

/// Unique per process: a run that is killed mid-way never uninstalls the
/// app, so a fixed name would leak rows into the next invocation.
final String kRunStamp = DateTime.now().millisecondsSinceEpoch.toRadixString(
  36,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FileStore fileStore;
  late BrowserController browser;
  late CaptureJobController job;
  late HttpServer server;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    kFixtureBase = 'http://127.0.0.1:${server.port}';
    unawaited(() async {
      try {
        await for (final req in server) {
          try {
            await handleFixtureRequest(req);
          } catch (_) {
            /* client went away */
          }
        }
      } catch (_) {
        /* server closed */
      }
    }());
  });

  tearDownAll(() => server.close(force: true));

  Future<void> bootApp(WidgetTester tester, {String? startUrl}) async {
    db = AppDatabase(name: 'it_capture_flow_$kRunStamp');
    fileStore = await FileStore.open(
      folderName: 'webread_it_capture_flow_$kRunStamp',
    );
    browser = BrowserController();
    job = CaptureJobController(browser: browser, db: db, fileStore: fileStore);

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
    await tester.pumpAndSettle(const Duration(seconds: 2));

    if (startUrl != null) {
      await browser.loadAndWait(startUrl);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }
  }

  /// Pump the UI while a background job runs — `pumpAndSettle` would hang on
  /// the WebView's continuous animation, so we pump on a clock instead.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    Duration timeout = const Duration(minutes: 4),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!done() && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(done(), isTrue, reason: 'timed out waiting for the condition');
  }

  tearDown(() async {
    // Dump the job log unconditionally: when a capture assertion fails, the
    // log is the only thing that explains why.
    for (final line in job.log.reversed) {
      debugPrint('[job] $line');
    }
    await db.close();
  });

  testWidgets('M0: the bridge can inspect a live DOM', (tester) async {
    await bootApp(tester, startUrl: '$kFixtureBase/chapter/1');

    // The shell boots on the Library tab; a WKWebView that has never been
    // painted reports zero layout metrics, so look at the Browser tab first —
    // exactly what a user probing a page would be doing. (Capture tests don't
    // need this: starting a job brings the Browser tab forward itself.)
    await tester.tap(
      find.byKey(const ValueKey('navTab-Browser')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 600));

    final probe = await browser.probe(withLinks: true);

    expect(probe.title, contains('Chapter 1'));
    expect(probe.url, contains('/chapter/1'));
    expect(probe.documentHeight, greaterThan(0));
    expect(probe.viewportHeight, greaterThan(0));
    expect(probe.readyState, anyOf('interactive', 'complete'));
    expect(probe.images.length, greaterThan(5));
    expect(probe.links, isNotEmpty);
    // rel=next is present on chapters 1 and 2 of the fixture.
    expect(probe.links.any((l) => l.rel.contains('next')), isTrue);

    debugPrint(
      '[M0] title="${probe.title}" images=${probe.images.length} '
      'height=${probe.documentHeight} links=${probe.links.length}',
    );
  });

  testWidgets('M1+M3: autonomously capture 3 chapters and follow the chain', (
    tester,
  ) async {
    await bootApp(tester, startUrl: '$kFixtureBase/chapter/1');

    // Fire and forget: the job drives the WebView while we pump the UI.
    unawaited(job.start(chapterLimit: 3));

    await pumpUntil(
      tester,
      () => job.progress.state.isTerminal && !job.isRunning,
    );

    debugPrint(
      '[M1/M3] final state=${job.progress.state.name} '
      'stored=${job.progress.storedChapters}',
    );
    for (final line in job.log.reversed) {
      debugPrint('[job] $line');
    }

    // --- database ------------------------------------------------------
    final chapters = await db.watchAllChapters().first;
    expect(chapters.length, 3, reason: 'three chapters should be recorded');

    // Chapter 2 has a deliberately broken image (503), so it must be partial —
    // and must NOT be reported as complete.
    final byUrl = {for (final c in chapters) c.sourceUrl: c};
    final ch1 = byUrl['$kFixtureBase/chapter/1']!;
    final ch2 = byUrl['$kFixtureBase/chapter/2']!;
    final ch3 = byUrl['$kFixtureBase/chapter/3']!;

    expect(ch1.captureStatus, 'complete');
    expect(ch1.storedImageCount, kFixtureImagesPerChapter);
    expect(ch1.detectedImageCount, kFixtureImagesPerChapter);

    expect(
      ch2.captureStatus,
      'partial',
      reason: 'the 503 image must produce a partial, never a false complete',
    );
    expect(ch2.storedImageCount, kFixtureImagesPerChapter - 1);

    expect(ch3.captureStatus, 'complete');
    expect(
      ch3.nextSourceUrl,
      isNull,
      reason: 'chapter 3 has no next link — end of chain',
    );

    // Capture-chain ordering.
    expect(chapters.map((c) => c.sequence).toList(), [1, 2, 3]);

    // --- files on disk --------------------------------------------------
    for (final chapter in chapters) {
      final relative = chapter.contentPath!;
      expect(
        relative,
        isNot(startsWith('/')),
        reason: 'stored paths must be relative to the app container',
      );

      final dir = Directory(fileStore.resolve(relative));
      expect(dir.existsSync(), isTrue, reason: 'chapter dir $relative');

      final manifest = await fileStore.readManifest(relative);
      expect(manifest, isNotNull);
      expect(manifest!.storedAssets.length, chapter.storedImageCount);

      var totalBytes = 0;
      for (final asset in manifest.storedAssets) {
        final file = fileStore.assetFile(relative, asset.relativePath!);
        expect(file.existsSync(), isTrue, reason: asset.relativePath);
        final bytes = await file.readAsBytes();
        // Real PNG bytes, not a placeholder or an HTML error page.
        expect(bytes.length, greaterThan(1000));
        expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);
        totalBytes += bytes.length;
      }
      debugPrint(
        '[M1] ${chapter.title}: ${chapter.storedImageCount} images, '
        '$totalBytes bytes at $relative',
      );
    }

    // Assets must be in reading order, zero padded by sequence.
    final m1 = await fileStore.readManifest(ch1.contentPath!);
    expect(m1!.storedAssets.map((a) => a.relativePath), [
      'assets/001.png',
      'assets/002.png',
      'assets/003.png',
      'assets/004.png',
      'assets/005.png',
      'assets/006.png',
    ]);

    // The failed asset is recorded with a reason, not dropped.
    final m2 = await fileStore.readManifest(ch2.contentPath!);
    final failed = m2!.assets.where((a) => a.status == AssetStatus.failed);
    expect(failed, hasLength(1));
    expect(failed.first.error, isNotNull);
    debugPrint('[M1] chapter 2 failed asset: ${failed.first.error}');

    // The job completed and cleaned up its resume record.
    expect(await db.findResumableJob(), isNull);
  });

  testWidgets('M3: a second run does not duplicate captured chapters', (
    tester,
  ) async {
    await bootApp(tester, startUrl: '$kFixtureBase/chapter/1');

    final before = (await db.watchAllChapters().first).length;
    expect(before, 3, reason: 'depends on the previous test having run');

    unawaited(job.start(chapterLimit: 3));
    await pumpUntil(
      tester,
      () => job.progress.state.isTerminal && !job.isRunning,
    );

    final after = await db.watchAllChapters().first;
    expect(after.length, 3, reason: 'already-captured chapters are skipped');
  });

  testWidgets('M3: loop and end-of-chain are handled, not crashed into', (
    tester,
  ) async {
    // Starting at the last chapter: there is no next link at all.
    await bootApp(tester, startUrl: '$kFixtureBase/chapter/3');

    unawaited(job.start(chapterLimit: 3));
    await pumpUntil(
      tester,
      () => job.progress.state.isTerminal && !job.isRunning,
    );

    expect(job.progress.state.isTerminal, isTrue);
    expect(
      job.log.any(
        (l) =>
            l.contains('end of chain') ||
            l.contains('already saved') ||
            l.contains('no next chapter beyond the skipped one'),
      ),
      isTrue,
      reason: 'a missing next link is a normal ending, not a failure',
    );
  });

  testWidgets('M3: user cancellation stops without a false success', (
    tester,
  ) async {
    await bootApp(tester, startUrl: '$kFixtureBase/chapter/1');

    // Earlier tests in this file captured these chapters; replaceAll forces a
    // real download so there is a scroll phase to cancel in.
    unawaited(job.start(chapterLimit: 3, policy: DuplicatePolicy.replaceAll));
    // Let it get into the scroll phase, then stop it.
    await pumpUntil(
      tester,
      () =>
          job.progress.state == CaptureState.scrolling ||
          job.progress.state == CaptureState.downloading,
      timeout: const Duration(seconds: 60),
    );
    job.stop();

    await pumpUntil(tester, () => !job.isRunning);
    expect(job.progress.state, CaptureState.cancelled);
  });
}

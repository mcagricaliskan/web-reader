// M2: capture online, then read with the source gone — in one run.
//
//   flutter test integration_test/offline_read_test.dart -d <simulator-id>
//
// The fixture is served *in-process on the simulator*, so the test can shut it
// down mid-run. That is what makes "offline" provable rather than asserted:
// after `server.close(force: true)` the source genuinely does not exist, and
// every panel the reader shows must have come off disk.
//
// (`flutter test integration_test/...` uninstalls the app afterwards, wiping
// the container — which is why the capture and the offline read must happen in
// the same run rather than as two separate invocations.)
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_reader/app.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_preflight.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/storage/manifest.dart';

import '../tool/fixture/fixture_site.dart';

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
  HttpServer? server;
  late String baseUrl;

  Future<void> startFixture() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server!.port}';
    unawaited(() async {
      try {
        await for (final req in server!) {
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
    debugPrint('[fixture] serving on $baseUrl');
  }

  Future<void> stopFixture() async {
    await server?.close(force: true);
    server = null;
    debugPrint('[fixture] STOPPED — the source no longer exists');
  }

  Future<bool> sourceReachable() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await client.getUrl(Uri.parse('$baseUrl/chapter/1'));
      final res = await req.close();
      await res.drain<void>();
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> bootApp(WidgetTester tester) async {
    db = AppDatabase(name: 'it_offline_read_$kRunStamp');
    fileStore = await FileStore.open(
      folderName: 'webread_it_offline_read_$kRunStamp',
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
    // Not pumpAndSettle: the browser tab hosts a live WebView that never
    // settles, so pump on a clock instead.
    await pumpFor(tester, const Duration(seconds: 3));
  }

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

  /// A series row in the All Series list, regardless of what Continue cards
  /// sit above it. Identified by key rather than widget type — the redesigned
  /// row is a Stack, not a ListTile.
  Finder seriesCard() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('seriesRow-'),
  );

  /// A saved-chapter row on the series detail screen.
  Finder chapterRow() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('chapterRow-'),
  );

  /// Switch to the Library tab. "Library" is both the tab label and the
  /// screen title, so the tab carries its own key.
  Future<void> openLibraryTab(WidgetTester tester) => tester.tap(
    find.byKey(const ValueKey('navTab-Library')),
    warnIfMissed: false,
  );

  tearDown(() async {
    await stopFixture();
    await db.close();
  });

  testWidgets('M2: capture online, kill the source, read entirely from disk', (
    tester,
  ) async {
    // --- 1. capture, with the source up -------------------------------
    await startFixture();
    expect(await sourceReachable(), isTrue, reason: 'fixture should be up');

    await bootApp(tester);
    await browser.loadAndWait('$baseUrl/chapter/1');
    await pumpFor(tester, const Duration(seconds: 1));

    unawaited(job.start(chapterLimit: 3));
    await pumpUntil(
      tester,
      () => job.progress.state.isTerminal && !job.isRunning,
    );
    for (final line in job.log.reversed) {
      debugPrint('[job] $line');
    }

    final chapters = await db.watchAllChapters().first;
    expect(chapters.length, 3);

    // --- 2. confirm the files are really there -------------------------
    var panelsOnDisk = 0;
    for (final chapter in chapters) {
      final relative = chapter.contentPath!;
      expect(
        relative,
        isNot(startsWith('/')),
        reason: 'paths must be relative to the app container',
      );
      final manifest = await fileStore.readManifest(relative);
      expect(manifest, isNotNull);
      for (final asset in manifest!.storedAssets) {
        final file = fileStore.assetFile(relative, asset.relativePath!);
        expect(file.existsSync(), isTrue);
        final bytes = await file.readAsBytes();
        expect(bytes.sublist(0, 4), [
          0x89,
          0x50,
          0x4e,
          0x47,
        ], reason: 'real PNG bytes, not a placeholder');
        panelsOnDisk++;
      }
      debugPrint(
        '[M2] ${chapter.title}: '
        '${manifest.storedAssets.length} panels · ${manifest.status.name}',
      );
    }
    expect(panelsOnDisk, 17, reason: '6 + 5 (one 503) + 6');

    // --- 3. destroy the source ------------------------------------------
    await stopFixture();
    expect(
      await sourceReachable(),
      isFalse,
      reason: 'the source must be genuinely gone for this to prove anything',
    );

    // --- 4. restart the app against the same container ------------------
    await db.close();
    await bootApp(tester);

    final afterRestart = await db.watchAllChapters().first;
    expect(afterRestart.length, 3, reason: 'library survived the restart');

    // --- 5. read it, through the real UI --------------------------------
    await openLibraryTab(tester);
    await pumpFor(tester, const Duration(seconds: 2));

    await pumpUntil(
      tester,
      () => seriesCard().evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    );

    // Since M4 the library is grouped: series card → series detail →
    // chapter tile → reader.
    await tester.ensureVisible(seriesCard().first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(seriesCard().first, warnIfMissed: false);
    await pumpUntil(
      tester,
      () => find.textContaining('images').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    );
    await tester.ensureVisible(chapterRow().first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(chapterRow().first, warnIfMissed: false);
    await pumpFor(tester, const Duration(seconds: 3));

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, isNotEmpty, reason: 'the reader rendered panels');
    for (final image in images) {
      // `cacheWidth` wraps the provider in a ResizeImage; unwrapping it also
      // confirms the decode-width limit is actually applied, which is what
      // keeps a 60-panel chapter from becoming hundreds of MB of bitmaps.
      final provider = image.image;
      expect(provider, isA<ResizeImage>());
      final resize = provider as ResizeImage;
      expect(resize.width, isNotNull, reason: 'decode width must be bounded');
      expect(
        resize.imageProvider,
        isA<FileImage>().having(
          (f) => f.file.existsSync(),
          'file exists',
          isTrue,
        ),
        reason:
            'every panel must come from a local file — the reader must '
            'never fall back to a remote URL',
      );
    }
    expect(find.textContaining('no longer'), findsNothing);

    debugPrint(
      '[M2] reader rendered ${images.length} local panels with the '
      'source server destroyed',
    );
  });

  testWidgets('M2: a partial chapter warns instead of pretending to be whole', (
    tester,
  ) async {
    await startFixture();
    await bootApp(tester);
    await browser.loadAndWait('$baseUrl/chapter/$kBrokenChapter');
    await pumpFor(tester, const Duration(seconds: 1));

    unawaited(job.start(chapterLimit: 1));
    await pumpUntil(
      tester,
      () => job.progress.state.isTerminal && !job.isRunning,
    );

    final chapters = await db.watchAllChapters().first;
    final partial = chapters.where((c) => c.captureStatus == 'partial');
    expect(
      partial,
      isNotEmpty,
      reason: 'the 503 panel must produce a partial, never a false complete',
    );

    final chapter = partial.first;
    expect(chapter.storedImageCount, lessThan(chapter.detectedImageCount));

    final manifest = await fileStore.readManifest(chapter.contentPath!);
    expect(manifest!.status, CaptureStatus.partial);
    expect(manifest.statusReason, contains('assetsFailed'));

    final failed = manifest.assets
        .where((a) => a.status == AssetStatus.failed)
        .toList();
    expect(failed, isNotEmpty);
    expect(failed.first.error, isNotNull);
    expect(
      failed.first.relativePath,
      isNull,
      reason: 'a failed asset must not claim a local file',
    );

    await stopFixture();

    // The reader shows the warning, offline. Grouped library since M4:
    // series card → series detail → chapter tile → reader. Waits are on
    // conditions, not clocks — stream providers emit when they emit.
    await openLibraryTab(tester);
    await pumpUntil(
      tester,
      () => seriesCard().evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    );
    // Earlier tests fill the sections above All Series, so the series card
    // can sit below the fold — bring it into view, then open THE partial
    // chapter by its own label rather than whatever tile happens to be first.
    await tester.ensureVisible(seriesCard().first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(seriesCard().first, warnIfMissed: false);
    final partialLabel = chapter.chapterLabel ?? chapter.title;
    await pumpUntil(
      tester,
      () => find
          .descendant(of: chapterRow(), matching: find.text(partialLabel))
          .evaluate()
          .isNotEmpty,
      timeout: const Duration(seconds: 20),
    );
    final partialTile = find.ancestor(
      of: find.text(partialLabel),
      matching: chapterRow(),
    );
    await tester.ensureVisible(partialTile.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(partialTile.first, warnIfMissed: false);
    await pumpFor(tester, const Duration(seconds: 3));

    expect(find.textContaining('Partial capture'), findsOneWidget);

    debugPrint(
      '[M2] partial chapter "${chapter.title}": '
      '${chapter.storedImageCount}/${chapter.detectedImageCount} panels, '
      'reason=${manifest.statusReason}, warning shown offline',
    );
  });

  testWidgets('M2: deleted local files degrade gracefully, keeping history', (
    tester,
  ) async {
    await startFixture();
    await bootApp(tester);
    await browser.loadAndWait('$baseUrl/chapter/1');
    await pumpFor(tester, const Duration(seconds: 1));

    // replaceAll: earlier tests in this run captured this chapter on a
    // fixture at a dead port; a skip would chase that stale chain. This test
    // needs a fresh capture whose files it can then destroy.
    unawaited(job.start(chapterLimit: 1, policy: DuplicatePolicy.replaceAll));
    await pumpUntil(
      tester,
      () => job.progress.state.isTerminal && !job.isRunning,
    );

    final chapter = (await db.watchAllChapters().first).first;
    final relative = chapter.contentPath!;

    // Simulate the OS or the user reclaiming the space behind our back.
    await stopFixture();
    Directory(fileStore.resolve(relative)).deleteSync(recursive: true);

    await openLibraryTab(tester);
    await pumpUntil(
      tester,
      () => seriesCard().evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    );
    await tester.ensureVisible(seriesCard().first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(seriesCard().first, warnIfMissed: false);

    // Open the gutted chapter itself: the database has not yet noticed the
    // files are gone, so the reader is what discovers it — and must degrade
    // to an explicit message rather than crash.
    // By key, not by label or position: the episode list is number-first and
    // newest-first now, so neither the visible text nor the row's index is a
    // stable way to find one particular chapter.
    final goneTile = find.byKey(ValueKey('chapterRow-${chapter.id}'));
    await pumpUntil(
      tester,
      () => goneTile.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 20),
    );
    await tester.ensureVisible(goneTile);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(goneTile, warnIfMissed: false);
    await pumpFor(tester, const Duration(seconds: 3));

    // No crash, an explicit message, and the row survives.
    expect(find.text('The files for this chapter are gone'), findsOneWidget);

    final stillListed = await db.chapterById(chapter.id);
    expect(
      stillListed,
      isNotNull,
      reason: 'deleting files must never delete reading history',
    );
    expect(stillListed!.title, chapter.title);

    debugPrint('[M2] "${chapter.title}" lost its files, kept its row');
  });
}

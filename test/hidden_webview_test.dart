import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/browser/page_data.dart';
import 'package:web_reader/capture/asset_downloader.dart';
import 'package:web_reader/capture/capture_engine.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/storage/manifest.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/library/update_checker.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

import 'helpers/scripted_browser.dart';

/// The unrendered-WebView class of bug (audit, 2026-07-27): an offstage
/// WKWebView answers probes with real DOM data but a zero viewport and a
/// frozen scroll position. On the real Asura page that combination made
/// extraction accept comment avatars as chapter panels. None of that may
/// ever reach disk.
void main() {
  late AppDatabase db;
  late Directory root;

  const config = CaptureConfig(
    scrollDelay: Duration(milliseconds: 5),
    fastScrollDelay: Duration(milliseconds: 1),
    quietPeriod: Duration.zero,
    requiredStableChecks: 1,
    maxScrollPasses: 1,
    maxAssetWait: Duration(milliseconds: 300),
    domReadyTimeout: Duration(seconds: 2),
    downloadRetries: 0,
    cooldownBetweenChapters: Duration.zero,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_hidden');
  });
  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  CaptureEngine engine(ScriptedBrowser browser) => CaptureEngine(
    browser: browser,
    db: db,
    fileStore: FileStore(root),
    downloader: AssetDownloader(browser: browser, config: config),
    config: config,
  );

  /// The audit's regression fixture: valid DOM (panels + avatars), zero
  /// viewport, frozen scroll.
  PageProbe hiddenSurface(int y) => lazyStripProbe(
    y: 0,
    viewportHeight: 0,
    panelCount: 5,
    extraImages: [
      avatarImage(1, complete: true),
      avatarImage(2, complete: true),
      avatarImage(3, complete: true),
    ],
  );

  test('zero viewport pauses the capture instead of extracting', () async {
    final states = <CaptureState>[];
    final browser = ScriptedBrowser(probeBuilder: (y, _) => hiddenSurface(y))
      ..scrollMoves = false
      ..setUrl('https://x.example/manga/foo/1');

    final eng = CaptureEngine(
      browser: browser,
      db: db,
      fileStore: FileStore(root),
      downloader: AssetDownloader(browser: browser, config: config),
      config: config,
      onProgress: (update) => states.add(update(const CaptureProgress()).state),
    );

    final run = eng.captureCurrentPage(
      libraryItemId: 'series-1',
      sequence: 1,
      visitedNormalized: {},
    );

    // Give it ample time to (wrongly) extract if it were going to.
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(
      states,
      contains(CaptureState.waitingForBrowser),
      reason: 'the hold must be visible to the UI',
    );
    expect(
      states,
      isNot(contains(CaptureState.extracting)),
      reason: 'nothing may be extracted from an unrendered surface',
    );

    eng.cancel();
    final result = await run;
    expect(result.status, CaptureStatus.failed);
    expect(await db.allChapters(), isEmpty, reason: 'nothing stored');
    expect(
      Directory(root.path).listSync(recursive: true).whereType<File>(),
      isEmpty,
      reason: 'no files written',
    );
  });

  test('surface coming back resumes and captures normally', () async {
    // Hidden for the first 5 probes, rendered afterwards. Downloads still
    // fail (no server), but the run must get PAST the guard and reach
    // extraction/download rather than waiting forever.
    final browser = ScriptedBrowser(
      probeBuilder: (y, n) => n <= 5
          ? hiddenSurface(y)
          : lazyStripProbe(y: y, viewportHeight: 800, panelCount: 5),
    )..setUrl('https://x.example/manga/foo/1');

    final result = await engine(browser).captureCurrentPage(
      libraryItemId: 'series-1',
      sequence: 1,
      visitedNormalized: {},
    );

    // It proceeded to the download phase (and failed there for lack of a
    // server) — the guard released; it did not hold forever and did not
    // refuse extraction.
    expect(result.error, 'No images could be downloaded');
  });

  test(
    'avatar-only collapse after healthy scrolling refuses to store',
    () async {
      // Scrolling sees tall real panels; the final verify probe sees only
      // avatars (rendered surface, but the reader content was torn down).
      // Extraction must refuse — never a complete chapter of avatars.
      final browser = ScriptedBrowser(
        probeBuilder: (y, n) {
          final avatarsOnly = PageProbe(
            url: 'https://x.example/manga/foo/1',
            title: 'Foo Chapter 1',
            readyState: 'complete',
            documentHeight: 4000,
            viewportHeight: 800,
            scrollY: y,
            atBottom: true,
            images: [
              for (var i = 0; i < 4; i++)
                PageImage(
                  domIndex: i,
                  src: 'https://cdn.example/avatar/big$i.webp',
                  currentSrc: 'https://cdn.example/avatar/big$i.webp',
                  complete: true,
                  naturalWidth: 538,
                  naturalHeight: 539,
                  renderedWidth: 538,
                  renderedHeight: 539,
                  documentTop: i * 600,
                ),
            ],
          );
          // Healthy tall strips while scrolling (probes before the last two),
          // avatars at verify time.
          return n < 12
              ? lazyStripProbe(
                  y: y,
                  viewportHeight: 800,
                  panelCount: 4,
                  panelHeight: 13000,
                )
              : avatarsOnly;
        },
      )..setUrl('https://x.example/manga/foo/1');

      final result = await engine(browser).captureCurrentPage(
        libraryItemId: 'series-1',
        sequence: 1,
        visitedNormalized: {},
      );

      expect(result.status, CaptureStatus.failed);
      expect(result.extractionFailed, isTrue, reason: 'asks the user instead');
      expect(result.error, contains('changed under the capture'));
      expect(await db.allChapters(), isEmpty);
    },
  );

  test('the update checker holds on a hidden surface too', () async {
    await db.upsertLibraryItem(
      LibraryItem(
        lifecycle: 'active',
        id: 's1',
        title: 'Foo',
        sourceUrl: 'https://x.example/manga/foo',
        host: 'x.example',
        seriesKey: '/manga/foo',
        createdAt: DateTime(2026, 7, 1),
      ),
    );
    await db.upsertChapter(
      Chapter(
        id: 'c1',
        libraryItemId: 's1',
        title: 'Foo Chapter 1',
        sourceUrl: 'https://x.example/manga/foo/1',
        urlKey: 'https://x.example/manga/foo/1',
        captureStatus: 'complete',
        contentPath: 'library/s1/chapters/c1',
        capturedAt: DateTime(2026, 7, 20),
        detectedImageCount: 3,
        storedImageCount: 3,
        sequence: 1,
        byteSize: 1024,
        chapterNumber: 1,
        chapterLabel: 'Chapter 1',
        readStatus: 'unread',
        progressFraction: 0,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
      ),
    );

    final browser = ScriptedBrowser(probeBuilder: (y, _) => hiddenSurface(y))
      ..setUrl('https://x.example/manga/foo/1');
    final checker = UpdateChecker(browser: browser, db: db);

    final outcome = checker.check('s1');
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(
      checker.log.join('\n'),
      contains('open the Browser'),
      reason: 'the hold is reported, not silent',
    );
    checker.cancel();
    final result = await outcome;
    expect(
      result.state,
      anyOf(UpdateCheckState.cancelled, UpdateCheckState.failed),
      reason: 'a cancelled hold never fabricates a result',
    );
  });
}

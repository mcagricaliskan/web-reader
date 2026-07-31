import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/save/asset_fetcher.dart';
import 'package:web_reader/save/capture_mode.dart';
import 'package:web_reader/save/save_engine.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

import 'helpers/scripted_browser.dart';

/// The adaptive traversal: fast over resolved regions, careful near pending
/// content, and never a full asset-wait for an avatar that will not load.
void main() {
  late AppDatabase db;
  late Directory root;

  const vp = 800;

  const config = SaveConfig(
    scrollDelay: Duration(milliseconds: 5),
    fastScrollDelay: Duration(milliseconds: 1),
    quietPeriod: Duration.zero,
    requiredStableChecks: 1,
    maxScrollIterations: 200,
    maxScrollPasses: 1,
    maxAssetWait: Duration(milliseconds: 600),
    domReadyTimeout: Duration(seconds: 2),
    downloadRetries: 0,
    cooldownBetweenEntries: Duration.zero,
  );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_adaptive');
  });
  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  SaveEngine engine(ScriptedBrowser browser, {SaveConfig? cfg}) => SaveEngine(
    browser: browser,
    db: db,
    fileStore: FileStore(root),
    downloader: AssetFetcher(browser: browser, config: cfg ?? config),
    config: cfg ?? config,
  );

  Future<void> run(ScriptedBrowser browser, {SaveConfig? cfg}) async {
    browser.setUrl('https://x.example/guide/foo/1');
    // Downloads fail (no server) — irrelevant: the assertions are about the
    // scroll pacing recorded before the download phase.
    await engine(browser, cfg: cfg).saveCurrentPage(
      collectionId: 'collection-1',
      entryOrder: 1,
      visitedNormalized: {},
      captureMode: CaptureMode.imageSequence,
    );
  }

  test('a fully loaded page is traversed in fast mode', () async {
    final browser = ScriptedBrowser(
      probeBuilder: (y, _) =>
          lazyStripProbe(y: y, viewportHeight: vp, panelCount: 40),
    );
    await run(browser);

    final fastSteps = browser.scrollSteps.where((dy) => dy > (vp * 2)).length;
    expect(fastSteps, greaterThan(0), reason: 'fast mode must engage');
    expect(
      browser.scrollSteps.length,
      lessThan(40),
      reason:
          '80k px of resolved content must not take '
          '${browser.scrollSteps.length} careful steps',
    );
  });

  test('pending images nearby force the careful pace', () async {
    // Panels load only as the position approaches them (a strict lazy
    // loader). Fast steps are legal only once everything below is loaded —
    // never from a position with pending content in the lookahead.
    final browser = ScriptedBrowser(
      probeBuilder: (y, _) => lazyStripProbe(
        y: y,
        viewportHeight: vp,
        panelCount: 10,
        loadedUpTo: y + vp * 2,
      ),
    );
    await run(browser);

    // Reconstruct the position each step started from (same clamp as the
    // scripted browser) and check no fast jump left unloaded ground.
    const docHeight = 10 * 2000;
    // The last panel (top 18000) resolves once y + 2*vp exceeds it.
    const fullyLoadedFrom = 18000 - vp * 2;
    var y = 0;
    for (final dy in browser.scrollSteps) {
      if (dy > vp) {
        expect(
          y,
          greaterThanOrEqualTo(fullyLoadedFrom),
          reason: 'fast jump from $y while the loader was still behind',
        );
      }
      y = (y + dy).clamp(0, docHeight - vp);
    }
  });

  test('stable loaded regions accelerate after consecutive probes', () async {
    // First half pending on approach, second half pre-loaded: careful early,
    // fast late.
    final browser = ScriptedBrowser(
      probeBuilder: (y, _) => lazyStripProbe(
        y: y,
        viewportHeight: vp,
        panelCount: 30,
        loadedUpTo: y < 10000 ? y + vp * 2 : null,
      ),
    );
    await run(browser);

    final firstFastIndex = browser.scrollSteps.indexWhere((dy) => dy > vp * 2);
    expect(firstFastIndex, greaterThan(0), reason: 'starts careful');
    expect(
      browser.scrollSteps.take(firstFastIndex).every((dy) => dy <= vp),
      isTrue,
      reason: 'careful until the loaded region',
    );
  });

  test('end detection still stops at the bottom', () async {
    final browser = ScriptedBrowser(
      probeBuilder: (y, _) =>
          lazyStripProbe(y: y, viewportHeight: vp, panelCount: 6),
    );
    await run(browser);

    // Reached the bottom (position clamped to docH - vp) and stopped well
    // inside the iteration bound.
    expect(browser.y, 6 * 2000 - vp);
    expect(browser.scrollSteps.length, lessThan(config.maxScrollIterations));
  });

  test('a permanently pending avatar does not burn the asset wait', () async {
    final browser = ScriptedBrowser(
      probeBuilder: (y, _) => lazyStripProbe(
        y: y,
        viewportHeight: vp,
        panelCount: 5,
        extraImages: [avatarImage(1), avatarImage(2)],
      ),
    );
    const cfg = SaveConfig(
      scrollDelay: Duration(milliseconds: 5),
      fastScrollDelay: Duration(milliseconds: 1),
      quietPeriod: Duration.zero,
      requiredStableChecks: 1,
      maxScrollPasses: 1,
      maxAssetWait: Duration(seconds: 20),
      domReadyTimeout: Duration(seconds: 2),
      downloadRetries: 0,
    );
    final started = DateTime.now();
    await run(browser, cfg: cfg);
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 10)),
      reason: 'two unloadable avatars must not hold a 20s asset wait',
    );
  });

  test('a pending REAL panel still blocks premature completion', () async {
    // One content-sized image never resolves: the asset wait must hold for
    // it (bounded by maxAssetWait), unlike the avatar case.
    final browser = ScriptedBrowser(
      probeBuilder: (y, _) => lazyStripProbe(
        y: y,
        viewportHeight: vp,
        panelCount: 5,
        loadedUpTo: 4 * 2000, // the last panel never loads
      ),
    );
    final started = DateTime.now();
    await run(browser);
    expect(
      DateTime.now().difference(started),
      greaterThanOrEqualTo(config.maxAssetWait),
      reason: 'a pending content panel is worth waiting for',
    );
  });
}

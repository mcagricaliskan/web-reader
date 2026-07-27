// Optional live probe against two real sites.
//
//   flutter test integration_test/live_site_probe_test.dart -d <simulator-id>
//
// READ-ONLY on purpose: this loads ONE chapter per site, inspects the DOM, and
// reports what automatic detection would do. It does not download images and
// does not walk the chain — the brief asks for limited tests, and there is no
// reason to pull large portions of anyone's series to learn whether the
// heuristic fires.
//
// These sites change. Nothing here asserts a chapter number, an image count,
// or a DOM structure; the assertions are about *our* logic being able to reach
// a decision, and the output is a report for docs/IMPLEMENTATION_STATUS.md.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_reader/app.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/browser/page_data.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/image_candidates.dart';
import 'package:web_reader/capture/next_page.dart';
import 'package:web_reader/capture/site_rule.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

const liveTargets = <String, String>{
  'uzaymanga':
      'https://uzaymanga.com/manga/efsanevi-buyu-imparatoru/883-bolum-oku',
  'asurascans':
      'https://asurascans.com/comics/genius-archers-streaming-f886a8af/chapter/101',
};

/// Unique per process: a run that is killed mid-way never uninstalls the
/// app, so a fixed name would leak rows into the next invocation.
final String kRunStamp = DateTime.now().millisecondsSinceEpoch.toRadixString(
  36,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late BrowserController browser;

  // Plain waiting, not a pump loop. The WebView lives on the platform side, so
  // the Dart isolate does not need to pump frames for it to make progress —
  // and interleaving guarded `pump` calls with long real-async work is what
  // deadlocked the first version of this probe.
  Future<void> pumpFor(WidgetTester tester, Duration d) async {
    await Future<void>.delayed(d);
    await tester.pump();
  }

  Future<void> bootApp(WidgetTester tester) async {
    db = AppDatabase(name: 'it_live_probe_$kRunStamp');
    final fileStore = await FileStore.open(
      folderName: 'webread_it_live_probe_$kRunStamp',
    );
    browser = BrowserController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(
            AppServices(
              db: db,
              fileStore: fileStore,
              browser: browser,
              captureJob: CaptureJobController(
                browser: browser,
                db: db,
                fileStore: fileStore,
              ),
            ),
          ),
        ],
        child: const WebReaderApp(),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
  }

  tearDown(() async => db.close());

  for (final entry in liveTargets.entries) {
    testWidgets('live probe: ${entry.key}', (tester) async {
      await bootApp(tester);

      debugPrint('=== ${entry.key} :: ${entry.value}');
      await browser.loadAndWait(
        entry.value,
        timeout: const Duration(seconds: 45),
      );
      await pumpFor(tester, const Duration(seconds: 3));

      // One cheap probe first: if the bridge cannot reach this page at all,
      // say so immediately instead of burning the budget on doomed calls.
      final started = DateTime.now();
      try {
        final first = await browser.probe();
        debugPrint(
          '[${entry.key}] first probe OK in '
          '${DateTime.now().difference(started).inMilliseconds}ms · '
          'readyState=${first.readyState} images=${first.images.length} '
          'height=${first.documentHeight}',
        );
      } catch (e) {
        debugPrint(
          '[LIVE][${entry.key}] RESULT: UNREACHABLE url=${entry.value} — $e',
        );
        markTestSkipped('${entry.key} unreachable — NOT a verification');
        return;
      }

      // A gentle scroll so lazy loaders fire. Bail on the first failure
      // rather than serialising a dozen 20s timeouts.
      var scrollFailed = false;
      for (var i = 0; i < 5 && !scrollFailed; i++) {
        final t0 = DateTime.now();
        try {
          final r = await browser.scrollStep(1500);
          debugPrint(
            '[${entry.key}] scroll $i -> y=${r['scrollY']} '
            'h=${r['documentHeight']} '
            'in ${DateTime.now().difference(t0).inMilliseconds}ms',
          );
        } catch (e) {
          debugPrint(
            '[${entry.key}] scroll $i failed after '
            '${DateTime.now().difference(t0).inMilliseconds}ms: $e',
          );
          scrollFailed = true;
        }
        await pumpFor(tester, const Duration(milliseconds: 500));
      }

      late final PageProbe probe;
      try {
        probe = await browser.probe(withLinks: true);
      } catch (e) {
        debugPrint(
          '[LIVE][${entry.key}] RESULT: BLOCKED url=${entry.value} — '
          'probe-with-links failed: $e',
        );
        markTestSkipped('${entry.key} blocked — NOT a verification');
        return;
      }

      if (probe.images.isEmpty && probe.links.isEmpty) {
        debugPrint(
          '[LIVE][${entry.key}] RESULT: BLOCKED url=${entry.value} — '
          'page produced no DOM to inspect',
        );
        markTestSkipped('${entry.key} blocked — NOT a verification');
        return;
      }

      debugPrint(
        '[${entry.key}] title="${probe.title}" '
        'landed=${probe.url} '
        'height=${probe.documentHeight} images=${probe.images.length} '
        'links=${probe.links.length} '
        'resolved=${probe.resolvedImageCount} broken=${probe.brokenImageCount} '
        'truncated=${probe.imagesTruncated}',
      );
      debugPrint(
        '[${entry.key}] series=${seriesFingerprint(probe.url)} '
        'chapterNumber=${chapterNumberIn(probe.url)}',
      );

      // --- extraction ---------------------------------------------------
      final selection = selectImageCandidates(probe.images);
      final counts = <RejectReason, int>{};
      for (final r in selection.rejected) {
        counts.update(r.reason, (v) => v + 1, ifAbsent: () => 1);
      }
      debugPrint(
        '[${entry.key}] EXTRACTION: ${selection.acceptedCount} accepted, '
        '${selection.rejected.length} rejected '
        '${counts.entries.map((e) => '${e.key.name}=${e.value}').join(' ')}',
      );
      if (selection.accepted.isNotEmpty) {
        final first = selection.accepted.first;
        debugPrint(
          '[${entry.key}] first panel ${first.width}x${first.height} '
          '${first.url}',
        );
      }
      debugPrint(
        '[${entry.key}] EXTRACTION VERDICT: '
        '${selection.acceptedCount >= 3 ? "AUTOMATIC" : "NEEDS USER-SELECTED READER AREA"}',
      );

      // --- next-page detection ------------------------------------------
      final next = resolveNextPage(
        probe,
        currentUrl: probe.url,
        visitedNormalized: {},
      );
      for (final c in next.considered.take(6)) {
        debugPrint(
          '[${entry.key}]   candidate ${c.strategy.label}: ${c.href} '
          '(${c.evidence})',
        );
      }
      debugPrint(
        '[${entry.key}] NEXT VERDICT: ${next.decision.name} '
        '${next.chosen != null ? "-> ${next.chosen!.href} "
                  "(${next.chosen!.strategy.label}, "
                  "${next.chosen!.confidence?.name})" : ""} '
        'reason="${next.reason}"',
      );

      // The logic must always reach one of the three decisions rather than
      // throwing or hanging. Which one it reaches is site-dependent and is
      // reported, not asserted.
      expect(
        NextDecision.values.contains(next.decision),
        isTrue,
        reason: 'detection must always terminate in a decision',
      );
      debugPrint(
        '[LIVE][${entry.key}] RESULT: PASSED url=${entry.value} '
        '(read-only probe: extraction + next-detection reached decisions)',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}

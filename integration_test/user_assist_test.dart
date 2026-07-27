// The user-assisted fallback, end to end on a real WebView.
//
//   flutter test integration_test/user_assist_test.dart -d <simulator-id>
//
// Uses the in-process fixture, whose `/amb/` pages offer two equally plausible
// "next" controls and whose `/nolabel/` pages offer an icon with no rel, text
// or aria-label. Both are cases where guessing would be wrong, so the job must
// stop and ask — and then remember the answer.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_reader/app.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/capture/next_page.dart';
import 'package:web_reader/capture/rule_repository.dart';
import 'package:web_reader/capture/site_rule.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

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
  late RuleRepository rules;
  HttpServer? server;
  late String baseUrl;

  Future<void> startFixture() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server!.port}';
    unawaited(() async {
      try {
        await for (final req in server!) {
          try {
            await handleFixtureRequest(req, applyDelays: false);
          } catch (_) {}
        }
      } catch (_) {}
    }());
  }

  Future<void> stopFixture() async {
    await server?.close(force: true);
    server = null;
  }

  Future<void> settle(WidgetTester tester, Duration d) async {
    await Future<void>.delayed(d);
    await tester.pump();
  }

  Future<void> waitFor(
    WidgetTester tester,
    bool Function() done, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!done() && DateTime.now().isBefore(deadline)) {
      await settle(tester, const Duration(milliseconds: 200));
    }
    expect(done(), isTrue, reason: 'timed out waiting');
  }

  // One database per BOOT, not per file: every test here is self-contained
  // (each pre-teaches what it needs), and several assert that no rules exist
  // — which state left by an earlier test would falsify.
  var bootCount = 0;

  Future<void> bootApp(WidgetTester tester) async {
    bootCount++;
    db = AppDatabase(name: 'it_user_assist_${kRunStamp}_$bootCount');
    fileStore = await FileStore.open(
      folderName: 'webread_it_user_assist_${kRunStamp}_$bootCount',
    );
    browser = BrowserController();
    rules = RuleRepository(db);
    job = CaptureJobController(
      browser: browser,
      db: db,
      fileStore: fileStore,
      rules: rules,
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
  }

  tearDown(() async {
    // Stop the job and let it unwind *before* tearing down its dependencies:
    // closing the database under a running job produces spurious failures in
    // whichever test happens to run next.
    job.stop();
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (job.isRunning && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await stopFixture();
    await db.close();
  });

  testWidgets(
    'ambiguous page: the job asks, the answer is saved, the run continues',
    (tester) async {
      await startFixture();
      await bootApp(tester);
      await browser.loadAndWait('$baseUrl/amb/1');
      await settle(tester, const Duration(seconds: 1));

      unawaited(job.start(chapterLimit: 3));

      // Two plausible controls disagree -> the job must stop and ask.
      await waitFor(tester, () => job.pendingSelection != null);
      final request = job.pendingSelection!;
      expect(request.kind, RuleKind.nextLink);
      expect(request.prompt, 'Select the next chapter button');
      expect(request.candidates, isNotEmpty);
      expect(
        browser.isSelecting,
        isTrue,
        reason: 'the page must be in element-picking mode',
      );
      debugPrint('[assist] asked: ${request.reason}');
      for (final c in request.candidates) {
        debugPrint('[assist]   candidate ${c.strategy.label}: ${c.href}');
      }

      // Simulate the user tapping the correct control. This is exactly the
      // payload the injected picker reports.
      await job.submitSelection(
        SelectedElement(
          mode: 'link',
          tag: 'a',
          text: 'Next',
          href: '$baseUrl/amb/2',
        ),
      );

      await waitFor(
        tester,
        () => job.progress.state.isTerminal && !job.isRunning,
      );
      for (final line in job.log.reversed) {
        debugPrint('[job] $line');
      }

      // A rule was created, scoped to this series.
      final saved = await rules.all();
      expect(saved, hasLength(1));
      expect(saved.single.kind, RuleKind.nextLink);
      expect(saved.single.scope, RuleScope.series);
      expect(saved.single.host, '127.0.0.1');
      expect(saved.single.seriesPath, '/amb');
      debugPrint(
        '[assist] saved rule: host=${saved.single.host} '
        'series=${saved.single.seriesPath} '
        'signals=${saved.single.locator.signalCount} '
        'pattern=${saved.single.locator.hrefPattern}',
      );

      // The run continued past the ambiguous page using the answer.
      final chapters = await db.watchAllChapters().first;
      expect(
        chapters.length,
        greaterThanOrEqualTo(2),
        reason: 'the job continued after the prompt',
      );
      debugPrint('[assist] captured ${chapters.length} chapters');
    },
  );

  testWidgets('a saved rule is reused without asking again', (tester) async {
    await startFixture();
    await bootApp(tester);

    // Pre-teach the rule, as if a previous run had asked.
    await rules.createNextLinkRule(
      element: SelectedElement(
        mode: 'link',
        tag: 'a',
        text: 'Next',
        href: '$baseUrl/amb/2',
      ),
      sourceUrl: '$baseUrl/amb/1',
    );

    await browser.loadAndWait('$baseUrl/amb/1');
    await settle(tester, const Duration(seconds: 1));

    unawaited(job.start(chapterLimit: 2));
    await waitFor(
      tester,
      () => job.progress.state.isTerminal && !job.isRunning,
      timeout: const Duration(minutes: 2),
    );

    expect(
      job.pendingSelection,
      isNull,
      reason: 'a saved rule must stop the prompts — that is the point of it',
    );
    expect(
      job.log.any((l) => l.contains('using saved next-link rule')),
      isTrue,
    );
    final chapters = await db.watchAllChapters().first;
    expect(chapters.length, greaterThanOrEqualTo(2));
    debugPrint(
      '[assist] reused rule, captured ${chapters.length} chapters, '
      'never prompted',
    );
  });

  testWidgets('an unlabelled control also asks rather than guessing', (
    tester,
  ) async {
    await startFixture();
    await bootApp(tester);
    await browser.loadAndWait('$baseUrl/nolabel/1');
    await settle(tester, const Duration(seconds: 1));

    unawaited(job.start(chapterLimit: 2));
    await waitFor(tester, () => job.pendingSelection != null);

    expect(job.pendingSelection!.kind, RuleKind.nextLink);
    expect(job.progress.state, CaptureState.awaitingSelection);
    debugPrint('[assist] nolabel asked: ${job.pendingSelection!.reason}');

    // Cancelling ends the job rather than guessing on.
    await job.cancelSelection();
    await waitFor(tester, () => !job.isRunning);
    expect(job.progress.state, CaptureState.cancelled);
    expect(await rules.all(), isEmpty, reason: 'cancelling saves no rule');
  });

  testWidgets('a selected link that leaves the host is refused', (
    tester,
  ) async {
    await startFixture();
    await bootApp(tester);
    await browser.loadAndWait('$baseUrl/amb/1');
    await settle(tester, const Duration(seconds: 1));

    unawaited(job.start(chapterLimit: 2));
    await waitFor(tester, () => job.pendingSelection != null);

    // A user tap is a strong signal about one link — not permission to leave
    // the site.
    await job.submitSelection(
      const SelectedElement(
        mode: 'link',
        tag: 'a',
        text: 'Next',
        href: 'https://elsewhere.example/chapter/2',
      ),
    );

    expect(
      job.pendingSelection,
      isNotNull,
      reason: 'the prompt stays open when the selection is refused',
    );
    expect(job.pendingSelection!.errorMessage, isNotNull);
    expect(await rules.all(), isEmpty, reason: 'no rule from a refused link');
    debugPrint('[assist] refused: ${job.pendingSelection!.errorMessage}');

    await job.cancelSelection();
    await waitFor(tester, () => !job.isRunning);
  });

  testWidgets('automatic detection needs no prompt on the plain fixture', (
    tester,
  ) async {
    await startFixture();
    await bootApp(tester);
    await browser.loadAndWait('$baseUrl/chapter/1');
    await settle(tester, const Duration(seconds: 1));

    unawaited(job.start(chapterLimit: 2));
    await waitFor(
      tester,
      () => job.progress.state.isTerminal && !job.isRunning,
      timeout: const Duration(minutes: 3),
    );

    expect(
      job.pendingSelection,
      isNull,
      reason: 'rel=next is unambiguous; asking here would be a regression',
    );
    expect(await rules.all(), isEmpty);
    final chapters = await db.watchAllChapters().first;
    expect(chapters.length, 2);
    debugPrint(
      '[assist] fully automatic: ${chapters.length} chapters, '
      'no rules needed',
    );
  });
}

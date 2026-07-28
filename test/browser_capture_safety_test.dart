import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/app.dart';
import 'package:web_reader/browser/browser_presentation.dart';
import 'package:web_reader/browser/history_repository.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/queue/task_queue.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/ui/theme.dart';

import 'helpers/fake_browser.dart';

/// Browser Home, History and the queue, against the capture rules (§15, §16).
///
/// The rule under test: **hiding the rendered WebView is leaving the
/// Browser**, whether that is a tab switch, a route push, or a local overlay
/// going up over the page. All three ask the same question, and only when a
/// phase genuinely needs the surface.
void main() {
  late AppDatabase db;
  late Directory root;
  late FakeBrowser browser;
  late CaptureJobController job;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_browser_safety');
    browser = FakeBrowser();
    job = CaptureJobController(
      browser: browser,
      db: db,
      fileStore: FileStore(root),
      config: const CaptureConfig(),
    );
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void inState(CaptureState state) {
    job.debugSetRunning(true);
    job.debugSetProgress(
      CaptureProgress(
        state: state,
        currentUrl: 'https://x.example/manga/foo/1',
        chapterTitle: 'Chapter 1',
        storedChapters: 4,
        skippedChapters: 2,
        requestedChapters: 8,
      ),
    );
  }

  /// A guard that records whether it was consulted, and answers [allow].
  Widget guarded({
    required List<String> asked,
    required bool allow,
    required Widget child,
  }) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      theme: appTheme(),
      home: LeaveBrowserGuard(
        confirm: () async {
          // The shell only asks when a phase is at risk; mirror that here so
          // the test exercises the real predicate.
          if (!job.needsRenderedBrowser) return true;
          asked.add('confirm');
          if (allow) job.pauseForBrowserHidden();
          return allow;
        },
        child: Scaffold(body: child),
      ),
    ),
  );

  group('opening a local surface during a Browser-dependent phase', () {
    for (final state in const [
      CaptureState.inspecting,
      CaptureState.scrolling,
      CaptureState.extracting,
      CaptureState.detectingNext,
    ]) {
      testWidgets('${state.name}: opening Home asks first', (tester) async {
        inState(state);
        final asked = <String>[];
        final presentation = BrowserPresentation();
        addTearDown(presentation.dispose);

        await tester.pumpWidget(
          guarded(
            asked: asked,
            allow: true,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  if (await LeaveBrowserGuard.confirmLeave(context)) {
                    presentation.openHome();
                  }
                },
                child: const Text('Home'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();

        expect(asked, ['confirm']);
        expect(presentation.isHome, isTrue);
        // A hold, not a stop: the run is paused with a named reason.
        expect(job.pauseReason, kPauseBrowserHidden);
      });
    }

    testWidgets('choosing Stay leaves the page on screen and the run running',
        (tester) async {
      inState(CaptureState.scrolling);
      final asked = <String>[];
      final presentation = BrowserPresentation();
      addTearDown(presentation.dispose);

      await tester.pumpWidget(
        guarded(
          asked: asked,
          allow: false,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                if (await LeaveBrowserGuard.confirmLeave(context)) {
                  presentation.openHome();
                }
              },
              child: const Text('Home'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(asked, ['confirm']);
      expect(presentation.isHome, isFalse, reason: 'the page stays visible');
      expect(job.pauseReason, isNull);
    });

    testWidgets('opening full History asks the same question', (tester) async {
      inState(CaptureState.extracting);
      final asked = <String>[];
      var pushed = false;

      await tester.pumpWidget(
        guarded(
          asked: asked,
          allow: true,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                if (await LeaveBrowserGuard.confirmLeave(context)) {
                  pushed = true;
                }
              },
              child: const Text('History'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(asked, ['confirm']);
      expect(pushed, isTrue);
    });
  });

  group('when the confirmation must NOT appear', () {
    testWidgets('a queued-only capture never warns', (tester) async {
      // Queued is not running: the user may browse, open Home, go to Settings
      // — nothing is at risk because nothing has started (D46).
      await db.upsertQueueTask(
        QueueTask(
          id: 'q1',
          taskType: QueueTaskType.multiChapterCapture.name,
          startUrl: 'https://x.example/manga/foo/1',
          chapterLimit: 8,
          state: QueueTaskState.queued.name,
          orderIndex: 1,
          queuedAt: DateTime.now(),
        ),
      );
      expect(job.isRunning, isFalse);
      expect(job.needsRenderedBrowser, isFalse);

      final asked = <String>[];
      final presentation = BrowserPresentation();
      addTearDown(presentation.dispose);

      await tester.pumpWidget(
        guarded(
          asked: asked,
          allow: true,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                if (await LeaveBrowserGuard.confirmLeave(context)) {
                  presentation.openHome();
                }
              },
              child: const Text('Home'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(asked, isEmpty, reason: 'nothing is running');
      expect(presentation.isHome, isTrue);
    });

    for (final state in const [CaptureState.downloading, CaptureState.saving]) {
      testWidgets('${state.name}: the download-only phase does not warn',
          (tester) async {
        // After extraction only bytes and manifests remain; the Browser is no
        // longer required, so opening Home must be silent.
        inState(state);
        final asked = <String>[];
        final presentation = BrowserPresentation();
        addTearDown(presentation.dispose);

        await tester.pumpWidget(
          guarded(
            asked: asked,
            allow: true,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  if (await LeaveBrowserGuard.confirmLeave(context)) {
                    presentation.openHome();
                  }
                },
                child: const Text('Home'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Home'));
        await tester.pumpAndSettle();

        expect(asked, isEmpty);
        expect(presentation.isHome, isTrue);
        expect(job.pauseReason, isNull);
      });
    }

    testWidgets('an already-paused run is not asked about twice',
        (tester) async {
      inState(CaptureState.scrolling);
      job.pauseForBrowserHidden();
      expect(job.needsRenderedBrowser, isFalse);

      final asked = <String>[];
      await tester.pumpWidget(
        guarded(
          asked: asked,
          allow: true,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => LeaveBrowserGuard.confirmLeave(context),
              child: const Text('Home'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(asked, isEmpty);
    });
  });

  group('returning', () {
    test('resuming clears the pause reason and the persisted row', () async {
      inState(CaptureState.scrolling);
      await job.debugPersist();
      job.pauseForBrowserHidden();
      await Future<void>.delayed(Duration.zero);

      job.resumeAfterBrowserVisible();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(job.pauseReason, isNull);
      final persisted = await db.findResumableJob();
      expect(persisted?.pauseReason, isNull);
    });
  });

  group('automation never enters manual history', () {
    test('the whole chapter chain leaves the history empty', () async {
      final history = HistoryRepository(db);

      // What a capture run looks like from the controller's side.
      browser.automationOwner = 'a capture job';
      browser.navigationSource = NavigationSource.captureAutomation;
      for (var i = 1; i <= 8; i++) {
        await history.recordVisit(
          url: 'https://x.example/manga/foo/$i',
          title: 'Chapter $i',
          source: browser.effectiveNavigationSource,
        );
      }
      browser.automationOwner = null;
      browser.navigationSource = NavigationSource.manual;

      expect(await db.visits(), isEmpty);

      // The user then browses to the same site themselves: that one counts.
      await history.recordVisit(
        url: 'https://x.example/manga/foo/9',
        title: 'Chapter 9',
        source: browser.effectiveNavigationSource,
      );
      final rows = await db.visits();
      expect(rows, hasLength(1));
      expect(rows.single.url, 'https://x.example/manga/foo/9');
    });
  });

  group('queued captures are reflected, never started', () {
    test('the Browser only ever counts them', () async {
      final tasks = <QueueTask>[
        QueueTask(
          id: 'q1',
          taskType: QueueTaskType.multiChapterCapture.name,
          startUrl: 'https://x.example/1',
          state: QueueTaskState.queued.name,
          orderIndex: 1,
          queuedAt: DateTime.now(),
        ),
        QueueTask(
          id: 'q2',
          taskType: QueueTaskType.chapterCapture.name,
          startUrl: 'https://x.example/2',
          state: QueueTaskState.queued.name,
          orderIndex: 2,
          queuedAt: DateTime.now(),
        ),
        QueueTask(
          id: 'q3',
          taskType: QueueTaskType.seriesCheck.name,
          state: QueueTaskState.queued.name,
          orderIndex: 3,
          queuedAt: DateTime.now(),
        ),
      ];
      // The chip counts capture work only — a queued check is not something
      // the user has to start.
      expect(QueueSummary.of(tasks).queuedCaptures, 2);
    });
  });
}

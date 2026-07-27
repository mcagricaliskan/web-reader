import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

import 'helpers/fake_browser.dart';

/// Leaving the Browser mid-capture: which phases are actually at risk, what
/// pausing persists, and what returning restores.
void main() {
  late AppDatabase db;
  late Directory root;
  late FakeBrowser browser;
  late CaptureJobController job;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_leave');
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

  /// Put the controller in a given running state without a real run.
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

  group('which phases need the Browser', () {
    for (final state in const [
      CaptureState.inspecting,
      CaptureState.scrolling,
      CaptureState.waitingForAssets,
      CaptureState.verifying,
      CaptureState.extracting,
      CaptureState.detectingNext,
      CaptureState.navigating,
    ]) {
      test('${state.name} does need it', () {
        inState(state);
        expect(job.needsRenderedBrowser, isTrue);
      });
    }

    for (final state in const [CaptureState.downloading, CaptureState.saving]) {
      test('${state.name} does NOT — bytes over HTTP touch no layout', () {
        inState(state);
        expect(
          job.needsRenderedBrowser,
          isFalse,
          reason: 'the modal must not cry wolf during downloads',
        );
      });
    }

    test('an idle controller never needs it', () {
      expect(job.needsRenderedBrowser, isFalse);
    });

    test('an already-paused run never asks again', () {
      inState(CaptureState.scrolling);
      job.pauseForBrowserHidden();
      expect(job.needsRenderedBrowser, isFalse);
    });
  });

  test('pausing records the reason and stops nothing else', () {
    inState(CaptureState.scrolling);
    job.pauseForBrowserHidden();

    expect(job.pauseReason, kPauseBrowserHidden);
    expect(job.isRunning, isTrue, reason: 'held, not stopped');
    expect(
      job.log.join('\n'),
      contains('Browser was left'),
      reason: 'the reason is visible, not silent',
    );
  });

  test('the pause reason is persisted on the job row', () async {
    inState(CaptureState.scrolling);
    await job.debugPersist();
    job.pauseForBrowserHidden();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final row = await db.findResumableJob();
    expect(row, isNotNull);
    expect(row!.pauseReason, kPauseBrowserHidden);
  });

  test('returning to the Browser clears the pause', () async {
    inState(CaptureState.scrolling);
    await job.debugPersist();
    job.pauseForBrowserHidden();
    expect(job.pauseReason, kPauseBrowserHidden);

    job.resumeAfterBrowserVisible();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(job.pauseReason, isNull);
    expect(job.log.join('\n'), contains('Browser is visible again'));
    final row = await db.findResumableJob();
    expect(row?.pauseReason, isNull);
  });

  test('resuming only lifts a browser-hidden pause', () {
    inState(CaptureState.scrolling);
    job.pause(); // a plain user pause
    expect(job.pauseReason, isNull);

    job.resumeAfterBrowserVisible();
    // Nothing to lift: the user's own pause is untouched by the browser
    // lifecycle.
    expect(job.pauseReason, isNull);
  });

  test('the leave dialog gets a truthful progress line', () {
    inState(CaptureState.scrolling);
    final line = job.progressSummary;
    expect(line, contains('Chapter 1'));
    expect(line, contains('4 captured'));
    expect(line, contains('2 skipped'));
    expect(line, contains('4 remaining'));
  });
}

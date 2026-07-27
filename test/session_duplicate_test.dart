import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/capture/capture_preflight.dart';
import 'package:web_reader/capture/capture_state.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/reading/reading_position.dart';
import 'package:web_reader/reading/reading_repository.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';
import 'package:web_reader/storage/manifest.dart';

import 'package:drift/native.dart';

import '../tool/fixture/fixture_site.dart';
import 'helpers/fake_browser.dart';

/// Duplicates met DURING a running multi-chapter session.
///
/// The whole loop runs for real — preflight, prompt, engine, downloads over a
/// local HTTP server, atomic replacement — only the WebView is faked.
void main() {
  late AppDatabase db;
  late Directory root;
  late FileStore store;
  late FakeBrowser browser;
  late CaptureJobController job;
  late HttpServer server;
  late String assetBase;

  const host = 'https://x.example';
  String chapterUrl(int n) => '$host/manga/foo/$n';

  const config = CaptureConfig(
    scrollDelay: Duration.zero,
    quietPeriod: Duration.zero,
    requiredStableChecks: 1,
    maxScrollIterations: 2,
    maxScrollPasses: 1,
    domReadyTimeout: Duration(seconds: 2),
    maxAssetWait: Duration(seconds: 2),
    downloadRetries: 0,
    cooldownBetweenChapters: Duration.zero,
    maxChaptersPerJob: 6,
    maxSkippedPerJob: 4,
  );

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    assetBase = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      final match = RegExp(r'^/img/(\d+)/(\d+)\.png$').firstMatch(req.uri.path);
      if (match == null) {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      req.response.headers.contentType = ContentType('image', 'png');
      req.response.add(
        panelPng(
          chapter: int.parse(match.group(1)!),
          index: int.parse(match.group(2)!),
        ),
      );
      await req.response.close();
    });
  });

  tearDownAll(() => server.close(force: true));

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_session');
    store = FileStore(root);
    Directory(
      p.join(root.path, FileStore.libraryFolderName),
    ).createSync(recursive: true);
    Directory(
      p.join(root.path, FileStore.tmpFolderName),
    ).createSync(recursive: true);
    browser = FakeBrowser();
    job = CaptureJobController(
      browser: browser,
      db: db,
      fileStore: store,
      config: config,
    );
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Chapter pages 1..[count]; each links rel=next to its successor.
  void servePages(int count) {
    for (var n = 1; n <= count; n++) {
      browser.addPage(
        chapterUrl(n),
        chapterProbe(
          url: chapterUrl(n),
          title: 'Foo Chapter $n',
          imageUrls: [for (var i = 1; i <= 3; i++) '$assetBase/img/$n/$i.png'],
          nextHref: n < count ? chapterUrl(n + 1) : null,
        ),
      );
    }
  }

  Future<void> seedSeries() => db.upsertLibraryItem(
    LibraryItem(
      lifecycle: 'active',
      id: 'series-1',
      title: 'Foo',
      sourceUrl: '$host/manga/foo',
      host: 'x.example',
      seriesKey: '/manga/foo',
      createdAt: DateTime(2026, 7, 1),
    ),
  );

  /// A committed, complete (or partial) local chapter with real files.
  Future<void> seedCaptured(int n, {String status = 'complete'}) async {
    final id = 'c$n';
    final staging = await store.beginChapter(
      libraryItemId: 'series-1',
      chapterId: id,
    );
    await staging
        .assetFile('001.png')
        .writeAsBytes(panelPng(chapter: n, index: 1));
    final relative = await store.commit(
      staging,
      ChapterManifest(
        schemaVersion: 1,
        chapterId: id,
        libraryItemId: 'series-1',
        sourceUrl: chapterUrl(n),
        title: 'Foo Chapter $n',
        capturedAt: DateTime(2026, 7, 10),
        status: status == 'partial'
            ? CaptureStatus.partial
            : CaptureStatus.complete,
        detectedImageCount: 3,
        storedImageCount: status == 'partial' ? 1 : 3,
        assets: const [],
      ),
    );
    await db.upsertChapter(
      Chapter(
        id: id,
        libraryItemId: 'series-1',
        title: 'Foo Chapter $n',
        sourceUrl: chapterUrl(n),
        urlKey: chapterUrl(n),
        captureStatus: status,
        contentPath: relative,
        capturedAt: DateTime(2026, 7, 10),
        detectedImageCount: 3,
        storedImageCount: status == 'partial' ? 1 : 3,
        nextSourceUrl: chapterUrl(n + 1),
        sequence: n,
        byteSize: 128,
        chapterNumber: n.toDouble(),
        chapterLabel: 'Chapter $n',
        readStatus: 'unread',
        progressFraction: 0,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
      ),
    );
  }

  Future<void> until(
    bool Function() done, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> runJob(
    Future<void> run, {
    Duration timeout = const Duration(seconds: 60),
  }) => run.timeout(timeout);

  test('a duplicate met after new captures pauses and asks', () async {
    await seedSeries();
    await seedCaptured(2);
    servePages(3);
    browser.setUrl(chapterUrl(1));

    var prompts = 0;
    final run = job.start(
      chapterLimit: 2,
      startUrl: chapterUrl(1),
      policy: DuplicatePolicy.ask,
    );

    await until(() => job.pendingDuplicate != null);
    prompts++;
    final request = job.pendingDuplicate!;
    expect(request.state, ChapterLocalState.complete);
    expect(request.chapter!.id, 'c2');
    expect(
      request.availableActions,
      contains(DuplicateChoiceAction.redownload),
    );
    expect(
      request.availableActions,
      isNot(contains(DuplicateChoiceAction.retryMissing)),
      reason: 'a complete chapter has no missing files to retry',
    );
    expect(
      job.progress.state,
      CaptureState.awaitingSelection,
      reason: 'the job is holding, not downloading',
    );

    // Skip once, without making it a session policy.
    job.resolveDuplicate(const DuplicateChoice(DuplicateChoiceAction.skip));
    await runJob(run);

    expect(prompts, 1);
    expect(job.sessionDuplicateDecision, SessionDuplicateDecision.ask);
    final chapters = await db.allChapters();
    expect(chapters.length, 3, reason: 'ch1 + seeded ch2 + ch3');
    expect(
      chapters.where((c) => c.urlKey == chapterUrl(2)).single.capturedAt,
      DateTime(2026, 7, 10),
      reason: 'the skipped chapter was not touched',
    );
    expect(job.progress.storedChapters, 2, reason: 'requested 2 new, got 2');
    expect(job.progress.skippedChapters, 1);
  });

  test('"use this choice" skips every later complete duplicate', () async {
    await seedSeries();
    await seedCaptured(2);
    await seedCaptured(3);
    servePages(4);
    browser.setUrl(chapterUrl(1));

    var prompts = 0;
    DuplicateRequest? lastPrompt;
    job.addListener(() {
      final pending = job.pendingDuplicate;
      if (pending != null && !identical(pending, lastPrompt)) {
        prompts++;
        lastPrompt = pending;
      }
    });

    final run = job.start(
      chapterLimit: 2,
      startUrl: chapterUrl(1),
      policy: DuplicatePolicy.ask,
    );

    await until(() => job.pendingDuplicate != null);
    job.resolveDuplicate(
      const DuplicateChoice(DuplicateChoiceAction.skip, applyToSession: true),
    );
    await runJob(run);

    expect(prompts, 1, reason: 'chapter 3 must not ask again');
    expect(
      job.sessionDuplicateDecision,
      SessionDuplicateDecision.skipCompleteForSession,
    );
    expect(job.progress.storedChapters, 2, reason: 'ch1 and ch4');
    expect(job.progress.skippedChapters, 2);
    expect((await db.allChapters()).length, 4);
  });

  test('re-download once replaces files but keeps reading progress', () async {
    await seedSeries();
    await seedCaptured(2);
    servePages(2);
    final reading = ReadingRepository(db);
    await reading.saveProgress(
      'c2',
      const ReadingPosition(fraction: 0.6, imageIndex: 1, offsetInImage: 0.3),
      completed: true,
    );
    final before = (await db.chapterById('c2'))!;
    browser.setUrl(chapterUrl(2));

    final run = job.start(
      chapterLimit: 1,
      startUrl: chapterUrl(2),
      policy: DuplicatePolicy.ask,
    );
    await until(() => job.pendingDuplicate != null);
    job.resolveDuplicate(
      const DuplicateChoice(DuplicateChoiceAction.redownload),
    );
    await runJob(run);

    final rows = (await db.allChapters())
        .where((c) => c.urlKey == chapterUrl(2))
        .toList();
    expect(rows, hasLength(1), reason: 'no duplicate row');
    final after = rows.single;
    expect(after.id, 'c2');
    expect(after.storedImageCount, 3, reason: 'files genuinely re-fetched');
    expect(after.readStatus, 'completed');
    expect(after.progressImageIndex, 1);
    expect(after.completedAt, before.completedAt);
    expect(job.sessionDuplicateDecision, SessionDuplicateDecision.ask);
  });

  test('"use this choice" re-downloads every later duplicate', () async {
    await seedSeries();
    await seedCaptured(1);
    await seedCaptured(2);
    servePages(2);
    browser.setUrl(chapterUrl(1));

    var prompts = 0;
    DuplicateRequest? lastPrompt;
    job.addListener(() {
      final pending = job.pendingDuplicate;
      if (pending != null && !identical(pending, lastPrompt)) {
        prompts++;
        lastPrompt = pending;
      }
    });

    final run = job.start(
      chapterLimit: 2,
      startUrl: chapterUrl(1),
      policy: DuplicatePolicy.ask,
    );
    await until(() => job.pendingDuplicate != null);
    job.resolveDuplicate(
      const DuplicateChoice(
        DuplicateChoiceAction.redownload,
        applyToSession: true,
      ),
    );
    await runJob(run);

    expect(prompts, 1);
    expect(
      job.sessionDuplicateDecision,
      SessionDuplicateDecision.replaceCompleteForSession,
    );
    for (final c in await db.allChapters()) {
      expect(c.storedImageCount, 3, reason: '${c.title} was re-captured');
    }
    expect((await db.allChapters()).length, 2, reason: 'still two rows');
  });

  test('Stop capture ends the job cleanly and is never a policy', () async {
    await seedSeries();
    await seedCaptured(1);
    servePages(2);
    browser.setUrl(chapterUrl(1));

    final run = job.start(
      chapterLimit: 2,
      startUrl: chapterUrl(1),
      policy: DuplicatePolicy.ask,
    );
    await until(() => job.pendingDuplicate != null);
    job.resolveDuplicate(
      const DuplicateChoice(
        DuplicateChoiceAction.stopCapture,
        // Even asked-for, stop must not become a session decision.
        applyToSession: true,
      ),
    );
    await runJob(run);

    expect(job.progress.state, CaptureState.cancelled);
    expect(job.progress.storedChapters, 0);
    expect(job.sessionDuplicateDecision, SessionDuplicateDecision.ask);
    expect(job.sessionPartialDecision, SessionPartialDecision.ask);
  });

  test('a partial chapter offers repair choices, not complete ones', () async {
    await seedSeries();
    await seedCaptured(2, status: 'partial');
    servePages(2);
    browser.setUrl(chapterUrl(1));

    final run = job.start(
      chapterLimit: 2,
      startUrl: chapterUrl(1),
      policy: DuplicatePolicy.ask,
    );
    await until(() => job.pendingDuplicate != null);
    final request = job.pendingDuplicate!;
    expect(request.state, ChapterLocalState.partial);
    expect(
      request.availableActions,
      containsAll([
        DuplicateChoiceAction.retryMissing,
        DuplicateChoiceAction.restartChapter,
        DuplicateChoiceAction.skip,
        DuplicateChoiceAction.stopCapture,
      ]),
    );
    expect(
      request.availableActions,
      isNot(contains(DuplicateChoiceAction.redownload)),
    );

    job.resolveDuplicate(
      const DuplicateChoice(DuplicateChoiceAction.retryMissing),
    );
    await runJob(run);

    final fixed = (await db.chapterById('c2'))!;
    expect(fixed.captureStatus, 'complete');
    expect(fixed.storedImageCount, 3);
  });

  test('session decisions survive an interrupted-job resume', () async {
    await seedSeries();
    await seedCaptured(1);
    await seedCaptured(2);
    servePages(3);
    browser.setUrl(chapterUrl(1));

    // What an interrupted run that had answered "skip for session" leaves.
    await db.upsertJob(
      CaptureJob(
        rangeMode: 'fixedCount',
        id: 'job-interrupted',
        startUrl: chapterUrl(1),
        currentUrl: chapterUrl(1),
        requestedChapters: 1,
        completedChapters: 0,
        state: 'navigating',
        visitedUrls: '',
        duplicatePolicy: 'ask',
        sessionDuplicateDecision: 'skipCompleteForSession',
        sessionPartialDecision: 'ask',
        createdAt: DateTime(2026, 7, 27),
        updatedAt: DateTime(2026, 7, 27),
      ),
    );

    var prompted = false;
    job.addListener(() {
      if (job.pendingDuplicate != null) prompted = true;
    });

    final resumable = (await db.findResumableJob())!;
    await runJob(job.resumeJob(resumable));

    expect(prompted, isFalse, reason: 'the session already answered');
    expect(
      job.sessionDuplicateDecision,
      SessionDuplicateDecision.skipCompleteForSession,
    );
    expect(job.progress.storedChapters, 1, reason: 'ch3 captured');
    expect(job.progress.skippedChapters, 2);
  });

  test('a new job starts back at "ask"', () async {
    await seedSeries();
    servePages(1);
    browser.setUrl(chapterUrl(1));

    await runJob(
      job.start(
        chapterLimit: 1,
        startUrl: chapterUrl(1),
        policy: DuplicatePolicy.ask,
        sessionDuplicate: SessionDuplicateDecision.replaceCompleteForSession,
      ),
    );
    expect(
      job.sessionDuplicateDecision,
      SessionDuplicateDecision.replaceCompleteForSession,
    );

    // The next start resets: a session decision is not a preference.
    browser.setUrl(chapterUrl(1));
    final run = job.start(
      chapterLimit: 1,
      startUrl: chapterUrl(1),
      policy: DuplicatePolicy.ask,
    );
    await until(() => job.pendingDuplicate != null || !job.isRunning);
    expect(job.sessionDuplicateDecision, SessionDuplicateDecision.ask);
    if (job.pendingDuplicate != null) {
      job.resolveDuplicate(const DuplicateChoice(DuplicateChoiceAction.skip));
    }
    await runJob(run);
  });

  test(
    'the requested count means new captures, and the report says so',
    () async {
      await seedSeries();
      await seedCaptured(2);
      await seedCaptured(3);
      servePages(4);
      browser.setUrl(chapterUrl(1));

      await runJob(
        job.start(
          chapterLimit: 2,
          startUrl: chapterUrl(1),
          policy: DuplicatePolicy.ask,
          sessionDuplicate: SessionDuplicateDecision.skipCompleteForSession,
        ),
      );

      expect(job.progress.storedChapters, 2, reason: 'ch1 and ch4 are new');
      expect(job.progress.skippedChapters, 2);
      expect(job.progress.requestedChapters, 2);
      expect(
        job.progress.message,
        allOf(
          contains('Requested 2 new'),
          contains('captured 2'),
          contains('skipped 2 existing'),
          contains('traversed 4'),
        ),
      );
    },
  );

  test('skipping cannot become an unbounded crawl', () async {
    await seedSeries();
    for (var n = 1; n <= 6; n++) {
      await seedCaptured(n);
    }
    servePages(6);
    browser.setUrl(chapterUrl(1));

    await runJob(
      job.start(
        chapterLimit: 1,
        startUrl: chapterUrl(1),
        policy: DuplicatePolicy.ask,
        sessionDuplicate: SessionDuplicateDecision.skipCompleteForSession,
      ),
    );

    expect(job.progress.storedChapters, 0);
    expect(
      job.progress.skippedChapters,
      config.maxSkippedPerJob,
      reason: 'the skip bound ends the walk',
    );
    expect(job.log.join('\n'), contains('stopping rather than crawling'));
  });
}

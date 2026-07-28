import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/core/local_reset.dart';
import 'package:web_reader/library/update_checker.dart';
import 'package:web_reader/queue/task_queue.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

import 'helpers/fake_browser.dart';

/// The development reset: everything goes, in a controlled order, and a
/// partial failure says so rather than claiming success.
void main() {
  late AppDatabase db;
  late FakeBrowser browser;
  late Directory root;
  late FileStore store;
  late TaskQueueController queue;
  late CaptureJobController job;
  var cookiesCleared = 0;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    browser = FakeBrowser();
    root = Directory.systemTemp.createTempSync('webread_reset');
    store = FileStore(root);
    cookiesCleared = 0;
    job = CaptureJobController(browser: browser, db: db, fileStore: store);
    queue = TaskQueueController(
      db: db,
      browser: browser,
      captureJob: job,
      checker: UpdateChecker(browser: browser, db: db),
      captureRunner: (_) async => const QueueOutcome.success('x'),
      checkRunner: (_) async => const QueueOutcome.success('x'),
    );
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  LocalResetService makeService({Future<void> Function()? cookies}) =>
      LocalResetService(
        db: db,
        fileStore: store,
        browser: browser,
        captureJob: job,
        checker: UpdateChecker(browser: browser, db: db),
        taskQueue: queue,
        clearCookies:
            cookies ??
            () async {
              cookiesCleared++;
            },
      );

  /// A device that has been used: a series, a chapter with files on disk,
  /// reading progress, a queued task, a saved rule and a setting.
  Future<void> seedUsedApp() async {
    await db.upsertLibraryItem(
      LibraryItem(
        lifecycle: 'active',
        id: 'series-1',
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
        libraryItemId: 'series-1',
        title: 'Chapter 1',
        sourceUrl: 'https://x.example/manga/foo/1',
        urlKey: 'https://x.example/manga/foo/1',
        captureStatus: 'complete',
        contentPath: 'library/series-1/chapters/c1',
        capturedAt: DateTime(2026, 7, 20),
        detectedImageCount: 1,
        storedImageCount: 1,
        sequence: 1,
        byteSize: 64,
        chapterNumber: 1,
        chapterLabel: 'Chapter 1',
        readStatus: 'completed',
        progressFraction: 1,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
      ),
    );
    await db.setSetting('series.chapterSort', 'oldestFirst');
    await queue.enqueueCapture(
      startUrl: 'https://x.example/manga/foo/2',
      chapterLimit: 1,
    );

    final dir = Directory(p.join(root.path, 'library', 'series-1'))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'panel.png')).writeAsBytesSync([1, 2, 3]);
    Directory(
      p.join(root.path, 'tmp', 'staging-1'),
    ).createSync(recursive: true);
    Directory(
      p.join(root.path, 'library', 'series-1.previous'),
    ).createSync(recursive: true);
  }

  test('the developer tools are debug-only', () {
    // The test binary is a debug build, so the gate is open here — the value
    // being kDebugMode is what guarantees it is shut in release.
    expect(developerToolsAvailable, kDebugMode);
    expect(kReleaseMode, isFalse, reason: 'sanity: tests run in debug');
  });

  test('a used app comes back empty', () async {
    await seedUsedApp();
    expect(await db.allChapters(), isNotEmpty);

    final report = await makeService().resetEverything();

    expect(report.ok, isTrue, reason: report.toString());
    expect(await db.allChapters(), isEmpty);
    expect(await db.allLibraryItems(), isEmpty);
    expect(await db.watchQueueTasks().first, isEmpty);
    expect(await db.setting('series.chapterSort'), isNull);
  });

  test('every table is emptied, discovered from the schema', () async {
    await seedUsedApp();
    await makeService().resetEverything();

    // The wipe empties everything; the two rows that exist afterwards are the
    // clean-install seed put back on purpose (D54) — the default saved site
    // and the flag that stops it being seeded twice.
    const reseeded = {'saved_sites', 'settings'};

    for (final table in db.allTables) {
      if (reseeded.contains(table.actualTableName)) continue;
      final rows = await db
          .customSelect('SELECT COUNT(*) AS n FROM ${table.actualTableName}')
          .getSingle();
      expect(
        rows.read<int>('n'),
        0,
        reason: '${table.actualTableName} still has rows',
      );
    }

    final saved = await db.allSavedSites();
    expect(saved, hasLength(1), reason: 'the default saved site is restored');
    expect(saved.single.isDefault, isTrue);
    // Nothing the *user* set survives — only the seed marker.
    expect(await db.setting('series.chapterSort'), isNull);
  });

  test('captured files, staging and replacement backups all go', () async {
    await seedUsedApp();
    expect(
      Directory(p.join(root.path, 'library', 'series-1')).existsSync(),
      isTrue,
    );

    await makeService().resetEverything();

    expect(
      Directory(p.join(root.path, 'library', 'series-1')).existsSync(),
      isFalse,
    );
    expect(
      Directory(p.join(root.path, 'tmp', 'staging-1')).existsSync(),
      isFalse,
    );
    expect(
      Directory(p.join(root.path, 'library', 'series-1.previous')).existsSync(),
      isFalse,
    );
    // The empty skeleton is put back, so the next capture is a normal one.
    expect(Directory(p.join(root.path, 'library')).existsSync(), isTrue);
    expect(Directory(p.join(root.path, 'tmp')).existsSync(), isTrue);
  });

  test('cookies are cleared', () async {
    await seedUsedApp();
    await makeService().resetEverything();
    expect(cookiesCleared, 1);
  });

  test('a build with no cookie store reports skipped, not cleared', () async {
    final service = LocalResetService(
      db: db,
      fileStore: store,
      browser: browser,
      captureJob: job,
      checker: UpdateChecker(browser: browser, db: db),
      taskQueue: queue,
    );
    final report = await service.resetEverything();
    expect(report.ok, isTrue);
    expect(
      report.steps.firstWhere((s) => s.area == 'browser session').detail,
      contains('skipped'),
    );
  });

  test('active work is stopped before anything is deleted', () async {
    await seedUsedApp();
    browser.automationOwner = 'capture';

    await makeService().resetEverything();

    expect(browser.automationOwner, isNull);
    expect(await queue.queuedCaptures(), isEmpty);
    expect(queue.captureStartAuthorised, isFalse);
  });

  test('the report names every area', () async {
    await seedUsedApp();
    final report = await makeService().resetEverything();
    expect(report.steps.map((s) => s.area), [
      'active work',
      'database rows',
      'captured files',
      'browser session',
      'browser defaults',
    ]);
    expect(report.summary, contains('Reset complete'));
  });

  test('a failing area is reported, and does not claim success', () async {
    await seedUsedApp();
    final service = makeService(
      cookies: () async => throw StateError('cookie store unavailable'),
    );

    final report = await service.resetEverything();

    expect(report.ok, isFalse);
    expect(report.summary, contains('INCOMPLETE'));
    expect(report.failures.single.area, 'browser session');
    // The areas that DID work still worked — a partial failure leaves the
    // app recoverable, not half-wiped and lying about it.
    expect(await db.allChapters(), isEmpty);
    expect(
      Directory(p.join(root.path, 'library', 'series-1')).existsSync(),
      isFalse,
    );
  });

  test('resetting twice is harmless', () async {
    await seedUsedApp();
    await makeService().resetEverything();
    final second = await makeService().resetEverything();
    expect(second.ok, isTrue);
    expect(await db.allChapters(), isEmpty);
  });
}

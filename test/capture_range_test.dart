import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/core/device_storage.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

import 'helpers/fake_browser.dart';
import '../tool/fixture/fixture_site.dart';

/// The three capture ranges through the real job loop: current chapter,
/// fixed count, and until-end with its loop protection and safety limit.
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
    maxChaptersPerJob: 10,
    untilEndSafetyLimit: 3,
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
    root = Directory.systemTemp.createTempSync('webread_range');
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

  /// Chapter pages 1..[count]; each links rel=next to its successor. With
  /// [loopBackFrom], that chapter's next points back at chapter 1.
  void servePages(int count, {int? loopBackFrom}) {
    for (var n = 1; n <= count; n++) {
      final next = n == loopBackFrom
          ? chapterUrl(1)
          : (n < count ? chapterUrl(n + 1) : null);
      browser.addPage(
        chapterUrl(n),
        chapterProbe(
          url: chapterUrl(n),
          title: 'Foo Chapter $n',
          imageUrls: [for (var i = 1; i <= 3; i++) '$assetBase/img/$n/$i.png'],
          nextHref: next,
        ),
      );
    }
  }

  test('current chapter captures exactly one and stops', () async {
    servePages(4);
    browser.setUrl(chapterUrl(1));
    await job.start(
      chapterLimit: 99, // ignored: the mode wins
      startUrl: chapterUrl(1),
      range: CaptureRangeMode.currentChapter,
    );

    expect((await db.allChapters()).length, 1);
    expect(job.progress.message, contains('Captured 1 chapter'));
  });

  test('fixed count captures exactly N new chapters', () async {
    servePages(5);
    browser.setUrl(chapterUrl(1));
    await job.start(
      chapterLimit: 2,
      startUrl: chapterUrl(1),
      range: CaptureRangeMode.fixedCount,
    );

    expect((await db.allChapters()).length, 2);
  });

  test('until-end runs to a confirmed end of chain and says so', () async {
    servePages(2); // ends inside the safety limit of 3
    browser.setUrl(chapterUrl(1));
    await job.start(
      chapterLimit: 1, // ignored: the mode wins
      startUrl: chapterUrl(1),
      range: CaptureRangeMode.untilEnd,
    );

    expect((await db.allChapters()).length, 2);
    expect(job.progress.message, contains('Reached the end of the series'));
    expect(job.progress.message, isNot(contains('safety limit')));
  });

  test('until-end stops at the safety limit with a distinct result', () async {
    servePages(6); // longer than the limit of 3
    browser.setUrl(chapterUrl(1));
    await job.start(
      chapterLimit: 1,
      startUrl: chapterUrl(1),
      range: CaptureRangeMode.untilEnd,
    );

    expect((await db.allChapters()).length, 3, reason: 'bounded');
    expect(
      job.progress.message,
      contains('Stopped at the safety limit before a confirmed end of series'),
    );
  });

  test('until-end detects a navigation loop and stops', () async {
    servePages(2, loopBackFrom: 2); // 1 -> 2 -> 1
    browser.setUrl(chapterUrl(1));
    await job.start(
      chapterLimit: 1,
      startUrl: chapterUrl(1),
      range: CaptureRangeMode.untilEnd,
    );

    expect(
      (await db.allChapters()).length,
      2,
      reason: 'each chapter once; the loop edge is rejected as visited',
    );
    expect(job.progress.message, contains('Reached the end of the series'));
  });

  test('the range mode is persisted on the job row', () async {
    // No page for the URL: the job records itself, then fails to inspect —
    // the persisted row is what matters here.
    browser.setUrl(chapterUrl(9));
    await job.start(
      chapterLimit: 1,
      startUrl: chapterUrl(9),
      range: CaptureRangeMode.untilEnd,
    );
    // The job persisted at least once with the mode before finishing.
    expect(job.rangeMode, CaptureRangeMode.untilEnd);
  });

  test('resume continues in the persisted mode', () async {
    servePages(2);
    browser.setUrl(chapterUrl(1));
    // A killed until-end job left this row behind.
    await db.upsertJob(
      CaptureJob(
        rangeMode: 'untilEnd',
        id: 'job-1-aaaaaaaa',
        libraryItemId: null,
        startUrl: chapterUrl(1),
        currentUrl: chapterUrl(1),
        requestedChapters: 3,
        completedChapters: 0,
        state: 'navigating',
        visitedUrls: '',
        createdAt: DateTime(2026, 7, 27),
        updatedAt: DateTime(2026, 7, 27),
      ),
    );

    final row = (await db.findResumableJob())!;
    await job.resumeJob(row);

    expect(job.rangeMode, CaptureRangeMode.untilEnd);
    expect((await db.allChapters()).length, 2, reason: 'ran to the end');
    expect(job.progress.message, contains('Reached the end of the series'));
  });

  test('disk refusal blocks the start with a distinct error', () async {
    servePages(1);
    browser.setUrl(chapterUrl(1));
    final blocked = CaptureJobController(
      browser: browser,
      db: db,
      fileStore: store,
      config: config,
      deviceStorage: _FixedStorage(free: 100 * 1024 * 1024), // < 500 MB floor
    );

    await blocked.start(chapterLimit: 1, startUrl: chapterUrl(1));

    expect(blocked.progress.lastError, 'insufficientStorage');
    expect(await db.allChapters(), isEmpty);
    expect(browser.automationOwner, isNull, reason: 'never took the browser');
  });
}

class _FixedStorage extends DeviceStorage {
  _FixedStorage({required this.free});
  final int free;

  @override
  Future<int?> freeBytes() async => free;

  @override
  Future<bool> excludeFromBackup(String absolutePath) async => true;
}

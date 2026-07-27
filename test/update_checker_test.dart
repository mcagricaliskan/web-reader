import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/browser/page_data.dart';
import 'package:web_reader/capture/capture_preflight.dart';
import 'package:web_reader/library/update_checker.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

import 'helpers/fake_browser.dart';

/// The M8 update check: bounded, metadata-only discovery over the same
/// navigation trust chain captures use.
void main() {
  late AppDatabase db;
  late FakeBrowser browser;
  late UpdateChecker checker;

  const host = 'https://x.example';
  String chapterUrl(int n) => '$host/manga/foo/$n';
  const seriesUrl = '$host/manga/foo';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    browser = FakeBrowser();
    checker = UpdateChecker(
      browser: browser,
      db: db,
      config: const UpdateCheckConfig(cooldownBetweenPages: Duration.zero),
    );
  });

  tearDown(() => db.close());

  Future<void> seedSeries({String? withSeriesUrl}) => db.upsertLibraryItem(
    LibraryItem(
      lifecycle: 'active',
      id: 'series-1',
      title: 'Foo',
      sourceUrl: seriesUrl,
      host: 'x.example',
      seriesKey: '/manga/foo',
      seriesUrl: withSeriesUrl,
      createdAt: DateTime(2026, 7, 1),
    ),
  );

  Future<void> seedCaptured(int n, {String? nextUrl}) => db.upsertChapter(
    Chapter(
      id: 'ch$n',
      libraryItemId: 'series-1',
      title: 'Foo Chapter $n',
      sourceUrl: chapterUrl(n),
      urlKey: chapterUrl(n),
      captureStatus: 'complete',
      contentPath: 'library/series-1/chapters/ch$n',
      capturedAt: DateTime(2026, 7, 10),
      detectedImageCount: 3,
      storedImageCount: 3,
      nextSourceUrl: nextUrl,
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

  /// Chapter pages [from]..[to], each linking rel=next to its successor.
  void serveChain(int from, int to) {
    for (var n = from; n <= to; n++) {
      browser.addPage(
        chapterUrl(n),
        chapterProbe(
          url: chapterUrl(n),
          title: 'Foo Chapter $n',
          imageUrls: const [],
          nextHref: n < to ? chapterUrl(n + 1) : null,
        ),
      );
    }
  }

  group('next-chain discovery', () {
    test('finds new chapters without downloading anything', () async {
      await seedSeries();
      await seedCaptured(1, nextUrl: chapterUrl(2));
      await seedCaptured(2); // captured while it was the newest — no next
      serveChain(2, 4);

      final outcome = await checker.check('series-1');

      expect(outcome.state, UpdateCheckState.updatesAvailable);
      expect(outcome.newChapters, 2);

      final discovered = (await db.allChapters())
          .where((c) => c.captureStatus == 'knownRemote')
          .toList();
      expect(discovered, hasLength(2));
      for (final c in discovered) {
        expect(c.contentPath, isNull, reason: 'metadata only, no bytes');
        expect(c.storedImageCount, 0);
        expect(c.discoveredAt, isNotNull);
        expect(c.discoveryBasis, 'nextChain');
      }
      expect(discovered.map((c) => c.chapterNumber), containsAll([3.0, 4.0]));
    });

    test('a second check discovers nothing new and reports upToDate', () async {
      await seedSeries();
      await seedCaptured(1, nextUrl: chapterUrl(2));
      await seedCaptured(2);
      serveChain(2, 4);

      await checker.check('series-1');
      final second = await checker.check('series-1');

      expect(second.state, UpdateCheckState.upToDate);
      expect(second.newChapters, 0);
      expect(
        (await db.allChapters())
            .where((c) => c.captureStatus == 'knownRemote')
            .length,
        2,
        reason: 'no duplicate discovery rows',
      );
    });

    test(
      'check state is persisted on the series, including failures',
      () async {
        await seedSeries();
        await seedCaptured(1, nextUrl: chapterUrl(2));
        await seedCaptured(2);
        serveChain(2, 3);

        await checker.check('series-1');
        var item = (await db.libraryItemById('series-1'))!;
        expect(item.lastCheckAt, isNotNull);
        expect(item.lastCheckSuccessAt, isNotNull);
        expect(item.lastCheckResult, 'updatesAvailable');
        expect(item.lastCheckError, isNull);

        // Now a failing check: the latest chapter's page does not exist.
        await db.upsertChapter(
          (await db.chapterById('ch2'))!.copyWith(sourceUrl: '$host/gone'),
        );
        browser.pages.clear();
        final failing = await checker.check('series-1');
        expect(failing.state, UpdateCheckState.failed);

        item = (await db.libraryItemById('series-1'))!;
        expect(item.lastCheckResult, 'failed');
        expect(item.lastCheckError, isNotNull);
      },
    );

    test('bounded: stops at maxNewChapters and maxPagesInspected', () async {
      final bounded = UpdateChecker(
        browser: browser,
        db: db,
        config: const UpdateCheckConfig(
          maxNewChapters: 3,
          maxPagesInspected: 5,
          cooldownBetweenPages: Duration.zero,
        ),
      );
      await seedSeries();
      await seedCaptured(1, nextUrl: chapterUrl(2));
      await seedCaptured(2);
      serveChain(2, 40); // a "site" with vastly more than the bound

      final outcome = await bounded.check('series-1');

      expect(outcome.state, UpdateCheckState.updatesAvailable);
      expect(outcome.newChapters, 3);
      expect(
        outcome.pagesInspected,
        lessThanOrEqualTo(5),
        reason: 'never an unbounded crawl',
      );
    });

    test('cancel stops the walk and keeps what was found', () async {
      await seedSeries();
      await seedCaptured(1, nextUrl: chapterUrl(2));
      await seedCaptured(2);
      serveChain(2, 10);

      // Cancel as soon as the first discovery lands.
      checker.addListener(() {
        if (checker.log.any((l) => l.contains('found:'))) checker.cancel();
      });

      final outcome = await checker.check('series-1');
      expect(outcome.state, UpdateCheckState.cancelled);
      expect(
        (await db.allChapters())
            .where((c) => c.captureStatus == 'knownRemote')
            .length,
        greaterThanOrEqualTo(1),
        reason: 'discovered metadata is kept, not rolled back',
      );

      final item = (await db.libraryItemById('series-1'))!;
      expect(item.lastCheckResult, 'cancelled');
    });

    test('a next link that leaves the series ends the check', () async {
      await seedSeries();
      await seedCaptured(1, nextUrl: chapterUrl(2));
      await seedCaptured(2);
      browser.addPage(
        chapterUrl(2),
        chapterProbe(
          url: chapterUrl(2),
          title: 'Foo Chapter 2',
          imageUrls: const [],
          nextHref: '$host/manga/OTHER-SERIES/1',
        ),
      );

      final outcome = await checker.check('series-1');
      expect(outcome.state, UpdateCheckState.upToDate);
      expect(outcome.newChapters, 0);
      expect(
        (await db.chaptersForItem('series-1')).length,
        2,
        reason: 'nothing from another series was recorded',
      );
    });

    test('refuses to run while something else drives the browser', () async {
      await seedSeries();
      await seedCaptured(1);
      browser.automationOwner = 'a capture job';

      final outcome = await checker.check('series-1');
      expect(outcome.state, UpdateCheckState.failed);
      expect(outcome.error, contains('capture job'));

      browser.automationOwner = null;
    });

    test('a discovered chapter is free to capture, not a failed one', () async {
      await seedSeries();
      await seedCaptured(1, nextUrl: chapterUrl(2));
      await seedCaptured(2);
      serveChain(2, 3);
      await checker.check('series-1');

      final discovered = (await db.allChapters())
          .where((c) => c.captureStatus == 'knownRemote')
          .single;
      expect(discovered.chapterNumber, 3.0);

      final root = Directory.systemTemp.createTempSync('webread_uc');
      addTearDown(() => root.deleteSync(recursive: true));
      final preflight = await CapturePreflight(
        db: db,
        fileStore: FileStore(root),
      ).inspect(discovered.sourceUrl, libraryItemId: 'series-1');

      expect(
        preflight.state,
        ChapterLocalState.none,
        reason: 'capturing it must neither prompt nor look like a retry',
      );
    });
  });

  group('chapter-list discovery (pure)', () {
    PageProbe listProbe(List<PageLink> links) => PageProbe(
      url: seriesUrl,
      title: 'Foo — all chapters',
      readyState: 'complete',
      links: links,
    );

    test('new numbered chapters above the latest known are found', () {
      final probe = listProbe([
        const PageLink(href: '/manga/foo/1', text: 'Chapter 1'),
        const PageLink(href: '/manga/foo/2', text: 'Chapter 2'),
        const PageLink(href: '/manga/foo/3', text: 'Chapter 3'),
        const PageLink(href: '/manga/foo/4', text: 'Chapter 4'),
        // Same host, different series: must not leak in.
        const PageLink(href: '/manga/bar/9', text: 'Chapter 9'),
        // Unnumbered: cannot be established as new from a list alone.
        const PageLink(href: '/manga/foo/extra', text: 'Extra'),
      ]);

      final result = discoverFromChapterList(
        probe,
        seriesKey: '/manga/foo',
        latestKnownNumber: 2,
        knownUrlKeys: {chapterUrl(1), chapterUrl(2)},
      );

      expect(result.listRecognised, isTrue);
      expect(result.newChapters.map((c) => c.number), [3.0, 4.0]);
      expect(result.knownSeen, 2);
    });

    test('an unrelated page is not "up to date", it is unrecognised', () {
      final probe = listProbe([
        const PageLink(href: '/about', text: 'About us'),
        const PageLink(href: '/login', text: 'Login'),
      ]);

      final result = discoverFromChapterList(
        probe,
        seriesKey: '/manga/foo',
        latestKnownNumber: 2,
        knownUrlKeys: {chapterUrl(1), chapterUrl(2)},
      );

      expect(
        result.listRecognised,
        isFalse,
        reason: 'a 404 or an error page must fall back to the chain walk',
      );
      expect(result.newChapters, isEmpty);
    });

    test('respects the maxNew bound', () {
      final probe = listProbe([
        for (var n = 1; n <= 30; n++)
          PageLink(href: '/manga/foo/$n', text: 'Chapter $n'),
      ]);

      final result = discoverFromChapterList(
        probe,
        seriesKey: '/manga/foo',
        latestKnownNumber: 2,
        knownUrlKeys: {chapterUrl(1), chapterUrl(2)},
        maxNew: 5,
      );

      expect(result.newChapters, hasLength(5));
      expect(
        result.newChapters.first.number,
        3.0,
        reason: 'oldest new first, so capture continues in reading order',
      );
    });
  });
}

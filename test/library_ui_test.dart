import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/features/library_screen.dart';
import 'package:web_reader/features/series_detail_screen.dart';
import 'package:web_reader/library/series_repository.dart';
import 'package:web_reader/library/update_checker.dart';
import 'package:web_reader/reading/reading_position.dart';
import 'package:web_reader/reading/reading_repository.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

/// The grouped library and series detail, driven as widgets.
///
/// The offline reader is not built here (it needs a real FileStore), but the
/// route a chapter tile pushes is asserted — the reader must stay reachable
/// through the new screens.
void main() {
  late AppDatabase db;
  late Directory harnessRoot;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    harnessRoot = Directory.systemTemp.createTempSync('webread_ui');
  });
  tearDown(() async {
    await db.close();
    if (harnessRoot.existsSync()) harnessRoot.deleteSync(recursive: true);
  });

  const series = 'https://uzay.example/manga/efsanevi-buyu-imparatoru';

  Future<String> seedSeries({
    String host = 'uzay.example',
    String seriesUrl = series,
    List<int> chapters = const [883, 884, 885],
    String status = 'complete',
  }) async {
    final repo = SeriesRepository(db);
    String? groupId;
    for (final n in chapters) {
      final url = '$seriesUrl/$n-bolum-oku';
      final title = 'Efsanevi Büyü İmparatoru $n. Bölüm - Oku';
      final group = await repo.resolveGroup(chapterUrl: url, pageTitle: title);
      groupId = group.id;
      await db.upsertChapter(
        Chapter(
          id: 'c$n-$host',
          libraryItemId: group.id,
          title: title,
          sourceUrl: url,
          urlKey: url,
          captureStatus: n == chapters.last ? status : 'complete',
          contentPath: 'library/${group.id}/chapters/c$n-$host',
          capturedAt: DateTime(2026, 7, 20).add(Duration(days: n - 883)),
          detectedImageCount: 6,
          storedImageCount: status == 'partial' && n == chapters.last ? 5 : 6,
          sequence: n - 882,
          byteSize: 2048,
          chapterNumber: n.toDouble(),
          chapterLabel: '$n. Bölüm',
          readStatus: 'unread',
          progressFraction: 0,
          progressImageIndex: 0,
          progressOffsetInImage: 0,
        ),
      );
    }
    return groupId!;
  }

  String? lastPushedRoute;

  /// Pump until the widget under test has data.
  ///
  /// Not `pumpAndSettle`: while the stream provider is still loading, the
  /// screen shows a CircularProgressIndicator, which animates forever and
  /// makes `pumpAndSettle` hang until it times out.
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('timed out waiting for $finder');
  }

  Widget harness(Widget child) {
    lastPushedRoute = null;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => child),
        GoRoute(
          path: '/series/:id',
          builder: (context, state) {
            lastPushedRoute = state.uri.toString();
            return SeriesDetailScreen(seriesId: state.pathParameters['id']!);
          },
        ),
        GoRoute(
          path: '/reader/:chapterId',
          builder: (context, state) {
            lastPushedRoute = state.uri.toString();
            return const Scaffold(body: Text('READER'));
          },
        ),
        GoRoute(path: '/rules', builder: (_, _) => const SizedBox()),
      ],
    );
    // The series detail screen reaches the update checker and the capture
    // job (for the check/capture actions); both get inert instances over an
    // unattached browser, so no WebView is ever stood up.
    final browser = BrowserController();
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        updateCheckerProvider.overrideWithValue(
          UpdateChecker(browser: browser, db: db),
        ),
        captureJobProvider.overrideWithValue(
          CaptureJobController(
            browser: browser,
            db: db,
            fileStore: FileStore(harnessRoot),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  final seriesRows = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('seriesRow-'),
  );

  group('grouped library screen', () {
    screenTest('shows one row per series, not one row per chapter', (
      tester,
    ) async {
      await seedSeries();
      await tester.pumpWidget(harness(const LibraryScreen()));
      await pumpUntil(tester, find.text('Efsanevi Büyü İmparatoru'));

      // The name also appears on the Continue card, so count the series rows
      // instead: exactly one in All Series.
      expect(seriesRows, findsOneWidget);
      expect(find.textContaining('3 unread'), findsOneWidget);
      // The chapter labels belong on the detail screen, not the library list.
      expect(find.text('884. Bölüm'), findsNothing);
    });

    screenTest('two series on one host appear as two rows', (tester) async {
      await seedSeries();
      await seedSeries(
        seriesUrl: 'https://uzay.example/manga/baska-seri',
        chapters: const [1, 2],
        host: 'other',
      );

      await tester.pumpWidget(harness(const LibraryScreen()));
      await pumpUntil(tester, seriesRows);

      expect(seriesRows, findsNWidgets(2));
    });

    screenTest('flags a series containing a partial chapter', (tester) async {
      await seedSeries(status: 'partial');
      await tester.pumpWidget(harness(const LibraryScreen()));
      await pumpUntil(tester, find.textContaining('1 chapter partial'));

      expect(find.textContaining('1 chapter partial'), findsOneWidget);
    });

    screenTest('opens the series detail screen on tap', (tester) async {
      final id = await seedSeries();
      await tester.pumpWidget(harness(const LibraryScreen()));
      await pumpUntil(tester, seriesRows);

      await tester.tap(
        find
            .descendant(of: seriesRows.first, matching: find.byType(InkWell))
            .first,
      );
      await pumpUntil(tester, find.text('883. Bölüm'));

      expect(lastPushedRoute, '/series/$id');
      expect(find.text('883. Bölüm'), findsOneWidget);
    });
  });

  group('continue reading', _continueReadingTests);

  final chapterRows = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('chapterRow-'),
  );

  group('series detail screen', () {
    screenTest('lists chapters in reading order', (tester) async {
      final id = await seedSeries();
      await tester.pumpWidget(harness(SeriesDetailScreen(seriesId: id)));
      await pumpUntil(tester, chapterRows);

      final labels = [
        for (final row in tester.widgetList<InkWell>(chapterRows))
          ((row.key! as ValueKey<String>).value),
      ];
      expect(labels, [
        'chapterRow-c883-uzay.example',
        'chapterRow-c884-uzay.example',
        'chapterRow-c885-uzay.example',
      ]);
    });

    screenTest('shows stored counts and capture status', (tester) async {
      final id = await seedSeries(status: 'partial');
      await tester.pumpWidget(harness(SeriesDetailScreen(seriesId: id)));
      await pumpUntil(tester, find.textContaining('5/6 images'));

      expect(find.textContaining('5/6 images'), findsOneWidget);
      expect(find.textContaining('6/6 images'), findsNWidgets(2));
    });

    screenTest('a chapter tile opens the offline reader', (tester) async {
      final id = await seedSeries();
      await tester.pumpWidget(harness(SeriesDetailScreen(seriesId: id)));
      await pumpUntil(tester, find.text('884. Bölüm'));

      await tester.tap(find.text('884. Bölüm'));
      await pumpUntil(tester, find.text('READER'));

      expect(lastPushedRoute, '/reader/c884-uzay.example');
      expect(find.text('READER'), findsOneWidget);
    });

    screenTest('renaming changes the heading, not the identity', (
      tester,
    ) async {
      final id = await seedSeries();
      await tester.pumpWidget(harness(SeriesDetailScreen(seriesId: id)));
      await pumpUntil(tester, find.byTooltip('Series actions'));

      final before = (await db.libraryItemById(id))!;

      await tester.tap(find.byTooltip('Series actions'));
      await pumpUntil(tester, find.text('Rename'));
      // The sheet slides in; tapping mid-animation lands off-screen.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Rename'));
      await pumpUntil(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'My Shelf Name');
      await tester.tap(find.text('Save'));
      await pumpUntil(tester, find.text('My Shelf Name'));

      expect(find.text('My Shelf Name'), findsWidgets);

      final after = (await db.libraryItemById(id))!;
      expect(after.userTitle, 'My Shelf Name');
      expect(after.seriesKey, before.seriesKey);
      expect(after.title, before.title);
      expect(after.sourceUrl, before.sourceUrl);
    });

    screenTest('a chapter with no local files is not tappable', (tester) async {
      final id = await seedSeries(chapters: const [883]);
      await db.markChapterContentMissing('c883-uzay.example');

      await tester.pumpWidget(harness(SeriesDetailScreen(seriesId: id)));
      await pumpUntil(tester, chapterRows);

      final row = tester.widget<InkWell>(chapterRows);
      expect(row.onTap, isNull, reason: 'nothing to open');
    });
  });

  group('read vs captured are separate states (P0.2)', () {
    screenTest('a captured, unread chapter never shows a checkmark', (
      tester,
    ) async {
      final id = await seedSeries(); // three complete, all unread

      await tester.pumpWidget(harness(SeriesDetailScreen(seriesId: id)));
      await pumpUntil(tester, find.text('884. Bölüm'));

      expect(
        find.byIcon(Icons.check_circle_outline),
        findsNothing,
        reason:
            'the checkmark is the READ vocabulary; capture-complete must '
            'not borrow it',
      );
      expect(
        find.descendant(
          of: chapterRows,
          matching: find.byIcon(Icons.download_for_offline),
        ),
        findsNWidgets(3),
        reason: 'capture-complete uses the download/offline vocabulary',
      );
      expect(
        find.byKey(const ValueKey('unreadDot-c883-uzay.example')),
        findsOneWidget,
        reason: 'unread chapters carry an explicit unread indicator',
      );
    });

    screenTest('reading a chapter moves only the read indicator', (
      tester,
    ) async {
      final id = await seedSeries();
      await ReadingRepository(db).markRead('c883-uzay.example');

      await tester.pumpWidget(harness(SeriesDetailScreen(seriesId: id)));
      await pumpUntil(tester, find.byIcon(Icons.check_circle_outline));

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(
        find.descendant(
          of: chapterRows,
          matching: find.byIcon(Icons.download_for_offline),
        ),
        findsNWidgets(3),
        reason: 'capture state is untouched by reading',
      );
      expect(
        find.byKey(const ValueKey('unreadDot-c883-uzay.example')),
        findsNothing,
      );
    });

    screenTest('an in-progress chapter shows its percentage, not a check', (
      tester,
    ) async {
      final id = await seedSeries();
      await ReadingRepository(db).saveProgress(
        'c884-uzay.example',
        const ReadingPosition(fraction: 0.42, imageIndex: 2),
      );

      await tester.pumpWidget(harness(SeriesDetailScreen(seriesId: id)));
      await pumpUntil(tester, find.text('42%'));

      expect(find.text('42%'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    screenTest('the series card counts unread offline chapters', (
      tester,
    ) async {
      final id = await seedSeries();
      await tester.pumpWidget(harness(const LibraryScreen()));
      await pumpUntil(tester, find.textContaining('3 unread'));
      expect(find.textContaining('3 unread'), findsOneWidget);

      await ReadingRepository(db).markRead('c883-uzay.example');
      await pumpUntil(tester, find.textContaining('2 unread'));
      expect(find.textContaining('3 unread'), findsNothing);
      expect(id, isNotEmpty);
    });

    screenTest('a chapter row inserted with no reading fields is unread', (
      tester,
    ) async {
      // The database default is the last line of defence: a bare insert (as
      // a migration or an old code path would produce) must come out unread.
      final id = await seedSeries(chapters: const [883]);
      await db
          .into(db.chapters)
          .insert(
            ChaptersCompanion.insert(
              id: 'bare',
              libraryItemId: id,
              title: 'Efsanevi Büyü İmparatoru 990. Bölüm',
              sourceUrl: '$series/990-bolum-oku',
              urlKey: '$series/990-bolum-oku',
              captureStatus: 'complete',
              contentPath: const Value('library/x/chapters/bare'),
              chapterNumber: const Value(990),
              chapterLabel: const Value('990. Bölüm'),
            ),
          );

      expect((await db.chapterById('bare'))!.readStatus, 'unread');

      await tester.pumpWidget(harness(SeriesDetailScreen(seriesId: id)));
      await pumpUntil(tester, find.text('990. Bölüm'));
      expect(find.byKey(const ValueKey('unreadDot-bare')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });
  });

  group('new chapters (M8)', () {
    /// A chapter an update check discovered: known on the source, no bytes.
    Future<void> seedKnownRemote(String groupId, int n) => db.upsertChapter(
      Chapter(
        id: 'r$n',
        libraryItemId: groupId,
        title: 'Efsanevi Büyü İmparatoru $n. Bölüm',
        sourceUrl: '$series/$n-bolum-oku',
        urlKey: '$series/$n-bolum-oku',
        captureStatus: 'knownRemote',
        detectedImageCount: 0,
        storedImageCount: 0,
        sequence: n - 882,
        byteSize: 0,
        chapterNumber: n.toDouble(),
        chapterLabel: '$n. Bölüm',
        readStatus: 'unread',
        progressFraction: 0,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
        discoveredAt: DateTime(2026, 7, 27),
        discoveryBasis: 'nextChain',
        discoveryConfidence: 'high',
      ),
    );

    screenTest('discovered chapters show as a count on the series row', (
      tester,
    ) async {
      final id = await seedSeries();
      await seedKnownRemote(id, 886);
      await seedKnownRemote(id, 887);
      await db.writeSeriesCheck(
        id,
        LibraryItemsCompanion(
          lastCheckAt: Value(DateTime(2026, 7, 27, 10)),
          lastCheckSuccessAt: Value(DateTime(2026, 7, 27, 10)),
          lastCheckResult: const Value('updatesAvailable'),
        ),
      );

      await tester.pumpWidget(harness(const LibraryScreen()));
      await pumpUntil(tester, find.text('2 new'));

      expect(find.text('2 new'), findsOneWidget);
      // Discovered chapters must not leak into the offline count: three are
      // on the device, two only on the source.
      expect(find.text('3'), findsOneWidget);
    });

    screenTest('never checked reads as "not checked yet", not zero', (
      tester,
    ) async {
      await seedSeries();
      await tester.pumpWidget(harness(const LibraryScreen()));
      await pumpUntil(tester, find.text('Not checked yet'));

      expect(find.text('Not checked yet'), findsOneWidget);
      expect(find.textContaining(' new'), findsNothing);
    });

    screenTest('a failed check is shown on the row, not hidden', (
      tester,
    ) async {
      final id = await seedSeries();
      await seedKnownRemote(id, 886);
      await db.writeSeriesCheck(
        id,
        LibraryItemsCompanion(
          lastCheckAt: Value(DateTime(2026, 7, 27, 10)),
          lastCheckError: const Value('source unreachable'),
          lastCheckResult: const Value('failed'),
        ),
      );

      await tester.pumpWidget(harness(const LibraryScreen()));
      await pumpUntil(tester, find.text('Check failed'));

      expect(find.text('Check failed'), findsOneWidget);
    });

    screenTest('the detail screen separates known-remote from saved', (
      tester,
    ) async {
      final id = await seedSeries();
      await seedKnownRemote(id, 886);

      await tester.pumpWidget(harness(SeriesDetailScreen(seriesId: id)));
      await pumpUntil(tester, find.textContaining('NEW ON SOURCE'));

      expect(find.textContaining('SAVED CHAPTERS · 3'), findsOneWidget);
      expect(find.text('886. Bölüm'), findsOneWidget);
      expect(find.textContaining('Capture 1 new chapter'), findsOneWidget);
      expect(find.text('Check now'), findsOneWidget);

      // The known-remote row is not a chapter row: there is nothing local to
      // read, so it never becomes tappable into the reader.
      expect(find.byKey(const ValueKey('remoteRow-r886')), findsOneWidget);
      expect(find.byKey(const ValueKey('chapterRow-r886')), findsNothing);
    });
  });
}

/// `testWidgets`, but the widget tree is torn down inside the test body.
///
/// Drift schedules a zero-duration timer when its query streams are disposed.
/// Left to the framework's own teardown that lands after the test has ended,
/// and every test fails with "pending timers" despite passing its assertions.
void screenTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    usePhoneSurface(tester);
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}

/// The default 800×600 test window is wider and much shorter than any phone:
/// list rows fall off the bottom and bottom sheets open outside the tree, so
/// finders miss widgets that are perfectly visible on a real device.
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Continue Reading and Recently Read, driven through the real library screen.
void _continueReadingTests() {
  late AppDatabase db;
  late ReadingRepository reading;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reading = ReadingRepository(db);
  });
  tearDown(() => db.close());

  Future<void> seed({int chapters = 3, String seriesId = 's1'}) async {
    await db.upsertLibraryItem(
      LibraryItem(
        lifecycle: 'active',
        id: seriesId,
        title: 'Series $seriesId',
        sourceUrl: 'https://x.example/manga/$seriesId',
        host: 'x.example',
        seriesKey: '/manga/$seriesId',
        createdAt: DateTime(2026, 7, 1),
      ),
    );
    for (var n = 1; n <= chapters; n++) {
      await db.upsertChapter(
        Chapter(
          id: '$seriesId-c$n',
          libraryItemId: seriesId,
          title: 'Series $seriesId Chapter $n',
          sourceUrl: 'https://x.example/manga/$seriesId/$n',
          urlKey: 'https://x.example/manga/$seriesId/$n',
          captureStatus: 'complete',
          contentPath: 'library/$seriesId/chapters/$seriesId-c$n',
          capturedAt: DateTime(2026, 7, 20),
          detectedImageCount: 6,
          storedImageCount: 6,
          sequence: n,
          byteSize: 1024,
          chapterNumber: n.toDouble(),
          chapterLabel: 'Chapter $n',
          readStatus: 'unread',
          progressFraction: 0,
          progressImageIndex: 0,
          progressOffsetInImage: 0,
        ),
      );
    }
  }

  // The library rows watch the update checker (for the live "Checking" chip)
  // and the strip watches the capture job (for the waiting-for-browser
  // banner), so the harness gives them inert instances over an unattached
  // browser.
  Widget harness() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      updateCheckerProvider.overrideWithValue(
        UpdateChecker(browser: BrowserController(), db: db),
      ),
      captureJobProvider.overrideWithValue(
        CaptureJobController(
          browser: BrowserController(),
          db: db,
          fileStore: FileStore(Directory.systemTemp.createTempSync('wr_cr')),
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const LibraryScreen()),
          GoRoute(
            path: '/reader/:id',
            builder: (context, state) =>
                Scaffold(body: Text('READER ${state.pathParameters['id']}')),
          ),
          GoRoute(path: '/series/:id', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/rules', builder: (_, _) => const SizedBox()),
        ],
      ),
    ),
  );

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('timed out waiting for $finder');
  }

  Future<void> settleDown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('a partly read chapter puts the series in Continue Reading', (
    tester,
  ) async {
    await seed();
    await reading.saveProgress('s1-c1', const ReadingPosition(fraction: 0.45));

    usePhoneSurface(tester);
    await tester.pumpWidget(harness());
    await pumpUntil(tester, find.text('CONTINUE READING'));

    expect(find.text('45%'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('tapping a Continue card opens that chapter', (tester) async {
    await seed();
    await reading.saveProgress('s1-c1', const ReadingPosition(fraction: 0.45));

    usePhoneSurface(tester);
    await tester.pumpWidget(harness());
    await pumpUntil(tester, find.text('45%'));
    await tester.tap(find.text('45%'));
    await pumpUntil(tester, find.textContaining('READER'));

    expect(find.text('READER s1-c1'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('completing a chapter advances Continue to the next unread', (
    tester,
  ) async {
    await seed();
    await reading.markRead('s1-c1');

    usePhoneSurface(tester);
    await tester.pumpWidget(harness());
    await pumpUntil(tester, find.text('CONTINUE READING'));

    expect(find.text('Chapter 2'), findsOneWidget);
    expect(find.text('not started'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('a fully read series says so rather than showing nothing', (
    tester,
  ) async {
    await seed(chapters: 2);
    await reading.markRead('s1-c1');
    await reading.markRead('s1-c2');

    usePhoneSurface(tester);
    await tester.pumpWidget(harness());
    await pumpUntil(tester, find.textContaining('up to date'));

    expect(find.textContaining('finished every chapter'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('marking a chapter unread makes it continuable again', (
    tester,
  ) async {
    await seed(chapters: 2);
    await reading.markRead('s1-c1');
    await reading.markRead('s1-c2');
    await reading.markUnread('s1-c1');

    usePhoneSurface(tester);
    await tester.pumpWidget(harness());
    await pumpUntil(tester, find.text('CONTINUE READING'));

    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.textContaining('finished every chapter'), findsNothing);
    await settleDown(tester);
  });

  testWidgets('Continue Reading orders by most recently read', (tester) async {
    await seed(seriesId: 's1', chapters: 1);
    await seed(seriesId: 's2', chapters: 1);
    await reading.saveProgress('s1-c1', const ReadingPosition(fraction: 0.3));
    await reading.saveProgress('s2-c1', const ReadingPosition(fraction: 0.6));

    // Explicit timestamps, not a real delay: `Future.delayed` inside a widget
    // test never completes until the fake clock is pumped, so waiting on wall
    // time here deadlocks before the first pump.
    await db.writeChapterReading(
      's1-c1',
      ChaptersCompanion(lastReadAt: Value(DateTime(2026, 7, 20))),
    );
    await db.writeChapterReading(
      's2-c1',
      ChaptersCompanion(lastReadAt: Value(DateTime(2026, 7, 25))),
    );
    await reading.repairSeriesReadingState();

    usePhoneSurface(tester);
    await tester.pumpWidget(harness());
    await pumpUntil(tester, find.text('CONTINUE READING'));

    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('continueCard-'),
    );
    expect(cards, findsNWidgets(2));
    // The most recently read series comes first.
    expect(
      find.descendant(
        of: cards.first,
        matching: find.textContaining('Series s2'),
      ),
      findsOneWidget,
    );
    await settleDown(tester);
  });

  testWidgets('one card per series, never duplicated within a section', (
    tester,
  ) async {
    await seed(chapters: 3);
    await reading.saveProgress('s1-c1', const ReadingPosition(fraction: 0.2));
    await reading.saveProgress('s1-c2', const ReadingPosition(fraction: 0.4));

    usePhoneSurface(tester);
    await tester.pumpWidget(harness());
    await pumpUntil(tester, find.text('CONTINUE READING'));

    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('continueCard-'),
      ),
      findsOneWidget,
    );
    await settleDown(tester);
  });

  testWidgets('reading progress updates the section without a restart', (
    tester,
  ) async {
    await seed();
    usePhoneSurface(tester);
    await tester.pumpWidget(harness());
    await pumpUntil(tester, find.text('CONTINUE READING'));
    expect(find.text('not started'), findsOneWidget);

    // Same app instance, no rebuild triggered by hand.
    await reading.saveProgress('s1-c1', const ReadingPosition(fraction: 0.5));
    await pumpUntil(tester, find.text('50%'));

    expect(find.text('50%'), findsOneWidget);
    await settleDown(tester);
  });

  testWidgets('captured but never opened says so rather than showing nothing', (
    tester,
  ) async {
    await seed();
    usePhoneSurface(tester);
    await tester.pumpWidget(harness());
    await pumpUntil(tester, find.text('CONTINUE READING'));

    // Never-opened series still offer their first chapter.
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Recently Read'), findsNothing);
    await settleDown(tester);
  });

  testWidgets('a series with no readable chapters gives a useful empty state', (
    tester,
  ) async {
    await db.upsertLibraryItem(
      LibraryItem(
        lifecycle: 'active',
        id: 's9',
        title: 'Broken Series',
        sourceUrl: 'https://x.example/manga/s9',
        host: 'x.example',
        seriesKey: '/manga/s9',
        createdAt: DateTime(2026, 7, 1),
      ),
    );
    await db.upsertChapter(
      Chapter(
        id: 's9-c1',
        libraryItemId: 's9',
        title: 'Broken Chapter',
        sourceUrl: 'https://x.example/manga/s9/1',
        urlKey: 'https://x.example/manga/s9/1',
        captureStatus: 'failed',
        capturedAt: DateTime(2026, 7, 20),
        detectedImageCount: 6,
        storedImageCount: 0,
        sequence: 1,
        byteSize: 0,
        readStatus: 'unread',
        progressFraction: 0,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
      ),
    );

    usePhoneSurface(tester);
    await tester.pumpWidget(harness());
    await pumpUntil(tester, find.text('CONTINUE READING'));

    expect(find.text('Nothing readable yet'), findsOneWidget);
    await settleDown(tester);
  });
}

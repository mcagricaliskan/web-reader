import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/capture/capture_job.dart';
import 'package:web_reader/core/connectivity.dart';
import 'package:web_reader/features/chapter_actions.dart';
import 'package:web_reader/features/series_detail_screen.dart';
import 'package:web_reader/library/update_checker.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/cleanup.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/file_store.dart';

/// Tapping a chapter: the reader when it can be read, and the two things
/// worth offering when it cannot.
class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this.online);

  bool online;
  final hosts = <String>[];

  @override
  Duration get timeout => const Duration(seconds: 1);

  @override
  Future<bool> canReach(String host) async {
    hosts.add(host);
    return online;
  }
}

void main() {
  late AppDatabase db;
  late Directory root;
  late FileStore store;
  late BrowserController browser;
  late _FakeConnectivity connectivity;
  String? lastRoute;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('webread_chapter_actions');
    store = FileStore(root);
    browser = BrowserController();
    connectivity = _FakeConnectivity(true);
    lastRoute = null;
  });
  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  const url = 'https://x.example/manga/foo/12';

  Future<void> seedSeries() => db.upsertLibraryItem(
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

  Future<void> seedChapter({
    String id = 'c1',
    String sourceUrl = url,
    bool offline = true,
    String captureStatus = 'complete',
    DateTime? removedAt,
  }) async {
    if (offline) {
      Directory(
        '${root.path}/library/series-1/chapters/$id',
      ).createSync(recursive: true);
    }
    await db.upsertChapter(
      Chapter(
        id: id,
        libraryItemId: 'series-1',
        title: 'Foo Chapter 12',
        sourceUrl: sourceUrl,
        urlKey: '$sourceUrl#$id',
        captureStatus: captureStatus,
        contentPath: offline ? 'library/series-1/chapters/$id' : null,
        capturedAt: DateTime(2026, 7, 20),
        detectedImageCount: 1,
        storedImageCount: offline ? 1 : 0,
        sequence: 12,
        byteSize: offline ? 64 : 0,
        chapterNumber: 12,
        chapterLabel: 'Chapter 12',
        readStatus: 'unread',
        progressFraction: 0,
        progressImageIndex: 0,
        progressOffsetInImage: 0,
        offlineRemovedAt: removedAt,
      ),
    );
  }

  Widget harness() {
    final router = GoRouter(
      initialLocation: '/series/series-1',
      routes: [
        GoRoute(
          path: '/series/:id',
          builder: (context, state) =>
              SeriesDetailScreen(seriesId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/reader/:chapterId',
          builder: (context, state) {
            lastRoute = state.uri.toString();
            return const Scaffold(body: Text('READER'));
          },
        ),
        GoRoute(path: '/rules', builder: (_, _) => const SizedBox()),
      ],
    );
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWithValue(store),
        browserProvider.overrideWithValue(browser),
        connectivityProvider.overrideWithValue(connectivity),
        // "Open on website" now goes through the shared coordinator, which
        // asks the capture job whether anything owns the rendered Browser
        // before it moves the user (D60).
        captureJobProvider.overrideWithValue(
          CaptureJobController(browser: browser, db: db, fileStore: store),
        ),
        updateCheckerProvider.overrideWithValue(
          UpdateChecker(browser: browser, db: db),
        ),
        cleanupProvider.overrideWithValue(
          CleanupService(db: db, fileStore: store),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Chapter 12').evaluate().isNotEmpty) return;
    }
    fail('series detail never listed the chapter');
  }

  Future<void> drain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('an offline chapter still opens the reader', (tester) async {
    await seedSeries();
    await seedChapter();
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('chapterRow-c1')));
    await tester.pumpAndSettle();

    expect(find.text('READER'), findsOneWidget);
    expect(lastRoute, '/reader/c1');
    await drain(tester);
  });

  testWidgets('a chapter with no files offers website and capture', (
    tester,
  ) async {
    await seedSeries();
    await seedChapter(offline: false, removedAt: DateTime(2026, 7, 26));
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('chapterRow-c1')));
    await tester.pumpAndSettle();

    expect(
      find.text('READER'),
      findsNothing,
      reason: 'there is nothing to read; the reader must not be opened',
    );
    expect(find.text('Open on website'), findsOneWidget);
    expect(find.text('Add to capture queue'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.textContaining('you removed its files'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('Open on website sends the Browser to the chapter URL', (
    tester,
  ) async {
    await seedSeries();
    await seedChapter(offline: false);
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('chapterRow-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open on website'));
    await tester.pumpAndSettle();

    expect(connectivity.hosts, ['x.example']);
    expect(
      browser.debugPendingUrl,
      url,
      reason: 'the stored chapter URL, never a series or fallback page',
    );
    await drain(tester);
  });

  testWidgets('an offline device says so instead of navigating', (
    tester,
  ) async {
    connectivity.online = false;
    await seedSeries();
    await seedChapter(offline: false);
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('chapterRow-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open on website'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No network connection'), findsOneWidget);
    expect(browser.debugPendingUrl, isNull);
    await drain(tester);
  });

  testWidgets('a chapter with no known URL cannot be opened on the web', (
    tester,
  ) async {
    await seedSeries();
    await seedChapter(offline: false, sourceUrl: '');
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('chapterRow-c1')));
    await tester.pumpAndSettle();

    expect(find.text('Open on website'), findsOneWidget);
    expect(
      find.text('The original page is unknown for this chapter'),
      findsOneWidget,
    );
    // Disabled, not merely unhelpful: tapping must not navigate anywhere.
    await tester.tap(find.text('Open on website'));
    await tester.pumpAndSettle();
    expect(browser.debugPendingUrl, isNull);
    expect(connectivity.hosts, isEmpty);
    await drain(tester);
  });

  testWidgets('an available chapter can still reach its source page', (
    tester,
  ) async {
    await seedSeries();
    await seedChapter();
    await open(tester);

    // Offered on long-press, so it never competes with reading.
    await tester.longPress(find.byKey(const ValueKey('chapterRow-c1')));
    await tester.pumpAndSettle();
    expect(find.text('Open episode'), findsOneWidget);

    await tester.tap(find.text('Open on website'));
    await tester.pumpAndSettle();
    expect(browser.debugPendingUrl, url);
    await drain(tester);
  });
}

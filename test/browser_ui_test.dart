import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/browser/browser_controller.dart';
import 'package:web_reader/browser/browser_presentation.dart';
import 'package:web_reader/browser/favicon_service.dart';
import 'package:web_reader/browser/history_repository.dart';
import 'package:web_reader/browser/saved_sites_repository.dart';
import 'package:web_reader/features/browser_home.dart';
import 'package:web_reader/features/browser_toolbar.dart';
import 'package:web_reader/features/browser_ui.dart';
import 'package:web_reader/features/browser_url_editor.dart';
import 'package:web_reader/providers.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/ui/theme.dart';

/// The Browser's own chrome: toolbar shape and state, Browser Home, and the
/// URL editor's suggestions.
///
/// These build the surfaces directly rather than the whole `BrowserScreen` —
/// that one embeds a real platform WebView, which a widget test cannot host.
/// Preservation of the WebView is asserted in `browser_navigation_test.dart`
/// against the presentation state, which is what actually decides it.
/// Every widget test here ends by unmounting and pumping once more.
///
/// Watching a drift query in a widget test schedules a zero-duration timer
/// when the stream is closed at dispose; without a final pump it is still
/// pending when the binding checks its invariants. The repo's other
/// provider-backed widget tests drain the same way.
void browserWidgetTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget host(Widget child, {Size size = const Size(390, 844)}) =>
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // Network-free, like everything under `test/`. A favicon miss
          // renders the fallback, which is the state these tests care about.
          faviconServiceProvider.overrideWithValue(
            FaviconService(db: db, allowNetwork: false),
          ),
        ],
        child: MaterialApp(
          theme: appTheme(),
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Scaffold(body: child),
          ),
        ),
      );

  group('toolbar', () {
    late BrowserController browser;
    late List<String> taps;

    setUp(() {
      browser = BrowserController();
      taps = [];
    });

    tearDown(() => browser.dispose());

    Widget toolbar({bool homeActive = false}) => host(
      BrowserToolbar(
        browser: browser,
        homeActive: homeActive,
        onBack: () => taps.add('back'),
        onForward: () => taps.add('forward'),
        onAddress: () => taps.add('address'),
        onReloadOrStop: () => taps.add('reloadOrStop'),
        onHome: () => taps.add('home'),
      ),
    );

    browserWidgetTest('has Home and no permanent Go button', (tester) async {
      await tester.pumpWidget(toolbar());

      expect(find.byKey(const ValueKey('browserHomeButton')), findsOneWidget);
      // The old Go/Enter affordance is gone: Go belongs to the editor (§2).
      expect(find.byIcon(Icons.subdirectory_arrow_left), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Go'), findsNothing);
    });

    browserWidgetTest('shows all five actions', (tester) async {
      await tester.pumpWidget(toolbar());
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      expect(find.byKey(const ValueKey('browserAddressField')), findsOneWidget);
      expect(find.byKey(const ValueKey('browserReloadStop')), findsOneWidget);
      expect(find.byKey(const ValueKey('browserHomeButton')), findsOneWidget);
    });

    browserWidgetTest(
      'Forward is disabled until there is somewhere to go forward',
      (tester) async {
        await tester.pumpWidget(toolbar());
        await tester.tap(find.byIcon(Icons.arrow_forward_ios));
        await tester.pump();
        expect(taps, isEmpty, reason: 'disabled, so the tap does nothing');
      },
    );

    browserWidgetTest(
      'Back is always live — with no page history it means leave',
      (tester) async {
        await tester.pumpWidget(toolbar());
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pump();
        expect(taps, ['back']);
      },
    );

    browserWidgetTest('Refresh becomes Stop during a load, and back again', (
      tester,
    ) async {
      await tester.pumpWidget(toolbar());
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      browser.onLoadStart('https://a.example/x');
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);

      await browser.onLoadStop('https://a.example/x');
      await tester.pump();
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    browserWidgetTest('the address field shows host plus a shortened path', (
      tester,
    ) async {
      browser.onUrlChanged(
        'https://uzaymanga.com/manga/efsanevi-buyu-imparatoru/885-bolum-oku',
      );
      await tester.pumpWidget(toolbar());

      final rich = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('browserAddressField')),
          matching: find.byType(Text),
        ),
      );
      final shown = rich.textSpan!.toPlainText();
      expect(shown, startsWith('uzaymanga.com'));
      expect(shown, contains('885-bolum-oku'));
      // Never the raw, unreadable full URL.
      expect(shown, isNot(contains('https://')));
      expect(shown.length, lessThan(45));
    });

    browserWidgetTest(
      'tapping the address field opens the editor, not an inline one',
      (tester) async {
        browser.onUrlChanged('https://a.example/x');
        await tester.pumpWidget(toolbar());
        await tester.tap(find.byKey(const ValueKey('browserAddressField')));
        await tester.pump();
        expect(taps, ['address']);
        // The compact field is not an editor.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('browserAddressField')),
            matching: find.byType(TextField),
          ),
          findsNothing,
        );
      },
    );

    browserWidgetTest('fits at 320pt with no overflow', (tester) async {
      browser.onUrlChanged('https://uzaymanga.com/manga/x/885-bolum-oku');
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(toolbar(homeActive: false));
      expect(tester.takeException(), isNull);

      // Every action keeps a usable target and one shared baseline.
      final boxes = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: find.byType(BrowserToolbar),
              matching: find.byType(SizedBox),
            ),
          )
          .where((b) => b.height == BrowserToolbar.kBrowserActionHeight);
      expect(boxes.length, greaterThanOrEqualTo(4));
      for (final box in boxes) {
        expect(box.width, BrowserToolbar.kBrowserActionWidth);
      }
    });

    browserWidgetTest('survives large text without overflowing', (
      tester,
    ) async {
      browser.onUrlChanged('https://uzaymanga.com/manga/x/885-bolum-oku');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: appTheme(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.6),
              ),
              child: Scaffold(
                body: BrowserToolbar(
                  browser: browser,
                  homeActive: false,
                  onBack: () {},
                  onForward: () {},
                  onAddress: () {},
                  onReloadOrStop: () {},
                  onHome: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Browser Home', () {
    late List<String> opened;

    setUp(() => opened = []);

    Widget home({PreservedPage? preserved}) => host(
      BrowserHome(
        preserved: preserved,
        onClose: () => opened.add('close'),
        onOpenAddressEditor: () => opened.add('editor'),
        onOpenUrl: (url, _) => opened.add('open:$url'),
        onOpenHistory: () => opened.add('history'),
        onAddSite: () => opened.add('add'),
        onEditSite: (_) => opened.add('edit'),
      ),
    );

    browserWidgetTest(
      'renders saved sites and recently visited from real data',
      (tester) async {
        await SavedSitesRepository(db).seedDefaultIfNeeded();
        await HistoryRepository(db).recordVisit(
          url: 'https://uzaymanga.com/manga/x/885',
          title: 'Bölüm 885',
          source: NavigationSource.manual,
        );

        await tester.pumpWidget(home());
        await tester.pump();

        expect(find.text('Saved sites'.toUpperCase()), findsOneWidget);
        expect(find.text('Google'), findsOneWidget);
        expect(find.text('Recently visited'.toUpperCase()), findsOneWidget);
        expect(find.text('Bölüm 885'), findsOneWidget);
      },
    );

    browserWidgetTest('the search field opens the URL editor', (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('browserHomeSearch')));
      await tester.pump();
      expect(opened, ['editor']);
    });

    browserWidgetTest('the preserved-page row returns to it, and says so', (
      tester,
    ) async {
      await tester.pumpWidget(
        home(
          preserved: const PreservedPage(
            url: 'https://uzaymanga.com/manga/x/885',
            title: 'Bölüm 885',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('still open · scroll position kept'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('browserHomeBackToPage')));
      await tester.pump();
      expect(opened, ['close']);
    });

    browserWidgetTest(
      'with no preserved page there is no way-back affordance',
      (tester) async {
        await tester.pumpWidget(home());
        await tester.pump();
        expect(
          find.byKey(const ValueKey('browserHomeBackToPage')),
          findsNothing,
        );
        expect(find.text('still open · scroll position kept'), findsNothing);
      },
    );

    browserWidgetTest('empty state: no saved sites', (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();
      expect(find.text('No saved sites yet'), findsOneWidget);
      await tester.tap(find.text('Add a site'));
      await tester.pump();
      expect(opened, ['add']);
    });

    browserWidgetTest('empty state: no manual history', (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();
      expect(
        find.textContaining('Pages you open in the Browser show up here'),
        findsOneWidget,
      );
    });

    browserWidgetTest('only the default saved site still renders a grid', (
      tester,
    ) async {
      await SavedSitesRepository(db).seedDefaultIfNeeded();
      await tester.pumpWidget(home());
      await tester.pump();
      expect(find.text('No saved sites yet'), findsNothing);
      expect(find.byKey(const ValueKey('addSavedSiteTile')), findsOneWidget);
    });

    browserWidgetTest('recently visited is bounded to four rows', (
      tester,
    ) async {
      final history = HistoryRepository(db);
      for (var i = 0; i < 12; i++) {
        await history.recordVisit(
          url: 'https://a.example/$i',
          title: 'Page $i',
          source: NavigationSource.manual,
        );
      }
      await tester.pumpWidget(home());
      await tester.pump();

      var shown = 0;
      for (var i = 0; i < 12; i++) {
        if (find.text('Page $i').evaluate().isNotEmpty) shown++;
      }
      expect(shown, 4);
    });

    browserWidgetTest('Full history is offered', (tester) async {
      await tester.pumpWidget(home());
      await tester.pump();
      await tester.tap(find.text('Full history'));
      await tester.pump();
      expect(opened, ['history']);
    });

    browserWidgetTest('fits at 320pt', (tester) async {
      await SavedSitesRepository(db).seedDefaultIfNeeded();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(home());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('URL editor', () {
    browserWidgetTest('opens with the full URL, selected', (tester) async {
      await tester.pumpWidget(
        host(
          BrowserUrlEditor(
            initialText: 'https://uzaymanga.com/manga/x/885?lang=tr',
            selectAll: true,
            currentPageUrl: 'https://uzaymanga.com/manga/x/885?lang=tr',
            onSubmit: (_) {},
            onCancel: () {},
            onSaveSite: (_, _) {},
          ),
        ),
      );
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('urlEditorField')),
      );
      expect(
        field.controller!.text,
        'https://uzaymanga.com/manga/x/885?lang=tr',
      );
      expect(field.controller!.selection.baseOffset, 0);
      expect(
        field.controller!.selection.extentOffset,
        field.controller!.text.length,
      );
    });

    browserWidgetTest('opens blank from Browser Home', (tester) async {
      await tester.pumpWidget(
        host(
          BrowserUrlEditor(
            initialText: '',
            selectAll: false,
            onSubmit: (_) {},
            onCancel: () {},
            onSaveSite: (_, _) {},
          ),
        ),
      );
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('urlEditorField')),
      );
      expect(field.controller!.text, isEmpty);
    });

    browserWidgetTest(
      'Go submits the raw text; the keyboard action does the same',
      (tester) async {
        final submitted = <String>[];
        await tester.pumpWidget(
          host(
            BrowserUrlEditor(
              initialText: '',
              selectAll: false,
              onSubmit: submitted.add,
              onCancel: () {},
              onSaveSite: (_, _) {},
            ),
          ),
        );
        await tester.pump();

        await tester.enterText(
          find.byKey(const ValueKey('urlEditorField')),
          'uzaymanga.com/manga/x',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('urlEditorGo')));
        await tester.pump();
        expect(submitted, ['uzaymanga.com/manga/x']);

        await tester.testTextInput.receiveAction(TextInputAction.go);
        await tester.pump();
        expect(submitted, hasLength(2));
      },
    );

    browserWidgetTest('Go reads "Search Google" for non-URL text', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          BrowserUrlEditor(
            initialText: '',
            selectAll: false,
            onSubmit: (_) {},
            onCancel: () {},
            onSaveSite: (_, _) {},
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('urlEditorField')),
        'baekmyeong chapter',
      );
      await tester.pump();
      expect(find.text('Search Google'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('urlEditorField')),
        'uzaymanga.com',
      );
      await tester.pump();
      expect(find.text('Go'), findsOneWidget);
    });

    browserWidgetTest('Clear empties the field', (tester) async {
      await tester.pumpWidget(
        host(
          BrowserUrlEditor(
            initialText: 'https://a.example/x',
            selectAll: false,
            onSubmit: (_) {},
            onCancel: () {},
            onSaveSite: (_, _) {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Clear'));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('urlEditorField')),
      );
      expect(field.controller!.text, isEmpty);
    });

    browserWidgetTest(
      'suggestions are debounced, not recomputed per keystroke',
      (tester) async {
        await HistoryRepository(db).recordVisit(
          url: 'https://uzaymanga.com/manga/x',
          title: 'Uzay chapter',
          source: NavigationSource.manual,
        );
        await tester.pumpWidget(
          host(
            BrowserUrlEditor(
              initialText: '',
              selectAll: false,
              onSubmit: (_) {},
              onCancel: () {},
              onSaveSite: (_, _) {},
            ),
          ),
        );
        await tester.pump();

        // An empty query matches everything, so the row is there to begin with.
        expect(find.text('Uzay chapter'), findsOneWidget);

        // Type something that matches nothing, in two quick keystrokes.
        await tester.enterText(
          find.byKey(const ValueKey('urlEditorField')),
          'z',
        );
        await tester.pump(const Duration(milliseconds: 40));
        await tester.enterText(
          find.byKey(const ValueKey('urlEditorField')),
          'zzzz',
        );
        await tester.pump(const Duration(milliseconds: 40));
        // Still inside the debounce window: the list is deliberately stale.
        // This is the assertion that the query is not recomputed per keystroke.
        expect(find.text('Uzay chapter'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Uzay chapter'), findsNothing);
        // Searching for it is still offered — that is always a real option.
        expect(find.textContaining('Search Google for'), findsOneWidget);
        expect(find.text('HISTORY'), findsNothing);
      },
    );
  });

  group('suggestion ranking', () {
    List<SavedSite> savedFixture() => [
      SavedSite(
        id: 's1',
        url: 'https://uzaymanga.com/',
        urlKey: 'https://uzaymanga.com/',
        host: 'uzaymanga.com',
        title: 'Uzay Manga',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        orderIndex: 0,
        isDefault: false,
      ),
    ];

    List<BrowsingHistoryData> visitFixture() => [
      BrowsingHistoryData(
        id: 'v1',
        url: 'https://asurascans.com/comics/x/137',
        urlKey: 'https://asurascans.com/comics/x/137',
        host: 'asurascans.com',
        title: 'Nebula 137',
        source: 'manual',
        completed: true,
        visitedAt: DateTime(2026, 7, 28),
      ),
    ];

    test('scores exact above prefix above contains', () {
      expect(matchScore('uzaymanga.com', 'uzaymanga.com'), 100);
      expect(matchScore('uzaymanga.com', 'uzay'), 60);
      expect(matchScore('uzaymanga.com', 'manga'), 20);
      expect(matchScore('uzaymanga.com', 'zzz'), 0);
    });

    test('saved sites rank above history', () {
      final groups = buildSuggestions(
        query: 'a',
        saved: savedFixture(),
        visits: visitFixture(),
      );
      final labels = groups.map((g) => g.$1).toList();
      expect(
        labels.indexOf('Saved sites'),
        lessThan(labels.indexOf('History')),
      );
    });

    test('typed text is always offered first', () {
      final groups = buildSuggestions(
        query: 'nebula',
        saved: savedFixture(),
        visits: visitFixture(),
      );
      expect(groups.first.$1, 'Search');
      expect(groups.first.$2.single.url, contains('google.com/search'));
    });

    test('a typed hostname is offered as somewhere to open, not to search', () {
      final groups = buildSuggestions(
        query: 'uzaymanga.com/manga',
        saved: savedFixture(),
        visits: visitFixture(),
      );
      expect(groups.first.$1, 'Open');
      expect(groups.first.$2.single.url, 'https://uzaymanga.com/manga');
    });

    test('a page already saved is not repeated under History', () {
      final saved = savedFixture();
      final visits = [
        BrowsingHistoryData(
          id: 'v2',
          url: 'https://uzaymanga.com/',
          urlKey: 'https://uzaymanga.com/',
          host: 'uzaymanga.com',
          title: 'Uzay Manga',
          source: 'manual',
          completed: true,
          visitedAt: DateTime(2026, 7, 28),
        ),
      ];
      final groups = buildSuggestions(
        query: 'uzay',
        saved: saved,
        visits: visits,
      );
      expect(groups.map((g) => g.$1), isNot(contains('History')));
    });
  });

  group('favicons', () {
    browserWidgetTest('the fallback is the hostname initial, at a fixed size', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const Center(child: FaviconTile(host: 'uzaymanga.com', size: 30))),
      );
      await tester.pump();

      expect(find.text('U'), findsOneWidget);
      final box = tester.getSize(find.byType(FaviconTile));
      expect(box, const Size(30, 30));
    });

    browserWidgetTest('the box does not change size when there is no icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const Center(child: FaviconTile(host: 'nothing.example'))),
      );
      final before = tester.getSize(find.byType(FaviconTile));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.getSize(find.byType(FaviconTile)), before);
    });

    browserWidgetTest('a site keeps the same tile colour everywhere', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: [
              FaviconTile(host: 'uzaymanga.com'),
              FaviconTile(host: 'uzaymanga.com'),
            ],
          ),
        ),
      );
      await tester.pump();
      final boxes = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(FaviconTile),
              matching: find.byType(DecoratedBox),
            ),
          )
          .toList();
      expect(
        (boxes[0].decoration as BoxDecoration).color,
        (boxes[1].decoration as BoxDecoration).color,
      );
    });
  });

  group('visit time formatting', () {
    final now = DateTime(2026, 7, 28, 15, 30);

    test('reads the way the design writes it', () {
      expect(
        formatVisitTime(now.subtract(const Duration(seconds: 20)), now: now),
        'just now',
      );
      expect(
        formatVisitTime(now.subtract(const Duration(minutes: 4)), now: now),
        '4 min ago',
      );
      expect(
        formatVisitTime(now.subtract(const Duration(hours: 3)), now: now),
        '3 h ago',
      );
      expect(
        formatVisitTime(DateTime(2026, 7, 27, 21, 40), now: now),
        'yesterday 21:40',
      );
      expect(formatVisitTime(DateTime(2026, 7, 12), now: now), '12 Jul');
      expect(formatVisitTime(DateTime(2025, 7, 12), now: now), '12 Jul 2025');
    });
  });
}

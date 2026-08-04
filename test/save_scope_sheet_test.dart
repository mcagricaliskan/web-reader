import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/save/capture_mode.dart';
import 'package:web_reader/library/content_shape.dart';
import 'package:web_reader/core/device_storage.dart';
import 'package:web_reader/features/save_scope_sheet.dart';
import 'package:web_reader/save/size_estimate.dart';
import 'package:web_reader/storage/database.dart';
import 'package:web_reader/storage/manifest.dart';

/// The three-choice range sheet: exactly three options, typed counts with
/// validation, the disk refusal in front of everything — and the two launches
/// the range can be given to, in the sheet itself (D58).
void main() {
  Widget host({
    required void Function(SaveRangeChoice?) onResult,
    int? free = 8 * 1024 * 1024 * 1024,
    String? busyLabel,
    CaptureCapabilities capabilities = const CaptureCapabilities.unanalysed(),
    CaptureMode? preferredMode,
    bool canRemember = false,
    CollectionSizeHistory sizeHistory = const CollectionSizeHistory.empty(),
    TextScaler textScale = TextScaler.noScaling,
  }) => MaterialApp(
    // Above the Navigator, so the sheet's own route inherits it too.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScale),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () async {
            final r = await showSaveRangeSheet(
              context: context,
              config: const SaveConfig(),
              deviceStorage: _FixedStorage(free),
              currentTitle: 'Foo Entry 137',
              busyLabel: busyLabel,
              capabilities: capabilities,
              preferredMode: preferredMode,
              canRemember: canRemember,
              sizeHistory: sizeHistory,
            );
            onResult(r);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The narrowest phone the design supports: both actions must fit here.
  void narrow(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// A phone-sized surface. With the keypad open the sheet is taller than the
  /// test default, and the launches live below it.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// The number as the sheet is showing it; '—' when nothing is entered.
  String shownCount(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('saveCountValueText')))
      .data!;

  Future<void> tapKey(WidgetTester tester, String id) async {
    final key = find.byKey(ValueKey(id));
    await tester.ensureVisible(key);
    await tester.pumpAndSettle();
    await tester.tap(key);
    await tester.pumpAndSettle();
  }

  /// Enters a number the only way the sheet allows: on its own keys. There is
  /// no text input to type into, so an existing value is deleted digit by
  /// digit exactly as a person would have to.
  Future<void> typeCount(WidgetTester tester, String digits) async {
    for (var i = 0; i < 12 && shownCount(tester) != '—'; i++) {
      await tapKey(tester, 'keypadDelete');
    }
    for (final d in digits.split('')) {
      await tapKey(tester, 'keypadKey_$d');
    }
  }

  /// Chooses the typed-count range on an already-open sheet.
  Future<void> chooseCount(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Number of entries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Number of entries'));
    await tester.pumpAndSettle();
  }

  testWidgets('exactly the two choices, no count presets', (tester) async {
    await tester.pumpWidget(host(onResult: (_) {}));
    await open(tester);

    expect(find.text('Current entry'), findsOneWidget);
    expect(find.text('Number of entries'), findsOneWidget);
    // No open-ended range. It was bounded by a ceiling the user never saw,
    // and — with no field to type one into — it passed a count of 1 and saved
    // exactly one entry.
    expect(find.text('Until the end'), findsNothing);
    expect(find.textContaining('safety limit'), findsNothing);
    expect(find.textContaining('3 entries'), findsNothing);
    expect(find.textContaining('5 entries'), findsNothing);
    expect(find.textContaining('Next 3'), findsNothing);
    expect(find.textContaining('Next 5'), findsNothing);
  });

  group('the two launches', () {
    testWidgets('both are offered, in the sheet, with no second drawer', (
      tester,
    ) async {
      narrow(tester);
      await tester.pumpWidget(host(onResult: (_) {}));
      await open(tester);

      expect(find.byKey(const ValueKey('saveAddToQueue')), findsOneWidget);
      expect(find.byKey(const ValueKey('saveStartNow')), findsOneWidget);
      expect(find.byKey(const ValueKey('saveLaunchExplainer')), findsOneWidget);
      // Both fit, side by side, at 320pt.
      final queue = tester.getRect(
        find.byKey(const ValueKey('saveAddToQueue')),
      );
      final start = tester.getRect(find.byKey(const ValueKey('saveStartNow')));
      expect(queue.right, lessThanOrEqualTo(start.left));
      expect(start.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });

    testWidgets('picking a range does not close the sheet or ask again', (
      tester,
    ) async {
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await open(tester);

      await tester.ensureVisible(find.text('Number of entries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Number of entries'));
      await tester.pumpAndSettle();

      expect(result, isNull, reason: 'choosing a range decides nothing yet');
      expect(find.text('Number of entries'), findsOneWidget);
      expect(find.byKey(const ValueKey('saveStartNow')), findsOneWidget);
      // No queue/start question anywhere but here.
      expect(find.text('Start queued saves?'), findsNothing);
    });

    testWidgets('Add to Queue returns the range with the queue intent', (
      tester,
    ) async {
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await open(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('saveAddToQueue')));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('saveAddToQueue')));
      await tester.pumpAndSettle();

      expect(result?.mode, SaveScope.currentPageOnly);
      expect(result?.action, SaveSheetAction.addToQueue);
    });

    testWidgets('Start Save returns the range with the direct intent', (
      tester,
    ) async {
      phone(tester);
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await open(tester);

      await chooseCount(tester);
      await typeCount(tester, '150');
      await tester.ensureVisible(find.byKey(const ValueKey('saveStartNow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveStartNow')));
      await tester.pumpAndSettle();

      expect(result?.mode, SaveScope.fixedCount);
      expect(result?.count, 150, reason: 'the number the user typed');
      expect(result?.action, SaveSheetAction.startNow);
    });

    testWidgets('the count field names the ceiling it will accept', (
      tester,
    ) async {
      await tester.pumpWidget(host(onResult: (_) {}));
      await open(tester);
      expect(
        find.textContaining('up to ${const SaveConfig().maxEntriesPerRun}'),
        findsOneWidget,
      );
    });
  });

  group('when the Browser is already busy', () {
    testWidgets('direct start is replaced, queueing is not', (tester) async {
      narrow(tester);
      SaveRangeChoice? result;
      await tester.pumpWidget(
        host(
          onResult: (r) => result = r,
          busyLabel: 'A save is using the Browser',
        ),
      );
      await open(tester);

      expect(find.byKey(const ValueKey('saveStartNow')), findsNothing);
      expect(find.byKey(const ValueKey('saveViewActiveTask')), findsOneWidget);
      expect(find.byKey(const ValueKey('saveBusyNote')), findsOneWidget);
      expect(
        find.textContaining('A save is using the Browser'),
        findsOneWidget,
      );

      // Queueing is still a real option — it starts nothing.
      await tester.ensureVisible(find.byKey(const ValueKey('saveAddToQueue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveAddToQueue')));
      await tester.pumpAndSettle();
      expect(result?.action, SaveSheetAction.addToQueue);
    });

    testWidgets('View active task is its own outcome', (tester) async {
      SaveRangeChoice? result;
      await tester.pumpWidget(
        host(onResult: (r) => result = r, busyLabel: 'An update check'),
      );
      await open(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('saveViewActiveTask')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveViewActiveTask')));
      await tester.pumpAndSettle();

      expect(result?.action, SaveSheetAction.viewActiveTask);
    });
  });

  testWidgets('typed count is validated for both actions', (tester) async {
    phone(tester);

    SaveRangeChoice? result;
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await open(tester);
    await chooseCount(tester);

    // Zero refuses — and the sheet stays open, error visible.
    await typeCount(tester, '0');
    await tester.ensureVisible(find.byKey(const ValueKey('saveStartNow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveStartNow')));
    await tester.pump();
    expect(find.textContaining('1 or more'), findsOneWidget);
    expect(result, isNull);
    expect(find.byKey(const ValueKey('saveAddToQueue')), findsOneWidget);

    // The same validation guards the queue action.
    await tester.ensureVisible(find.byKey(const ValueKey('saveAddToQueue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveAddToQueue')));
    await tester.pump();
    expect(result, isNull);

    // Excessive refuses, naming the bound.
    await typeCount(tester, '9999');
    await tester.ensureVisible(find.byKey(const ValueKey('saveStartNow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveStartNow')));
    await tester.pump();
    expect(
      find.textContaining('${const SaveConfig().maxEntriesPerRun}'),
      findsWidgets,
    );
    expect(result, isNull);

    // A valid number shows the summary and returns with the chosen launch.
    await typeCount(tester, '8');
    expect(find.textContaining('Save 8 items'), findsOneWidget);
    expect(find.textContaining('Foo Entry 137'), findsWidgets);
    await tester.ensureVisible(find.byKey(const ValueKey('saveStartNow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveStartNow')));
    await tester.pumpAndSettle();
    expect(result?.mode, SaveScope.fixedCount);
    expect(result?.count, 8);
    expect(result?.action, SaveSheetAction.startNow);
  });

  /// The sheet draws its own number keys.
  ///
  /// A platform keyboard cannot be asked for "digits and an OK": iOS renders a
  /// number pad with no return key at all, Android renders whichever IME the
  /// user installed, and neither is something this sheet can promise. So it
  /// promises nothing and draws the keys itself — the same ten digits, the
  /// same delete, the same OK, on both platforms.
  group('the count keypad', () {
    Future<void> openCount(WidgetTester tester) async {
      await open(tester);
      await chooseCount(tester);
    }

    testWidgets('choosing the range reveals the keypad, not a keyboard', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(host(onResult: (_) {}));
      await open(tester);

      // Not before: with no number being typed there are no keys.
      expect(find.byKey(const ValueKey('saveCountKeypad')), findsNothing);

      await chooseCount(tester);
      expect(find.byKey(const ValueKey('saveCountKeypad')), findsOneWidget);
      expect(find.byKey(const ValueKey('saveCountValue')), findsOneWidget);

      // Nothing here can summon the platform's keyboard, because nothing here
      // is a text input.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);

      // The suffix action the native keyboard needed is gone with it.
      expect(find.byKey(const ValueKey('saveCountDone')), findsNothing);
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('the keys are plain digits and nothing else', (tester) async {
      phone(tester);
      await tester.pumpWidget(host(onResult: (_) {}));
      await openCount(tester);

      for (final d in [for (var i = 0; i <= 9; i++) '$i']) {
        final key = find.byKey(ValueKey('keypadKey_$d'));
        expect(key, findsOneWidget, reason: d);
        // Exactly one label on the key, and it is the digit — no phone-pad
        // letters riding underneath it.
        final labels = tester
            .widgetList<Text>(
              find.descendant(of: key, matching: find.byType(Text)),
            )
            .map((t) => t.data)
            .toList();
        expect(labels, [d], reason: 'key $d shows only its digit');
      }
      for (final letters in ['ABC', 'DEF', 'GHI', 'JKL', 'MNO', 'PQRS']) {
        expect(find.textContaining(letters), findsNothing, reason: letters);
      }
      // No decimal, sign, or anything else that is not a number this sheet
      // can act on.
      for (final symbol in ['.', ',', '-', '+', '*', '#']) {
        expect(find.text(symbol), findsNothing, reason: symbol);
      }
    });

    testWidgets('digits build the value, leading zeroes normalise away', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(host(onResult: (_) {}));
      await openCount(tester);

      await typeCount(tester, '1');
      expect(shownCount(tester), '1');
      await tapKey(tester, 'keypadKey_2');
      await tapKey(tester, 'keypadKey_0');
      expect(shownCount(tester), '120');

      // 004 is 4: the display never shows a number that reads as something
      // other than what it means.
      await typeCount(tester, '004');
      expect(shownCount(tester), '4');
      await typeCount(tester, '0');
      expect(shownCount(tester), '0', reason: 'zero is a value, and invalid');
    });

    testWidgets('delete removes one digit, and is safe on an empty value', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(host(onResult: (_) {}));
      await openCount(tester);

      await typeCount(tester, '123');
      await tapKey(tester, 'keypadDelete');
      expect(shownCount(tester), '12');
      await tapKey(tester, 'keypadDelete');
      expect(shownCount(tester), '1');
      await tapKey(tester, 'keypadDelete');
      expect(shownCount(tester), '—', reason: 'nothing entered');

      // Delete on nothing does nothing at all.
      await tapKey(tester, 'keypadDelete');
      await tapKey(tester, 'keypadDelete');
      expect(shownCount(tester), '—');
      expect(tester.takeException(), isNull);
    });

    testWidgets('OK keeps the value, hides the keypad, and starts nothing', (
      tester,
    ) async {
      phone(tester);
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await openCount(tester);

      await typeCount(tester, '12');
      await tapKey(tester, 'keypadOk');

      expect(shownCount(tester), '12', reason: 'the value is kept');
      expect(find.byKey(const ValueKey('saveCountKeypad')), findsNothing);
      // Confirming a number is not authorising a save.
      expect(result, isNull);
      expect(find.byKey(const ValueKey('saveStartNow')), findsOneWidget);
      expect(find.byKey(const ValueKey('saveAddToQueue')), findsOneWidget);
    });

    testWidgets('Start Save after OK carries the confirmed count', (
      tester,
    ) async {
      phone(tester);
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await openCount(tester);

      await typeCount(tester, '12');
      await tapKey(tester, 'keypadOk');
      await tester.ensureVisible(find.byKey(const ValueKey('saveStartNow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveStartNow')));
      await tester.pumpAndSettle();

      expect(result?.mode, SaveScope.fixedCount);
      expect(result?.count, 12);
      expect(result?.action, SaveSheetAction.startNow);
    });

    testWidgets('Add to Queue after OK carries the confirmed count', (
      tester,
    ) async {
      phone(tester);
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await openCount(tester);

      await typeCount(tester, '9');
      await tapKey(tester, 'keypadOk');
      await tester.ensureVisible(find.byKey(const ValueKey('saveAddToQueue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveAddToQueue')));
      await tester.pumpAndSettle();

      expect(result?.mode, SaveScope.fixedCount);
      expect(result?.count, 9);
      expect(result?.action, SaveSheetAction.addToQueue);
    });

    testWidgets('OK answers a bad number where it was typed', (tester) async {
      phone(tester);
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await openCount(tester);

      // Nothing entered at all.
      await typeCount(tester, '');
      await tapKey(tester, 'keypadOk');
      expect(find.textContaining('1 or more'), findsOneWidget);
      expect(result, isNull);
      expect(
        find.byKey(const ValueKey('saveCountKeypad')),
        findsOneWidget,
        reason: 'the keys to fix it stay under the thumb',
      );

      // Zero, then over the ceiling — the same two rules the launches apply.
      await typeCount(tester, '0');
      await tapKey(tester, 'keypadOk');
      expect(find.textContaining('1 or more'), findsOneWidget);

      await typeCount(tester, '9999');
      await tapKey(tester, 'keypadOk');
      expect(
        find.textContaining('At most ${const SaveConfig().maxEntriesPerRun}'),
        findsOneWidget,
      );
      expect(result, isNull);

      // A number that is fine clears the stale complaint and closes the keys.
      await typeCount(tester, '4');
      expect(find.textContaining('At most'), findsNothing);
      await tapKey(tester, 'keypadOk');
      expect(find.byKey(const ValueKey('saveCountError')), findsNothing);
      expect(find.byKey(const ValueKey('saveCountKeypad')), findsNothing);
      expect(shownCount(tester), '4');
    });

    testWidgets('switching range hides the keypad and still switches', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(host(onResult: (_) {}));
      await openCount(tester);

      // Leave a complaint on screen, then walk away from the range it is about.
      await typeCount(tester, '0');
      await tapKey(tester, 'keypadOk');
      expect(find.byKey(const ValueKey('saveCountError')), findsOneWidget);

      await tester.tap(find.text('Current entry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('saveCountKeypad')), findsNothing);
      expect(find.byKey(const ValueKey('saveCountValue')), findsNothing);
      expect(
        find.byKey(const ValueKey('saveCountError')),
        findsNothing,
        reason: 'not about the range being used any more',
      );
      expect(find.text('Current entry'), findsOneWidget);
    });

    testWidgets('switching back keeps the number that was entered', (
      tester,
    ) async {
      phone(tester);
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await openCount(tester);

      await typeCount(tester, '37');
      await tapKey(tester, 'keypadOk');

      await tester.tap(find.text('Current entry'));
      await tester.pumpAndSettle();
      await chooseCount(tester);
      expect(shownCount(tester), '37', reason: 'the sheet does not forget');

      await tester.ensureVisible(find.byKey(const ValueKey('saveStartNow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveStartNow')));
      await tester.pumpAndSettle();
      expect(result?.count, 37);
    });

    testWidgets('the current entry range still saves exactly one', (
      tester,
    ) async {
      phone(tester);
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await openCount(tester);
      await typeCount(tester, '37');
      await tapKey(tester, 'keypadOk');

      await tester.tap(find.text('Current entry'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('saveStartNow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveStartNow')));
      await tester.pumpAndSettle();

      expect(result?.mode, SaveScope.currentPageOnly);
      expect(result?.count, 1, reason: 'the typed number is not in play');
    });

    testWidgets('the grid fits the narrowest phone', (tester) async {
      narrow(tester);
      await tester.pumpWidget(host(onResult: (_) {}));
      await openCount(tester);

      for (final id in ['keypadKey_1', 'keypadKey_9', 'keypadDelete']) {
        final rect = tester.getRect(find.byKey(ValueKey(id)));
        expect(rect.left, greaterThanOrEqualTo(0), reason: id);
        expect(rect.right, lessThanOrEqualTo(320), reason: id);
        // A key a thumb can actually hit.
        expect(rect.height, greaterThanOrEqualTo(44), reason: id);
      }
      final ok = tester.getRect(find.byKey(const ValueKey('keypadOk')));
      expect(ok.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text does not overflow the keys', (tester) async {
      narrow(tester);
      await tester.pumpWidget(
        host(onResult: (_) {}, textScale: const TextScaler.linear(3.0)),
      );
      await openCount(tester);

      expect(find.byKey(const ValueKey('keypadOk')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow');

      // The keys still work at that size.
      await typeCount(tester, '5');
      expect(shownCount(tester), '5');
    });

    testWidgets('the keys, delete, OK and the value carry semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      phone(tester);
      await tester.pumpWidget(host(onResult: (_) {}));
      await openCount(tester);
      await typeCount(tester, '12');

      // Every key names itself, and every key can be operated by the name —
      // a glyph a screen reader cannot say is not a control.
      const labels = {
        'keypadKey_7': '7',
        'keypadDelete': 'Delete digit',
        'keypadOk': 'OK, use this number',
      };
      for (final entry in labels.entries) {
        final node = tester.getSemantics(find.byKey(ValueKey(entry.key)));
        expect(node.label, entry.value, reason: entry.key);
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: entry.key,
        );
      }

      final value = tester.getSemantics(
        find.byKey(const ValueKey('saveCountValue')),
      );
      expect(value.label, contains('How many new entries'));
      expect(value.value, '12', reason: 'the number is announced');

      await typeCount(tester, '');
      final empty = tester.getSemantics(
        find.byKey(const ValueKey('saveCountValue')),
      );
      expect(empty.value, 'No number entered', reason: 'never a bare dash');
      semantics.dispose();
    });
  });

  /// The estimate line, as the sheet is showing it.
  String estimateLine(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('saveEstimatedSize')))
      .data!;

  /// A finished image entry of [bytes], the only kind of row the estimate is
  /// allowed to learn from.
  Entry saved(int bytes, {String id = 'e', String status = 'complete'}) =>
      Entry(
        id: id,
        collectionId: 'c',
        title: 'Entry',
        sourceUrl: 'https://example.com/$id',
        urlKey: 'example.com/$id',
        host: 'example.com',
        contentKind: 'imageDominant',
        contentKindConfidence: 'high',
        contentKindIsUserSet: false,
        artifactFormat: ArtifactFormat.imageSequence.name,
        saveStatus: status,
        contentPath: 'library/c/$id',
        detectedAssetCount: 10,
        storedAssetCount: 10,
        entryOrder: 1,
        byteSize: bytes,
        readStatus: 'unread',
        progressFraction: 0,
        progressPageIndex: 0,
        progressOffsetInPage: 0,
      );

  group('what it will cost', () {
    const mb = 1024 * 1024;

    testWidgets('a collection nothing was saved from shows a rough range', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(host(onResult: (_) {}));
      await open(tester);
      await chooseCount(tester);
      await typeCount(tester, '5');
      await tester.ensureVisible(
        find.byKey(const ValueKey('saveEstimatedSize')),
      );

      // The example from the design: five entries, 3–20 MB each.
      expect(estimateLine(tester), contains('15–100 MB'));
      expect(estimateLine(tester), contains('rough'));
      // And never the old flat-constant answer, which was 250 MB for these
      // five and a full gigabyte for twenty.
      expect(estimateLine(tester), isNot(contains('GB')));
    });

    testWidgets('a collection with saved entries is measured, not guessed', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          onResult: (_) {},
          sizeHistory: CollectionSizeHistory.fromEntries([
            for (var i = 0; i < 5; i++) saved(6 * mb, id: 'e$i'),
          ]),
        ),
      );
      await open(tester);
      await chooseCount(tester);
      await typeCount(tester, '5');
      await tester.ensureVisible(
        find.byKey(const ValueKey('saveEstimatedSize')),
      );

      expect(estimateLine(tester), contains('30 MB'));
      expect(estimateLine(tester), contains('already saved here'));
    });

    testWidgets('the single-entry range is estimated too, and for one entry', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          onResult: (_) {},
          sizeHistory: CollectionSizeHistory.fromEntries([
            for (var i = 0; i < 5; i++) saved(12 * mb, id: 'e$i'),
          ]),
        ),
      );
      await open(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('saveEstimatedSize')),
      );

      expect(estimateLine(tester), contains('12 MB'));
    });

    testWidgets('unusable rows are not history', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          onResult: (_) {},
          sizeHistory: CollectionSizeHistory.fromEntries([
            saved(900 * mb, id: 'failed', status: 'failed'),
            saved(0, id: 'empty'),
          ]),
        ),
      );
      await open(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('saveEstimatedSize')),
      );

      // Falls back to the band rather than reporting 900 MB for one entry.
      expect(estimateLine(tester), contains('3–20 MB'));
      expect(estimateLine(tester), contains('rough'));
    });

    testWidgets('a number that does not validate shows no size at all', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(host(onResult: (_) {}));
      await open(tester);
      await chooseCount(tester);

      await typeCount(tester, '');
      await tester.ensureVisible(
        find.byKey(const ValueKey('saveEstimatedSize')),
      );
      expect(estimateLine(tester), kSizeUnknownMessage);

      await typeCount(tester, '0');
      expect(estimateLine(tester), kSizeUnknownMessage);

      await typeCount(tester, '9999');
      expect(estimateLine(tester), kSizeUnknownMessage);
    });

    testWidgets('a count that genuinely is gigabytes says so', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          onResult: (_) {},
          sizeHistory: CollectionSizeHistory.fromEntries([
            for (var i = 0; i < 5; i++) saved(10 * mb, id: 'e$i'),
          ]),
        ),
      );
      await open(tester);
      await chooseCount(tester);
      await typeCount(tester, '400');
      await tester.ensureVisible(
        find.byKey(const ValueKey('saveEstimatedSize')),
      );

      expect(estimateLine(tester), contains('3.9 GB'));
    });
  });

  testWidgets('insufficient space refuses before any choice', (tester) async {
    SaveRangeChoice? result;
    await tester.pumpWidget(
      host(onResult: (r) => result = r, free: 100 * 1024 * 1024),
    );
    await open(tester);

    expect(find.text('Not enough space'), findsOneWidget);
    expect(find.textContaining('not affected'), findsOneWidget);
    expect(find.text('Current entry'), findsNothing);
    await tester.ensureVisible(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  group('what to save', () {
    testWidgets('all three modes are shown, unavailable ones disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          onResult: (_) {},
          capabilities: const CaptureCapabilities(
            content: ContentShape(
              kind: ContentKind.article,
              confidence: ShapeConfidence.high,
            ),
            available: {CaptureMode.textOnly},
            blocked: {
              CaptureMode.imageSequence: ModeBlockReason.noImageSequence,
              CaptureMode.textAndImages: ModeBlockReason.noMeaningfulImages,
            },
            defaultMode: CaptureMode.textOnly,
          ),
        ),
      );
      await open(tester);

      // Present, not hidden — a missing option reads as a bug.
      for (final mode in CaptureMode.values) {
        expect(
          find.byKey(ValueKey('captureMode_${mode.name}')),
          findsOneWidget,
          reason: mode.name,
        );
      }
      // …and the unavailable ones say why.
      expect(
        find.textContaining('does not have enough full-size images'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No images were found inside the readable text'),
        findsOneWidget,
      );
    });

    testWidgets('the detected default is returned when nothing is tapped', (
      tester,
    ) async {
      SaveRangeChoice? result;
      await tester.pumpWidget(
        host(
          onResult: (r) => result = r,
          capabilities: const CaptureCapabilities(
            content: ContentShape(kind: ContentKind.article),
            available: {CaptureMode.textOnly, CaptureMode.textAndImages},
            blocked: {},
            defaultMode: CaptureMode.textAndImages,
          ),
        ),
      );
      await open(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('saveAddToQueue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveAddToQueue')));
      await tester.pumpAndSettle();

      expect(result?.captureMode, CaptureMode.textAndImages);
      expect(result?.captureModeIsUserSet, isFalse);
    });

    testWidgets('choosing a mode marks it as the user\'s own', (tester) async {
      SaveRangeChoice? result;
      await tester.pumpWidget(
        host(
          onResult: (r) => result = r,
          capabilities: const CaptureCapabilities(
            content: ContentShape(kind: ContentKind.article),
            available: {CaptureMode.textOnly, CaptureMode.textAndImages},
            blocked: {},
            defaultMode: CaptureMode.textAndImages,
          ),
        ),
      );
      await open(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('captureMode_textOnly')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('captureMode_textOnly')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('saveAddToQueue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveAddToQueue')));
      await tester.pumpAndSettle();

      expect(result?.captureMode, CaptureMode.textOnly);
      expect(result?.captureModeIsUserSet, isTrue);
    });

    testWidgets('a video page with nothing readable cannot be launched', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          onResult: (_) {},
          capabilities: const CaptureCapabilities(
            content: ContentShape(
              kind: ContentKind.videoDominant,
              confidence: ShapeConfidence.high,
            ),
            available: {},
            blocked: {
              CaptureMode.imageSequence: ModeBlockReason.noImageSequence,
              CaptureMode.textOnly: ModeBlockReason.noReadableText,
              CaptureMode.textAndImages: ModeBlockReason.noReadableText,
            },
            videoDominant: true,
          ),
        ),
      );
      await open(tester);

      expect(find.byKey(const ValueKey('videoNotSavedNotice')), findsOneWidget);
      expect(
        find.textContaining('no readable text to save instead'),
        findsOneWidget,
      );
      // Queueing a save that is going to refuse would be a button that lies.
      final queue = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('saveAddToQueue')),
      );
      expect(queue.onPressed, isNull);
    });

    testWidgets('an unanalysed page offers everything and says so', (
      tester,
    ) async {
      await tester.pumpWidget(host(onResult: (_) {}));
      await open(tester);

      expect(find.textContaining('could not be analysed'), findsOneWidget);
      final queue = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('saveAddToQueue')),
      );
      expect(queue.onPressed, isNotNull);
    });

    testWidgets('an unclassified page says so plainly', (tester) async {
      await tester.pumpWidget(
        host(
          onResult: (_) {},
          capabilities: const CaptureCapabilities(
            content: ContentShape(
              kind: ContentKind.unknownWebContent,
              confidence: ShapeConfidence.low,
            ),
            available: {CaptureMode.imageSequence},
            blocked: {
              CaptureMode.textOnly: ModeBlockReason.noReadableText,
              CaptureMode.textAndImages: ModeBlockReason.noReadableText,
            },
            defaultMode: CaptureMode.imageSequence,
          ),
        ),
      );
      await open(tester);
      // Never "this looks like not something we could classify".
      expect(
        find.textContaining('did not say clearly what it is'),
        findsOneWidget,
      );
      expect(find.textContaining('This looks like'), findsNothing);
    });

    testWidgets('remembering a mode is not offered without a collection', (
      tester,
    ) async {
      await tester.pumpWidget(host(onResult: (_) {}, canRemember: false));
      await open(tester);
      expect(find.byKey(const ValueKey('rememberCaptureMode')), findsNothing);
    });

    testWidgets('remembering a mode is offered when there is one', (
      tester,
    ) async {
      await tester.pumpWidget(host(onResult: (_) {}, canRemember: true));
      await open(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('rememberCaptureMode')),
      );
      expect(find.byKey(const ValueKey('rememberCaptureMode')), findsOneWidget);
    });

    testWidgets('a remembered mode is carried back when it still applies', (
      tester,
    ) async {
      SaveRangeChoice? result;
      await tester.pumpWidget(
        host(
          onResult: (r) => result = r,
          canRemember: true,
          preferredMode: CaptureMode.textOnly,
          capabilities: const CaptureCapabilities(
            content: ContentShape(kind: ContentKind.article),
            available: {CaptureMode.textOnly, CaptureMode.textAndImages},
            blocked: {},
            defaultMode: CaptureMode.textAndImages,
          ),
        ),
      );
      await open(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('saveAddToQueue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveAddToQueue')));
      await tester.pumpAndSettle();

      // The preference wins over the detected default, and the sheet reports
      // that it should stay remembered.
      expect(result?.captureMode, CaptureMode.textOnly);
      expect(result?.rememberForCollection, isTrue);
    });
  });
}

class _FixedStorage extends DeviceStorage {
  _FixedStorage(this.free);
  final int? free;

  @override
  Future<int?> freeBytes() async => free;
}

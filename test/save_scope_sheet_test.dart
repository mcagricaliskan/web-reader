import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/save/capture_mode.dart';
import 'package:web_reader/library/content_shape.dart';
import 'package:web_reader/core/device_storage.dart';
import 'package:web_reader/features/save_scope_sheet.dart';

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
  }) => MaterialApp(
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
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      await open(tester);

      await tester.ensureVisible(find.text('Number of entries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Number of entries'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '150');
      await tester.pumpAndSettle();
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
    // A phone-sized surface: with the count field open the sheet is taller
    // than the test default, and the actions live below it.
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SaveRangeChoice? result;
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await open(tester);
    await tester.ensureVisible(find.text('Number of entries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Number of entries'));
    await tester.pumpAndSettle();

    // Zero refuses — and the sheet stays open, error visible.
    await tester.enterText(find.byType(TextField), '0');
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
    await tester.enterText(find.byType(TextField), '9999');
    await tester.ensureVisible(find.byKey(const ValueKey('saveStartNow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saveStartNow')));
    await tester.pump();
    expect(
      find.textContaining('${const SaveConfig().maxEntriesPerRun}'),
      findsWidgets,
    );
    expect(result, isNull);

    // Decimals cannot be typed at all (digits-only keyboard filter).
    await tester.enterText(find.byType(TextField), '3.5');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '35',
    );

    // A valid number shows the summary and returns with the chosen launch.
    await tester.enterText(find.byType(TextField), '8');
    await tester.pump();
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

  /// Confirming the number and authorising the save are separate acts. A
  /// number pad has no return key on iOS, so the sheet has to offer the way
  /// out itself — and that way out must not start anything.
  group('confirming the typed count', () {
    /// A phone-sized surface: with the count field open the sheet is taller
    /// than the test default.
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    /// Chooses the typed-count range on an already-open sheet.
    Future<TextField> chooseCount(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Number of entries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Number of entries'));
      await tester.pumpAndSettle();
      return tester.widget<TextField>(find.byType(TextField));
    }

    Future<TextField> openCount(WidgetTester tester) async {
      phone(tester);
      await open(tester);
      return chooseCount(tester);
    }

    testWidgets('the Done action is on screen with the field', (tester) async {
      // At 320pt: the field, its label and the action share one row on the
      // narrowest phone the design supports.
      narrow(tester);
      await tester.pumpWidget(host(onResult: (_) {}));
      await open(tester);

      // Not before: with no count to confirm there is nothing to confirm.
      expect(find.byKey(const ValueKey('saveCountDone')), findsNothing);

      await chooseCount(tester);
      final done = find.byKey(const ValueKey('saveCountDone'));
      expect(done, findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(tester.getRect(done).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Done keeps the value, drops focus, and starts nothing', (
      tester,
    ) async {
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      final field = await openCount(tester);

      await tester.enterText(find.byType(TextField), '12');
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isTrue, reason: 'typing focuses it');

      await tester.ensureVisible(find.byKey(const ValueKey('saveCountDone')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveCountDone')));
      await tester.pumpAndSettle();

      expect(field.controller!.text, '12', reason: 'the value is kept');
      expect(field.focusNode!.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      // Confirming a number is not authorising a save.
      expect(result, isNull);
      expect(find.byKey(const ValueKey('saveStartNow')), findsOneWidget);
      expect(find.byKey(const ValueKey('saveAddToQueue')), findsOneWidget);
      // …and the launch that does authorise one still carries the number.
      await tester.ensureVisible(find.byKey(const ValueKey('saveStartNow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveStartNow')));
      await tester.pumpAndSettle();
      expect(result?.mode, SaveScope.fixedCount);
      expect(result?.count, 12);
      expect(result?.action, SaveSheetAction.startNow);
    });

    testWidgets('the keyboard\'s own Done does the same thing', (tester) async {
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      final field = await openCount(tester);

      await tester.enterText(find.byType(TextField), '7');
      await tester.pumpAndSettle();
      expect(field.textInputAction, TextInputAction.done);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(field.controller!.text, '7');
      expect(field.focusNode!.hasFocus, isFalse);
      expect(result, isNull);
    });

    testWidgets('Done answers a bad number where it was typed', (tester) async {
      SaveRangeChoice? result;
      await tester.pumpWidget(host(onResult: (r) => result = r));
      final field = await openCount(tester);

      await tester.enterText(find.byType(TextField), '0');
      await tester.ensureVisible(find.byKey(const ValueKey('saveCountDone')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveCountDone')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 or more'), findsOneWidget);
      expect(field.controller!.text, '0', reason: 'nothing is typed for them');
      expect(result, isNull);

      // The same bound the launches enforce, named the same way.
      await tester.enterText(find.byType(TextField), '9999');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveCountDone')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('At most ${const SaveConfig().maxEntriesPerRun}'),
        findsOneWidget,
      );
      expect(result, isNull);

      // A number that is fine clears the answer and leaves the field alone.
      await tester.enterText(find.byType(TextField), '4');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveCountDone')));
      await tester.pumpAndSettle();
      expect(find.textContaining('At most'), findsNothing);
      expect(find.textContaining('1 or more'), findsNothing);
      expect(field.controller!.text, '4');
    });

    testWidgets('tapping the sheet elsewhere also puts the keyboard away', (
      tester,
    ) async {
      await tester.pumpWidget(host(onResult: (_) {}));
      final field = await openCount(tester);
      expect(field.focusNode!.hasFocus, isTrue);

      // A tap on another control does its own job *and* ends the editing.
      await tester.tap(find.text('Current entry'));
      await tester.pumpAndSettle();

      expect(field.focusNode!.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byType(TextField), findsNothing, reason: 'range switched');
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

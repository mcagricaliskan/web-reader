import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/core/config.dart';
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
            );
            onResult(r);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The narrowest phone the design supports: both actions must fit here.
  void narrow(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('exactly the three choices, no count presets', (tester) async {
    await tester.pumpWidget(host(onResult: (_) {}));
    await open(tester);

    expect(find.text('Current entry'), findsOneWidget);
    expect(find.text('Number of entries'), findsOneWidget);
    expect(find.text('Until the end'), findsOneWidget);
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

      await tester.tap(find.text('Until the end'));
      await tester.pumpAndSettle();

      expect(result, isNull, reason: 'choosing a range decides nothing yet');
      expect(find.text('Until the end'), findsOneWidget);
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

      await tester.tap(find.text('Until the end'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saveStartNow')));
      await tester.pumpAndSettle();

      expect(result?.mode, SaveScope.untilNoNextPage);
      expect(result?.action, SaveSheetAction.startNow);
    });

    testWidgets('until the end names its safety limit', (tester) async {
      await tester.pumpWidget(host(onResult: (_) {}));
      await open(tester);
      expect(
        find.textContaining(
          'safety limit: ${const SaveConfig().untilEndSafetyLimit}',
        ),
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
    await tester.tap(find.text('Number of entries'));
    await tester.pumpAndSettle();

    // Zero refuses — and the sheet stays open, error visible.
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.byKey(const ValueKey('saveStartNow')));
    await tester.pump();
    expect(find.textContaining('1 or more'), findsOneWidget);
    expect(result, isNull);
    expect(find.byKey(const ValueKey('saveAddToQueue')), findsOneWidget);

    // The same validation guards the queue action.
    await tester.tap(find.byKey(const ValueKey('saveAddToQueue')));
    await tester.pump();
    expect(result, isNull);

    // Excessive refuses, naming the bound.
    await tester.enterText(find.byType(TextField), '9999');
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
    await tester.tap(find.byKey(const ValueKey('saveStartNow')));
    await tester.pumpAndSettle();
    expect(result?.mode, SaveScope.fixedCount);
    expect(result?.count, 8);
    expect(result?.action, SaveSheetAction.startNow);
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
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}

class _FixedStorage extends DeviceStorage {
  _FixedStorage(this.free);
  final int? free;

  @override
  Future<int?> freeBytes() async => free;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/core/config.dart';
import 'package:web_reader/core/device_storage.dart';
import 'package:web_reader/features/capture_range_sheet.dart';

/// The three-choice range sheet: exactly three options, typed counts with
/// validation, and the disk refusal in front of everything.
void main() {
  Widget host({
    required void Function(CaptureRangeChoice?) onResult,
    int? free = 8 * 1024 * 1024 * 1024,
  }) => MaterialApp(
    home: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () async {
            final r = await showCaptureRangeSheet(
              context: context,
              config: const CaptureConfig(),
              deviceStorage: _FixedStorage(free),
              currentTitle: 'Foo Chapter 137',
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

  testWidgets('exactly the three choices, no count presets', (tester) async {
    await tester.pumpWidget(host(onResult: (_) {}));
    await open(tester);

    expect(find.text('Current chapter'), findsOneWidget);
    expect(find.text('Number of chapters'), findsOneWidget);
    expect(find.text('Until the end'), findsOneWidget);
    expect(find.textContaining('3 chapters'), findsNothing);
    expect(find.textContaining('5 chapters'), findsNothing);
    expect(find.textContaining('Next 3'), findsNothing);
    expect(find.textContaining('Next 5'), findsNothing);
  });

  testWidgets('current chapter returns its mode', (tester) async {
    CaptureRangeChoice? result;
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await open(tester);
    await tester.tap(find.text('Current chapter'));
    await tester.pumpAndSettle();

    expect(result?.mode, CaptureRangeMode.currentChapter);
  });

  testWidgets('until the end returns its mode and names the limit', (
    tester,
  ) async {
    CaptureRangeChoice? result;
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await open(tester);

    expect(
      find.textContaining(
        'safety limit: ${const CaptureConfig().untilEndSafetyLimit}',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Until the end'));
    await tester.pumpAndSettle();
    expect(result?.mode, CaptureRangeMode.untilEnd);
  });

  testWidgets('typed count is validated and summarised', (tester) async {
    CaptureRangeChoice? result;
    await tester.pumpWidget(host(onResult: (r) => result = r));
    await open(tester);
    await tester.tap(find.text('Number of chapters'));
    await tester.pumpAndSettle();

    // Zero refuses.
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Start capture'));
    await tester.pump();
    expect(find.textContaining('1 or more'), findsOneWidget);
    expect(result, isNull);

    // Excessive refuses, naming the bound.
    await tester.enterText(find.byType(TextField), '9999');
    await tester.tap(find.text('Start capture'));
    await tester.pump();
    expect(
      find.textContaining('${const CaptureConfig().maxChaptersPerJob}'),
      findsWidgets,
    );
    expect(result, isNull);

    // Decimals cannot be typed at all (digits-only keyboard filter).
    await tester.enterText(find.byType(TextField), '3.5');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '35',
    );

    // A valid number shows the summary and returns.
    await tester.enterText(find.byType(TextField), '8');
    await tester.pump();
    expect(find.textContaining('Capture 8 new chapters'), findsOneWidget);
    expect(find.textContaining('Foo Chapter 137'), findsWidgets);
    await tester.tap(find.text('Start capture'));
    await tester.pumpAndSettle();
    expect(result?.mode, CaptureRangeMode.fixedCount);
    expect(result?.count, 8);
  });

  testWidgets('insufficient space refuses before any choice', (tester) async {
    CaptureRangeChoice? result;
    await tester.pumpWidget(
      host(onResult: (r) => result = r, free: 100 * 1024 * 1024),
    );
    await open(tester);

    expect(find.text('Not enough space'), findsOneWidget);
    expect(find.textContaining('not affected'), findsOneWidget);
    expect(find.text('Current chapter'), findsNothing);
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

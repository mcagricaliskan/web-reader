import 'package:flutter_test/flutter_test.dart';
import 'package:web_reader/capture/capture_state.dart';

void main() {
  group('capture state transitions', () {
    test('the happy path for a single chapter is legal end to end', () {
      const path = [
        CaptureState.idle,
        CaptureState.inspecting,
        CaptureState.scrolling,
        CaptureState.waitingForAssets,
        CaptureState.verifying,
        CaptureState.extracting,
        CaptureState.downloading,
        CaptureState.saving,
        CaptureState.complete,
      ];

      for (var i = 0; i < path.length - 1; i++) {
        expect(
          isTransitionAllowed(path[i], path[i + 1]),
          isTrue,
          reason: '${path[i].name} -> ${path[i + 1].name}',
        );
      }
    });

    test('the multi-chapter loop closes back to inspecting', () {
      expect(
        isTransitionAllowed(CaptureState.saving, CaptureState.detectingNext),
        isTrue,
      );
      expect(
        isTransitionAllowed(
          CaptureState.detectingNext,
          CaptureState.navigating,
        ),
        isTrue,
      );
      expect(
        isTransitionAllowed(CaptureState.navigating, CaptureState.inspecting),
        isTrue,
      );
    });

    test('capture can never jump straight from scrolling to complete', () {
      expect(
        isTransitionAllowed(CaptureState.scrolling, CaptureState.complete),
        isFalse,
      );
    });

    test('downloading cannot skip saving', () {
      expect(
        isTransitionAllowed(CaptureState.downloading, CaptureState.complete),
        isFalse,
      );
      expect(
        isTransitionAllowed(CaptureState.downloading, CaptureState.saving),
        isTrue,
      );
    });

    test('every running state can be paused and cancelled', () {
      const running = [
        CaptureState.inspecting,
        CaptureState.scrolling,
        CaptureState.waitingForAssets,
        CaptureState.verifying,
        CaptureState.extracting,
        CaptureState.downloading,
        CaptureState.detectingNext,
        CaptureState.navigating,
      ];
      for (final state in running) {
        expect(
          isTransitionAllowed(state, CaptureState.paused),
          isTrue,
          reason: '${state.name} -> paused',
        );
        expect(
          isTransitionAllowed(state, CaptureState.cancelled),
          isTrue,
          reason: '${state.name} -> cancelled',
        );
      }
    });

    test('pause returns to any working state', () {
      expect(
        isTransitionAllowed(CaptureState.paused, CaptureState.downloading),
        isTrue,
      );
      expect(
        isTransitionAllowed(CaptureState.paused, CaptureState.scrolling),
        isTrue,
      );
    });

    test(
      'terminal states are terminal, and only restart into a new capture',
      () {
        for (final state in [
          CaptureState.complete,
          CaptureState.partial,
          CaptureState.failed,
          CaptureState.cancelled,
        ]) {
          expect(state.isTerminal, isTrue);
          expect(state.isRunning, isFalse);
          expect(isTransitionAllowed(state, CaptureState.downloading), isFalse);
          expect(isTransitionAllowed(state, CaptureState.inspecting), isTrue);
        }
      },
    );

    test('idle and paused are not "running"', () {
      expect(CaptureState.idle.isRunning, isFalse);
      expect(CaptureState.paused.isRunning, isFalse);
      expect(CaptureState.scrolling.isRunning, isTrue);
    });

    test('staying in the same state is always legal', () {
      for (final state in CaptureState.values) {
        expect(isTransitionAllowed(state, state), isTrue);
      }
    });

    test('every state has a human label', () {
      for (final state in CaptureState.values) {
        expect(state.label, isNotEmpty);
      }
    });
  });

  group('CaptureProgress', () {
    test('copyWith preserves untouched fields', () {
      const p = CaptureProgress(
        state: CaptureState.downloading,
        currentUrl: 'https://x.com/1',
        detectedImages: 6,
        requestedChapters: 3,
      );
      final next = p.copyWith(storedImages: 4);

      expect(next.storedImages, 4);
      expect(next.detectedImages, 6);
      expect(next.currentUrl, 'https://x.com/1');
      expect(next.requestedChapters, 3);
      expect(next.state, CaptureState.downloading);
    });

    test('clearError wipes the error rather than carrying it forward', () {
      const p = CaptureProgress(lastError: 'HTTP 503');
      expect(p.copyWith(clearError: true).lastError, isNull);
      expect(p.copyWith(storedImages: 1).lastError, 'HTTP 503');
    });
  });
}

import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/media/livekit_audio_visualizer.dart';

void main() {
  group('AudioVisualizerCircuitBreaker', () {
    test('disables a missing native implementation across widget remounts', () {
      final circuitBreaker = AudioVisualizerCircuitBreaker()
        ..recordFailure(MissingPluginException());

      check(circuitBreaker.canAttempt).isFalse();
    });

    test('keeps transient failures retryable', () {
      final circuitBreaker = AudioVisualizerCircuitBreaker()
        ..recordFailure(StateError('listener startup failed'));

      check(circuitBreaker.canAttempt).isTrue();
    });
  });

  group('waveformIsActive', () {
    test(
      'ignores background noise until a sample crosses the activation gate',
      () {
        check(
          waveformIsActive(const [0.01, 0.03, 0.02], wasActive: false),
        ).isFalse();
        check(
          waveformIsActive(const [0.01, 0.04, 0.02], wasActive: false),
        ).isTrue();
      },
    );

    test(
      'holds the waveform through small changes before settling to silence',
      () {
        check(waveformIsActive(const [0.025, 0.01], wasActive: true)).isTrue();
        check(waveformIsActive(const [0.019, 0.01], wasActive: true)).isFalse();
      },
    );
  });

  group('audioVisualizerSamplesChanged', () {
    test('ignores imperceptible changes and detects visible changes', () {
      check(
        audioVisualizerSamplesChanged(
          const [0.1, 0.5, 0.9],
          const [0.105, 0.495, 0.9],
        ),
      ).isFalse();
      check(
        audioVisualizerSamplesChanged(
          const [0.1, 0.5, 0.9],
          const [0.111, 0.5, 0.9],
        ),
      ).isTrue();
      check(
        audioVisualizerSamplesChanged(const [0.1], const [0.1, 0.2]),
      ).isTrue();
    });

    test('settles a previously visible waveform to silence', () {
      check(audioVisualizerSamplesChanged(const [0.009], const [0])).isTrue();
    });
  });
}

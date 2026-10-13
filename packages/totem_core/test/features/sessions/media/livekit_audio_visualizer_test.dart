import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/media/livekit_audio_visualizer.dart';

void main() {
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
      check(audioVisualizerSamplesChanged(const [0.1], const [0.1, 0.2]))
          .isTrue();
    });

    test('settles a previously visible waveform to silence', () {
      check(audioVisualizerSamplesChanged(const [0.009], const [0])).isTrue();
    });
  });
}

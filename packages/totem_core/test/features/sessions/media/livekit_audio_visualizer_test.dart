import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_audio_visualizer.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';

import '../livekit_mocks.dart';

void main() {
  testWidgets('renders louder microphone samples with taller bars', (
    tester,
  ) async {
    final samples = StreamController<List<double>>(sync: true);
    final track = MockLocalAudioTrack();
    addTearDown(samples.close);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 50,
          height: 20,
          child: SoundWaveformWidget(
            audioTrack: track,
            barCount: 5,
            color: Colors.white,
            sampleLevels: samples.stream,
          ),
        ),
      ),
    );
    samples.add(const [0.05, 0.05, 0.05, 0.05, 0.05]);
    await tester.pump();
    final quiet = List.of(
      tester.widget<LevelBars>(find.byType(LevelBars)).levels.value,
    );

    samples.add(const [0.2, 0.4, 0.6, 0.8, 1]);
    await tester.pump(const Duration(milliseconds: 140));
    final loud = tester.widget<LevelBars>(find.byType(LevelBars)).levels.value;
    check(loud[0]).isLessThan(loud[4]);
    check(loud[2]).isGreaterThan(quiet[2]);

    samples.add(const [0, 0, 0, 0, 0]);
    await tester.pump(const Duration(milliseconds: 140));
    check(
      tester.widget<LevelBars>(find.byType(LevelBars)).levels.value,
    ).deepEquals(const [0, 0, 0, 0, 0]);

    samples.add(const [0, 0, 0, 0, 0]);
    await tester.pump(const Duration(milliseconds: 140));
    check(tester.binding.hasScheduledFrame).isFalse();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    check(samples.hasListener).isFalse();
  });

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

  group('webWaveformIsActive', () {
    test('filters quantized background noise before activating', () {
      check(
        webWaveformIsActive(const [0.05, 0, 0, 0, 0], wasActive: false),
      ).isFalse();
      check(
        webWaveformIsActive(const [0.1, 0, 0, 0, 0], wasActive: false),
      ).isFalse();
      check(
        webWaveformIsActive(const [0, 0.15, 0, 0, 0], wasActive: false),
      ).isTrue();
    });

    test('holds the first visible Web Audio step until silence', () {
      check(
        webWaveformIsActive(const [0.05, 0, 0, 0, 0], wasActive: true),
      ).isTrue();
      check(
        webWaveformIsActive(const [0, 0, 0, 0, 0], wasActive: true),
      ).isFalse();
    });
  });
}

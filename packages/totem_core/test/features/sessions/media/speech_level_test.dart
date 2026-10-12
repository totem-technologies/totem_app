import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/media/speech_level.dart';

void main() {
  group('speechLevel', () {
    test('background noise reads as silence', () {
      check(speechLevel(double.negativeInfinity)).equals(0);
      check(speechLevel(-60)).equals(0);
      check(speechLevel(-45)).equals(0);
    });

    test('quiet speech LiveKit counts as active shows', () {
      check(speechLevel(-35)).isGreaterThan(0.25);
    });

    test('loud speech fills the bars', () {
      check(speechLevel(-15)).equals(1);
      check(speechLevel(0)).equals(1);
    });

    test('moves in steps, so small fluctuations do not redraw', () {
      check(speechLevel(-30)).equals(speechLevel(-29.9));
    });
  });

  test('amplitudeToDb converts LiveKit audio levels', () {
    check(amplitudeToDb(1)).equals(0);
    check(amplitudeToDb(0.1)).isCloseTo(-20, 0.0001);
    check(amplitudeToDb(0)).equals(double.negativeInfinity);
  });

  test('rmsDb measures a sine wave', () {
    // A sine at amplitude 0.1 has an RMS of 0.1 / sqrt(2), about -23 dB.
    final samples = Float32List.fromList([
      for (var i = 0; i < 480; i++) 0.1 * math.sin(2 * math.pi * i / 48),
    ]);

    check(rmsDb(samples)).isCloseTo(-23.01, 0.01);
    check(rmsDb(Float32List(480))).equals(double.negativeInfinity);
  });
}

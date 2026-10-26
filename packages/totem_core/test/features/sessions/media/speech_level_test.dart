import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/media/speech_level.dart';

void main() {
  group('SpeechLevelMeter', () {
    late Duration now;
    late SpeechLevelMeter meter;

    setUp(() {
      now = Duration.zero;
      meter = SpeechLevelMeter(now: () => now);
    });

    double read(
      double db, {
      Duration after = const Duration(milliseconds: 100),
    }) {
      now += after;
      return meter.level(db);
    }

    test('silence and noise below the gate read as zero', () {
      check(read(double.negativeInfinity)).equals(0);
      check(read(-60)).equals(0);
    });

    test('the loudest recent speech fills the bars', () {
      check(read(-20)).equals(1);
      check(read(-32)).isGreaterThan(0.3);
      check(read(-32)).isLessThan(0.7);
    });

    test('quiet and loud microphones look the same', () {
      final quieter = SpeechLevelMeter(now: () => now);
      final louder = SpeechLevelMeter(now: () => now);
      quieter.level(-20);
      louder.level(-10);

      check(quieter.level(-30)).equals(louder.level(-20));
    });

    test('noise just above the gate shows barely any bar', () {
      check(read(-50)).equals(0);
      check(read(-49)).isLessThan(0.1);
      check(read(-45)).isLessThan(0.25);
    });

    test('noise stays low after a long silence', () {
      read(-20);
      read(double.negativeInfinity, after: const Duration(seconds: 30));

      check(read(-49)).isLessThan(0.1);
      check(read(-45)).isLessThan(0.25);
    });

    test('background noise well below speech reads as zero', () {
      read(-20);

      check(read(-48)).equals(0);
    });

    test('a loud moment stops dominating after a while', () {
      read(-10);
      final soonAfter = read(-25);

      final muchLater = read(-25, after: const Duration(seconds: 20));

      check(muchLater).isGreaterThan(soonAfter);
      check(muchLater).equals(1);
    });

    test('moves in steps, so small fluctuations do not redraw', () {
      read(-20);

      check(read(-30)).equals(read(-30.05));
    });
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

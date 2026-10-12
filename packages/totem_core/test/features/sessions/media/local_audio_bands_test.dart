import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/media/local_audio_bands.dart';

void main() {
  group('speechBands', () {
    test('silence and background noise read as zero', () {
      check(speechBands(Uint8List(128), 3)).deepEquals([0, 0, 0]);
      check(
        speechBands(Uint8List(128)..fillRange(0, 128, 3), 3),
      ).deepEquals([0, 0, 0]);
    });

    test('puts the lowest band in the middle', () {
      // Energy only in the lowest speech frequencies.
      final spectrum = Uint8List(128)..fillRange(0, 7, 255);

      final bands = speechBands(spectrum, 3);

      check(bands[1]).equals(1);
      check(bands[0]).equals(0);
      check(bands[2]).equals(0);
    });

    test('ignores frequencies above the speech range', () {
      final spectrum = Uint8List(128)..fillRange(40, 128, 255);

      check(speechBands(spectrum, 5)).every((it) => it.equals(0));
    });

    test('levels stay between 0 and 1', () {
      final spectrum = Uint8List(128)..fillRange(0, 128, 255);

      check(speechBands(spectrum, 7)).every(
        (it) => it
          ..isGreaterOrEqual(0)
          ..isLessOrEqual(1),
      );
    });
  });

  group('speechBandsChanged', () {
    test('ignores small differences', () {
      check(speechBandsChanged([0.5, 0.5], [0.52, 0.48])).isFalse();
    });

    test('reports visible differences', () {
      check(speechBandsChanged([0.5, 0.5], [0.6, 0.5])).isTrue();
      check(speechBandsChanged(const [], [0.0])).isTrue();
    });
  });
}

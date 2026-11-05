import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_benchmark/synthetic_speech.dart';

void main() {
  test('a seeded talker repeats exactly and alternates speech with pauses', () {
    List<List<double>> talk(int seed) {
      final speech = SyntheticSpeech(seed);
      return [for (var i = 0; i < 200; i++) speech.next()];
    }

    final samples = talk(3);
    check(talk(3)).deepEquals(samples);
    check(samples).every((it) => it.length.equals(5));
    check(samples).any((it) => it.every((level) => level.equals(0)));
    check(samples).any((it) => it.any((level) => level.isGreaterThan(0.5)));
  });
}

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/media/local_audio_level.dart';

void main() {
  group('heldSpeechLevel', () {
    test('rises at once', () {
      check(heldSpeechLevel(0.2, 0.8)).equals(0.8);
    });

    test('falls gradually between words', () {
      var shown = 0.8;
      final steps = <double>[];
      while (shown > 0) {
        shown = heldSpeechLevel(shown, 0);
        steps.add(shown);
      }

      check(steps.first).isGreaterThan(0.5);
      check(steps.length).isGreaterThan(3);
      check(steps.last).equals(0);
    });

    test('stays on the speech level steps', () {
      check(heldSpeechLevel(0.35, 0)).equals(0.2);
    });
  });
}

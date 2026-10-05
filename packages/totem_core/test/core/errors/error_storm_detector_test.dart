import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/core/errors/error_storm_detector.dart';

void main() {
  group('ErrorStormDetector', () {
    late DateTime now;
    late int storms;
    late ErrorStormDetector detector;

    setUp(() {
      now = DateTime(2026, 10, 5);
      storms = 0;
      detector = ErrorStormDetector(
        threshold: 3,
        window: const Duration(seconds: 10),
        clock: () => now,
        onStorm: () => storms++,
      );
    });

    test('fires once the threshold is reached within the window', () {
      detector
        ..record()
        ..record();
      check(storms).equals(0);
      detector.record();
      check(storms).equals(1);
    });

    test('ignores errors spread out beyond the window', () {
      for (var i = 0; i < 10; i++) {
        detector.record();
        now = now.add(const Duration(seconds: 6));
      }
      check(storms).equals(0);
    });

    test('fires only once per page', () {
      for (var i = 0; i < 20; i++) {
        detector.record();
      }
      check(storms).equals(1);
    });
  });

  group('isUnhandledSentryEvent', () {
    SentryEvent eventWith({bool? handled}) => SentryEvent(
      exceptions: [
        SentryException(
          type: 'NoSuchMethodError',
          value: 'Null check operator used on a null value',
          mechanism: handled == null
              ? null
              : Mechanism(type: 'runZonedGuarded', handled: handled),
        ),
      ],
    );

    test('is true when an exception mechanism is unhandled', () {
      check(isUnhandledSentryEvent(eventWith(handled: false))).isTrue();
    });

    test('is false for handled or mechanism-less exceptions', () {
      check(isUnhandledSentryEvent(eventWith(handled: true))).isFalse();
      check(isUnhandledSentryEvent(eventWith())).isFalse();
      check(isUnhandledSentryEvent(SentryEvent())).isFalse();
    });
  });
}

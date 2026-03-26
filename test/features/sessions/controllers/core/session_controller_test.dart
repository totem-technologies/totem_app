import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';

void main() {
  group('SessionController', () {
    group('static configuration', () {
      test('syncTimerDuration is 20 seconds', () {
        expect(
          SessionController.syncTimerDuration,
          equals(const Duration(seconds: 20)),
        );
      });

      test('syncTimerDuration is positive', () {
        expect(
          SessionController.syncTimerDuration.isNegative,
          isFalse,
        );
      });
    });
  });
}

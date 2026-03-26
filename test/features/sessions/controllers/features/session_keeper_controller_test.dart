import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/sessions/controllers/features/session_keeper_controller.dart';

void main() {
  group('SessionKeeperController', () {
    test('keeper disconnection timeout is exactly 3 minutes', () {
      expect(
        SessionKeeperController.keeperDisconnectionTimeout,
        equals(const Duration(minutes: 3)),
      );
    });
  });
}

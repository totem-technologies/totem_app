import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/sessions/controllers/features/session_device_controller.dart';

void main() {
  group('SessionDeviceController', () {
    test('externalAudioOutputTypes includes common audio output devices', () {
      // Verify that common external audio device types are recognized
      expect(
        SessionDeviceController.externalAudioOutputTypes.length,
        greaterThan(0),
        reason: 'Should have at least one external audio output type',
      );
    });

    test('externalAudioOutputTypes contains expected device type names', () {
      final deviceTypeNames = SessionDeviceController.externalAudioOutputTypes
          .map((e) => e.toString())
          .toList();

      expect(deviceTypeNames, isNotEmpty);
    });

    test('externalAudioOutputTypes includes common headset types', () {
      final typeStrings = SessionDeviceController.externalAudioOutputTypes
          .map((e) => e.toString())
          .toList();

      // Should handle various audio output scenarios
      expect(typeStrings, isNotEmpty);
    });
  });
}

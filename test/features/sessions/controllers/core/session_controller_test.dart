import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions;
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

      test('defaultCameraCaptureOptions is defined', () {
        expect(
          SessionController.defaultCameraCaptureOptions,
          isNotNull,
        );
      });

      test('defaultCameraCaptureOptions has h720_43 dimensions', () {
        expect(
          SessionController.defaultCameraCaptureOptions.params?.dimensions,
          equals(VideoDimensionsPresets.h720_43),
        );
      });

      test('defaultCameraCaptureOptions has 20 fps framerate', () {
        expect(
          SessionController
              .defaultCameraCaptureOptions
              .params
              ?.encoding
              ?.maxFramerate,
          equals(20),
        );
      });

      test('defaultCameraCaptureOptions has 1300kbps bitrate', () {
        expect(
          SessionController
              .defaultCameraCaptureOptions
              .params
              ?.encoding
              ?.maxBitrate,
          equals(1300 * 1000),
        );
      });
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks/checks.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

void main() {
  group('SessionController video codecs by platform', () {
    for (final platform in [
      (name: 'native', web: false, wasm: false, codec: 'h265'),
      (name: 'JavaScript web', web: true, wasm: false, codec: 'h264'),
      (name: 'Wasm web', web: true, wasm: true, codec: 'h264'),
      (name: 'Wasm', web: false, wasm: true, codec: 'h264'),
    ]) {
      test('${platform.name} selects ${platform.codec} with h264 backup', () {
        final options = SessionController.videoPublishOptionsForPlatform(
          isWeb: platform.web,
          isWasm: platform.wasm,
        );
        check(options.videoCodec).equals(platform.codec);
        check(options.backupVideoCodec.enabled).isTrue();
        check(options.backupVideoCodec.codec).equals('h264');
      });
    }
  });

  group('SessionController defaultVideoPublishOptions', () {
    test('uses the codec for the current runtime', () {
      check(
        SessionController.defaultVideoPublishOptions.videoCodec,
      ).equals(kIsWeb || kIsWasm ? 'h264' : 'h265');
    });

    test('configures h264 as backup video codec', () {
      final backup =
          SessionController.defaultVideoPublishOptions.backupVideoCodec;
      check(backup.enabled).equals(true);
      check(backup.codec).equals('h264');
    });
  });
}

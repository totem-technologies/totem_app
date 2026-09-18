@TestOn('chrome')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:checks/checks.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

void main() {
  group('SessionController defaultVideoPublishOptions on web', () {
    test('uses h264 codec', () {
      check(
        SessionController.defaultVideoPublishOptions.videoCodec,
      ).equals('h264');
    });

    test('configures h264 as backup video codec', () {
      final backup =
          SessionController.defaultVideoPublishOptions.backupVideoCodec;
      check(backup.enabled).equals(true);
      check(backup.codec).equals('h264');
    });
  });
}

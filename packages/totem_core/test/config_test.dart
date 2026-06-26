import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/config/app_config.dart';

void main() {
  // Validates the .env files in each consuming package by feeding them
  // through [AppConfig.parse]. These are composed from config/ by
  // scripts/setup_env.dart (see config/README.md), so a misconfigured layer
  // that omits a required key (e.g. LIVEKIT_URL) fails here instead of
  // shipping a build that hangs on the splash screen at runtime.
  for (final package in const ['totem_app', 'totem_web']) {
    test('$package/.env builds an AppConfig', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final envFile = File('../$package/.env');
      expect(
        envFile.existsSync(),
        isTrue,
        reason:
            'Missing ${envFile.path}; generate it with `make env-dev` '
            '(or scripts/setup_env.dart <flavor>). See config/README.md.',
      );
      AppConfig.parse(envFile.readAsStringSync());
    });
  }
}

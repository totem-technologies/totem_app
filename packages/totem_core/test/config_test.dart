import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/config/app_config.dart';

void main() {
  test('valid configuration builds an AppConfig', () {
    final config = AppConfig.parse('''
ENVIRONMENT=development
API_URL=https://api.totem.org/
LIVEKIT_URL=wss://livekit.totem.org/
''');

    check(config.apiUrl).equals('https://api.totem.org/');
    check(config.liveKitUrl).equals('wss://livekit.totem.org/');
  });
}

// We are not importing firebase_core_platform_interface directly
// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/src/pigeon/mocks.dart'
    show setupFirebaseCoreMocks;
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:totem_core/core/config/app_config.dart';

/// Assigns [AppConfig.instance] to a test-friendly default. Any overrides
/// passed in replace the defaults — required for tests that exercise code
/// reading specific config values (e.g. `liveKitUrl`).
void setupAppConfig({
  Environment environment = Environment.production,
  String apiUrl = 'https://test.example.com/',
  String liveKitUrl = 'wss://test.livekit.cloud',
  int maxPinAttempts = 5,
  String? vapidKey,
  bool analyticsEnabled = false,
  String? sentryDsn,
  String? posthogApiKey,
  String posthogHost = 'https://us.i.posthog.com',
  Uri? privacyPolicyUrl,
  Uri? termsOfServiceUrl,
  Uri? communityGuidelinesUrl,
}) {
  AppConfig.instance = AppConfig(
    environment: environment,
    apiUrl: apiUrl,
    liveKitUrl: liveKitUrl,
    maxPinAttempts: maxPinAttempts,
    vapidKey: vapidKey,
    analyticsEnabled: analyticsEnabled,
    sentryDsn: sentryDsn,
    posthogApiKey: posthogApiKey,
    posthogHost: posthogHost,
    privacyPolicyUrl:
        privacyPolicyUrl ?? Uri.parse('https://example.com/privacy'),
    termsOfServiceUrl:
        termsOfServiceUrl ?? Uri.parse('https://example.com/tos'),
    communityGuidelinesUrl:
        communityGuidelinesUrl ?? Uri.parse('https://example.com/guidelines'),
  );
}

void silenceLogger() {
  Logger.level = Level.off;
}

Future<void> setupFirebase() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setupFirebaseCoreMocks();

  await Firebase.initializeApp(
    name: 'test_app',
    options: const FirebaseOptions(
      apiKey: 'test_api_key',
      appId: 'test_app_id',
      messagingSenderId: 'test_messaging_sender_id',
      projectId: 'test_project_id',
    ),
  );
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/shared/router.dart';

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

/// A minimal [TotemRouter] implementation for use in unit tests.
/// All methods are no-ops except [GlobalKey] and [baseUri] accessors.
class FakeTotemRouter extends TotemRouter {
  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Uri get baseUri => Uri.parse('https://test.example.com/');

  @override
  void popOrHome([BuildContext? context]) {}

  @override
  void toHome([HomeRoutes route = HomeRoutes.initialRoute]) {}

  @override
  Future<void> toKeeperProfile(BuildContext context, String userSlug) async {}

  @override
  Future<void> toSpaceSession(
    BuildContext context,
    String spaceSlug,
    String? sessionSlug, [
    bool replacement = false,
  ]) async {}

  @override
  GoRouter createRouter(WidgetRef ref) {
    throw UnsupportedError('createRouter should not be called in tests');
  }

  @override
  void setTabCloseConfirmationEnabled(bool enabled) {}
}

import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_web/core/navigation/web_router.dart';

void main() {
  setUpAll(() {
    AppConfig.instance = AppConfig(
      environment: Environment.development,
      apiUrl: 'https://api.totem.org/',
      liveKitUrl: 'https://livekit.totem.org/',
      maxPinAttempts: 5,
      vapidKey: null,
      analyticsEnabled: false,
      sentryDsn: null,
      posthogApiKey: null,
      posthogHost: 'https://us.i.posthog.com',
      privacyPolicyUrl: Uri.parse('https://totem.org/privacy/'),
      termsOfServiceUrl: Uri.parse('https://totem.org/tos/'),
      communityGuidelinesUrl: Uri.parse('https://totem.org/guidelines/'),
    );
  });

  test('buildHomeUrl returns correct URLs', () {
    final router = WebTotemRouter();
    expect(router.buildHomeUrl(HomeRoutes.home), 'https://api.totem.org/');
    expect(
      router.buildHomeUrl(HomeRoutes.spaces),
      'https://api.totem.org/spaces/',
    );
    expect(router.buildHomeUrl(HomeRoutes.blog), 'https://api.totem.org/blog/');
    expect(
      router.buildHomeUrl(HomeRoutes.profile),
      'https://api.totem.org/users/profile/',
    );
  });
}

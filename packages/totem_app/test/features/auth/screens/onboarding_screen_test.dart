import 'package:checks/checks.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/auth/controllers/user_profile_controller.dart';
import 'package:totem_app/features/auth/screens/onboarding_screen.dart';
import 'package:totem_core/shared/router.dart';

import 'auth_screen_test_support.dart';

void main() {
  setUp(configureAuthScreenTests);

  testWidgets('completes welcome onboarding from the sign-in action', (
    tester,
  ) async {
    final profile = TestUserProfileController();
    final router = await pumpAuthScreen(
      tester,
      screen: const OnboardingScreen(),
      initialPath: RouteNames.onboarding,
      overrides: [userProfileControllerProvider.overrideWith(() => profile)],
    );

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    check(profile.markWelcomeCalls).equals(1);
    check(router.state.uri.path).equals(RouteNames.login);
    await disposeAuthScreenTest(tester, router);
  });

  testWidgets('does not navigate when welcome onboarding completion fails', (
    tester,
  ) async {
    final profile = TestUserProfileController()
      ..onMarkWelcome = () async => throw StateError('storage failed');
    final router = await pumpAuthScreen(
      tester,
      screen: const OnboardingScreen(),
      initialPath: RouteNames.onboarding,
      overrides: [userProfileControllerProvider.overrideWith(() => profile)],
    );

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    check(profile.markWelcomeCalls).equals(1);
    check(router.state.uri.path).equals(RouteNames.onboarding);
    check(tester.takeException()).isNull();
    await disposeAuthScreenTest(tester, router);
  });
}

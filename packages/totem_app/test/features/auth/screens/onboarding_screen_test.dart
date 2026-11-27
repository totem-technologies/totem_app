import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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

  for (final size in const [
    Size(320, 568),
    Size(360, 800),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
    Size(768, 1024),
    Size(844, 390),
  ]) {
    testWidgets(
      'on a middle page the back and forward buttons are the same 54x54 size '
      'at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final profile = TestUserProfileController();
        final router = await pumpAuthScreen(
          tester,
          screen: const OnboardingScreen(),
          initialPath: RouteNames.onboarding,
          overrides: [userProfileControllerProvider.overrideWith(() => profile)],
        );

        await tester.tap(find.bySemanticsLabel('Next page'));
        await tester.pumpAndSettle();

        check(tester.takeException()).isNull();
        final previous = tester.getSize(find.bySemanticsLabel('Previous page'));
        final next = tester.getSize(find.bySemanticsLabel('Next page'));
        check(previous).equals(const Size(54, 54));
        check(next).equals(previous);

        await disposeAuthScreenTest(tester, router);
      },
    );
  }
}

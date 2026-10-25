import 'dart:async';

import 'package:checks/checks.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/controllers/user_profile_controller.dart';
import 'package:totem_app/features/auth/screens/profile_setup_screen.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/shared/router.dart';

import 'auth_screen_test_support.dart';

void main() {
  setUp(configureAuthScreenTests);

  testWidgets('validates required profile fields before submission', (
    tester,
  ) async {
    final profile = TestUserProfileController();
    final router = await _pumpProfile(tester, profile);

    await _openProfileTab(tester);
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pump();

    check(profile.completeOnboardingCalls).equals(0);
    check(
      tester.widgetList(find.text('Please enter your age')),
    ).length.equals(1);
    await disposeAuthScreenTest(tester, router);
  });

  testWidgets('prevents duplicate profile submissions while saving', (
    tester,
  ) async {
    final completion = Completer<void>();
    final profile = TestUserProfileController()
      ..onCompleteOnboarding = () => completion.future;
    final router = await _pumpProfile(tester, profile);

    await _openProfileTab(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Alex');
    await tester.enterText(find.byType(TextFormField).at(1), '29');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pump();

    check(profile.completeOnboardingCalls).equals(1);
    check(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Continue'),
          )
          .onPressed,
    ).isNull();

    completion.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    check(tester.widgetList(find.text('Topics'))).length.equals(1);
    await disposeAuthScreenTest(tester, router);
  });

  testWidgets('keeps the profile form usable after submission failure', (
    tester,
  ) async {
    final profile = TestUserProfileController()
      ..onCompleteOnboarding = () async => throw StateError('save failed');
    final router = await _pumpProfile(tester, profile);

    await _openProfileTab(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Alex');
    await tester.enterText(find.byType(TextFormField).at(1), '29');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pump();
    await tester.pump();

    check(profile.completeOnboardingCalls).equals(1);
    check(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Continue'),
          )
          .onPressed,
    ).isNotNull();
    check(router.state.uri.path).equals(RouteNames.onboarding);
    await disposeAuthScreenTest(tester, router);
  });
}

Future<GoRouter> _pumpProfile(
  WidgetTester tester,
  TestUserProfileController profile,
) {
  return pumpAuthScreen(
    tester,
    screen: const ProfileSetupScreen(),
    initialPath: RouteNames.onboarding,
    overrides: [
      authControllerProvider.overrideWith(() => TestMobileAuthController()),
      mobileAuthControllerProvider.overrideWith(
        (ref) => TestMobileAuthController(),
      ),
      userProfileControllerProvider.overrideWith(() => profile),
    ],
  );
}

Future<void> _openProfileTab(WidgetTester tester) async {
  await tester.tap(find.text('Agree and Continue'));
  await tester.pumpAndSettle();
}

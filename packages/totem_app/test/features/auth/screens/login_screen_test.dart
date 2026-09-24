import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/screens/login_screen.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';

import 'package:totem_core/shared/router.dart';

import 'auth_screen_test_support.dart';

void main() {
  setUp(configureAuthScreenTests);

  testWidgets('rejects invalid email without requesting a PIN', (tester) async {
    final auth = TestMobileAuthController();
    final router = await pumpAuthScreen(
      tester,
      screen: const LoginScreen(),
      initialPath: RouteNames.login,
      overrides: [
        authControllerProvider.overrideWith(() => TestMobileAuthController()),
        mobileAuthControllerProvider.overrideWith((ref) => auth),
      ],
    );

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    check(auth.requestPinCalls).equals(0);
    check(
      tester.widgetList(find.text('Please enter your email')),
    ).length.equals(1);
    await disposeAuthScreenTest(tester, router);
  });

  testWidgets('prevents duplicate PIN requests while the first is pending', (
    tester,
  ) async {
    final request = Completer<void>();
    final auth = TestMobileAuthController()
      ..onRequestPin = (_) => request.future;
    final router = await pumpAuthScreen(
      tester,
      screen: const LoginScreen(),
      initialPath: RouteNames.login,
      overrides: [
        authControllerProvider.overrideWith(() => TestMobileAuthController()),
        mobileAuthControllerProvider.overrideWith((ref) => auth),
      ],
    );

    await tester.enterText(find.byType(TextFormField), 'person@example.com');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    check(auth.requestPinCalls).equals(1);
    check(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
    ).isNull();

    request.complete();
    await tester.pump();
    await tester.pump();
    check(router.state.uri.path).equals(RouteNames.pinEntry);
    await disposeAuthScreenTest(tester, router);
  });

  testWidgets('recovers from a failed PIN request and allows retry', (
    tester,
  ) async {
    final auth = TestMobileAuthController()
      ..onRequestPin = (_) async => throw StateError('request failed');
    final router = await pumpAuthScreen(
      tester,
      screen: const LoginScreen(),
      initialPath: RouteNames.login,
      overrides: [
        authControllerProvider.overrideWith(() => TestMobileAuthController()),
        mobileAuthControllerProvider.overrideWith((ref) => auth),
      ],
    );

    await tester.enterText(find.byType(TextFormField), 'person@example.com');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump();

    check(auth.requestPinCalls).equals(1);
    check(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
    ).isNotNull();
    check(router.state.uri.path).equals(RouteNames.login);
    await disposeAuthScreenTest(tester, router);
  });
}

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/screens/pin_entry_screen.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/shared/router.dart';
import 'package:pinput/pinput.dart';

import 'auth_screen_test_support.dart';

void main() {
  setUp(configureAuthScreenTests);

  testWidgets('rejects an incomplete PIN without verifying', (tester) async {
    final auth = TestMobileAuthController();
    final router = await pumpAuthScreen(
      tester,
      screen: const PinEntryScreen(email: 'person@example.com'),
      initialPath: RouteNames.pinEntry,
      overrides: [
        authControllerProvider.overrideWith(() => TestMobileAuthController()),
        mobileAuthControllerProvider.overrideWith((ref) => auth),
      ],
    );

    await tester.enterText(find.byType(Pinput), '123');
    await tester.tap(find.text('Verify Code'));
    await tester.pump();

    check(auth.verifyPinCalls).equals(0);

    await disposeAuthScreenTest(tester, router);
  });

  testWidgets(
    'prevents duplicate verification while the first attempt is pending',
    (tester) async {
      final verification = Completer<void>();
      final auth = TestMobileAuthController()
        ..onVerifyPin = (_) => verification.future;
      final router = await pumpAuthScreen(
        tester,
        screen: const PinEntryScreen(email: 'person@example.com'),
        initialPath: RouteNames.pinEntry,
        overrides: [
          authControllerProvider.overrideWith(() => TestMobileAuthController()),
          mobileAuthControllerProvider.overrideWith((ref) => auth),
        ],
      );

      await tester.enterText(find.byType(Pinput), '123456');
      await tester.pump();
      check(auth.verifyPinCalls).equals(1);
      check(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      ).isNull();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      check(auth.verifyPinCalls).equals(1);

      verification.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      check(router.state.uri.path).equals('/');
      await disposeAuthScreenTest(tester, router);
    },
  );

  testWidgets('shows a failed verification as a retryable attempt', (
    tester,
  ) async {
    final auth = TestMobileAuthController()
      ..onVerifyPin = (_) async => throw StateError('invalid');
    final router = await pumpAuthScreen(
      tester,
      screen: const PinEntryScreen(email: 'person@example.com'),
      initialPath: RouteNames.pinEntry,
      overrides: [
        authControllerProvider.overrideWith(() => TestMobileAuthController()),
        mobileAuthControllerProvider.overrideWith((ref) => auth),
      ],
    );

    await tester.enterText(find.byType(Pinput), '123456');
    await tester.pump();
    await tester.pump();

    check(auth.verifyPinCalls).equals(1);
    check(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
    ).isNotNull();
    check(
      tester.widgetList(find.textContaining('Attempts: 1 of 3')),
    ).length.equals(1);
    await disposeAuthScreenTest(tester, router);
  });
}

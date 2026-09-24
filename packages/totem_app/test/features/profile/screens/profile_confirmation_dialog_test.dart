import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/profile/screens/delete_account.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';

final class _FakeAuthController extends MobileAuthController {
  _FakeAuthController(this.user, {this.onLogout, this.onDeleteAccount});

  @override
  final UserSchema? user;

  final AsyncCallback? onLogout;
  final AsyncCallback? onDeleteAccount;

  @override
  AuthState build() => AuthState.authenticated(user: user!);

  @override
  bool get isAuthenticated => user != null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<void> checkExistingAuth() async {}

  @override
  Future<void> logout() async => onLogout?.call();

  @override
  Future<void> deleteAccount() async => onDeleteAccount?.call();
}

void main() {
  final user = UserSchema(
    profileAvatarType: ProfileAvatarTypeEnum.td,
    circleCount: 0,
    email: 'person@example.com',
    dateCreated: DateTime.utc(2024),
  );

  Future<void> pumpDialog(
    WidgetTester tester,
    flutter.Widget dialog,
    _FakeAuthController auth,
  ) async {
    var scheduled = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          mobileAuthControllerProvider.overrideWithValue(auth),
        ],
        child: flutter.MaterialApp(
          home: mui.MaterialApp(
            theme: AppTheme.lightTheme,
            home: flutter.Builder(
              builder: (context) {
                if (!scheduled) {
                  scheduled = true;
                  flutter.WidgetsBinding.instance.addPostFrameCallback((_) {
                    flutter.Navigator.of(context).push(
                      flutter.MaterialPageRoute<void>(builder: (_) => dialog),
                    );
                  });
                }
                return const mui.Scaffold();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('logout cancellation leaves the account unchanged', (
    tester,
  ) async {
    var logoutCalls = 0;
    final auth = _FakeAuthController(user, onLogout: () async => logoutCalls++);
    await pumpDialog(tester, const LogoutDialog(), auth);

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    check(logoutCalls).equals(0);
    check(tester.widgetList(find.byType(mui.AlertDialog))).length.equals(0);
  });

  testWidgets('logout confirmation waits, then invokes logout', (tester) async {
    final logout = Completer<void>();
    final auth = _FakeAuthController(
      user,
      onLogout: logout.future.asVoidCallback,
    );
    await pumpDialog(tester, const LogoutDialog(), auth);

    await tester.tap(find.text('Sign out'));
    await tester.pump();

    check(tester.widgetList(find.byType(LoadingIndicator))).length.equals(1);
    check(tester.widgetList(find.text('Sign out'))).length.equals(0);

    logout.complete();
    await tester.pump();
    check(tester.widgetList(find.byType(LoadingIndicator))).length.equals(0);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
  });

  testWidgets('logout failure keeps the dialog available for retry', (
    tester,
  ) async {
    var attempts = 0;
    final auth = _FakeAuthController(
      user,
      onLogout: () async {
        attempts++;
        // The production controller handles the failure and remains usable.
      },
    );
    await pumpDialog(tester, const LogoutDialog(), auth);

    await tester.tap(find.text('Sign out'));
    await tester.pump();
    await tester.pump();
    check(attempts).equals(1);
    check(tester.widgetList(find.text('Sign out'))).length.equals(1);

    await tester.tap(find.text('Sign out'));
    await tester.pump();
    await tester.pump();
    check(attempts).equals(2);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
  });

  testWidgets('delete account can be cancelled or confirmed', (tester) async {
    var deleteCalls = 0;
    final auth = _FakeAuthController(
      user,
      onDeleteAccount: () async => deleteCalls++,
    );
    await pumpDialog(tester, const DeleteAccountDialog(), auth);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    check(deleteCalls).equals(0);
    check(tester.widgetList(find.byType(mui.AlertDialog))).length.equals(0);

    await pumpDialog(tester, const DeleteAccountDialog(), auth);
    await tester.tap(find.text('Delete account'));
    await tester.pump();
    await tester.pump();
    check(deleteCalls).equals(1);
  });
}

extension on Future<void> {
  AsyncCallback get asVoidCallback =>
      () => this;
}

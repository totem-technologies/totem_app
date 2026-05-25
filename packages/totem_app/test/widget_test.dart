import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/main.dart' as app;
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/models/user_schema.dart';
import 'package:totem_core/shared/router.dart';

import '../../totem_core/test/setup.dart';

void main() {
  setUpAll(() async {
    setupAppConfig();
    await setupFirebase();
    TotemRouter.instance = AppTotemRouter();
  });

  testWidgets('App builds smoke test', (tester) async {
    final fakeController = _FakeMobileAuthController(
      const AuthState(status: AuthStatus.unauthenticated),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => fakeController),
          mobileAuthControllerProvider.overrideWith((ref) => fakeController),
        ],
        child: app.TotemApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(app.TotemApp), findsOneWidget);
  });
}

class _FakeMobileAuthController extends MobileAuthController {
  _FakeMobileAuthController(this.fakeState);

  final AuthState fakeState;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  @override
  AuthState build() {
    ref.onDispose(() async {
      await _controller.close();
    });
    _controller.add(fakeState);
    return fakeState;
  }

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  bool get isAuthenticated => fakeState.status == AuthStatus.authenticated;

  @override
  UserSchema? get user => fakeState.user;

  @override
  bool get isOnboardingCompleted => false;

  @override
  Future<bool> get hasSeenWelcomeOnboarding async => false;

  @override
  Future<void> checkExistingAuth() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> logout() async {}
}

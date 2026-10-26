import 'dart:async';

import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/models/user_schema.dart';

class FakeAuthController extends AuthController {
  FakeAuthController(this.fakeState);

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
  Future<void> checkExistingAuth() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  bool get isAuthenticated => fakeState.status == AuthStatus.authenticated;

  @override
  Future<void> logout() async {}

  @override
  UserSchema? get user => fakeState.user;
}

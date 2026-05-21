import 'dart:async';

import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/auth/repositories/auth_repository.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:web/web.dart' as web;

class WebAuthController extends AuthController {
  final _authStateController = StreamController<AuthState>.broadcast();
  Completer<void>? _checkExistingAuthCompleter;

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    ref.onDispose(() async {
      await _authStateController.close();
    });

    unawaited(checkExistingAuth());
    return AuthState.initial();
  }

  @override
  bool get isAuthenticated {
    return state.status == AuthStatus.authenticated || _hasSessionCookie();
  }

  @override
  UserSchema? get user => state.user;

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  @override
  Future<void> checkExistingAuth() async {
    if (_checkExistingAuthCompleter == null) {
      _checkExistingAuthCompleter = Completer<void>();

      try {
        _setState(AuthState.loading());
        final currentUser = await _authRepository.currentUser;
        _setState(AuthState.authenticated(user: currentUser));
        _checkExistingAuthCompleter?.complete();
      } catch (_) {
        _setState(AuthState.unauthenticated());
        _checkExistingAuthCompleter?.complete();
      } finally {
        _checkExistingAuthCompleter = null;
      }
    } else {
      await _checkExistingAuthCompleter!.future;
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _authRepository.deleteAccount();
    } finally {
      _setState(AuthState.unauthenticated());
    }
  }

  @override
  Future<void> logout() async {
    _setState(AuthState.unauthenticated());
  }

  bool _hasSessionCookie() {
    return readCookieValue('sessionid')?.isNotEmpty ?? false;
  }

  static String? readCookieValue(String cookieName) {
    final cookie = web.document.cookie;
    if (cookie.isEmpty) {
      return null;
    }

    for (final part in cookie.split(';')) {
      final trimmed = part.trim();
      if (trimmed.startsWith('$cookieName=')) {
        return Uri.decodeComponent(trimmed.substring(cookieName.length + 1));
      }
    }

    return null;
  }

  void _setState(AuthState newState) {
    state = newState;
    _authStateController.add(state);
  }
}

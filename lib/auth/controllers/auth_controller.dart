import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/auth/repositories/auth_repository.dart';
import 'package:totem_app/core/config/consts.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/services/analytics_service.dart';
import 'package:totem_app/core/services/notifications_service.dart';
import 'package:totem_app/core/services/secure_storage.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    secureStorage: ref.watch(secureStorageProvider),
  ),
);

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthRepository authRepository,
    required SecureStorage secureStorage,
  }) : _authRepository = authRepository,
       _secureStorage = secureStorage,
       super(AuthState.unauthenticated()) {
    _checkExistingAuth();

    FirebaseMessaging.instance.onTokenRefresh
        .listen((_) => _updateFCMToken)
        .onError((err) {});
  }
  final AuthRepository _authRepository;
  final SecureStorage _secureStorage;
  final _authStateController = StreamController<AuthState>.broadcast();

  Stream<AuthState> get authStateChanges => _authStateController.stream;

  bool get isAuthenticated => state.status == AuthStatus.authenticated;
  bool get isOnboardingCompleted => state.status == AuthStatus.authenticated
  // TODO(bdlukaa): Uncomment this when profile endpoints are available
  // &&
  // (state.user?.name != null && state.user!.name!.isNotEmpty == true)
  ;

  Future<void> requestPin(String email, bool newsletterConsent) async {
    try {
      state = AuthState.loading();
      _emitState();
      await _authRepository.requestPin(email, newsletterConsent);
      state = AuthState.awaitingVerification(email: email);
      _emitState();

      AnalyticsService.instance.logEvent(
        'pin_requested',
        parameters: {'email': email, 'newsletterConsent': newsletterConsent},
      );
    } catch (e) {
      state = AuthState.error(e.toString());
      _emitState();
      rethrow;
    }
  }

  /// Verify a magic link token
  Future<void> verifyPin(String pin) async {
    assert(
      state.status == AuthStatus.awaitingVerification,
      'verifyPin() should only be called when status is '
      'AuthStatus.awaitingVerification',
    );
    assert(
      state.email != null,
      'verifyPin() should only be called when email is not null',
    );
    try {
      final email = state.email!;
      state = AuthState.loading();
      _emitState();

      final authResponse = await _authRepository.verifyPin(email, pin);
      await _secureStorage.write(
        key: AppConsts.jwtToken,
        value: authResponse.refreshToken,
      );
      await _secureStorage.write(
        key: AppConsts.accessToken,
        value: authResponse.accessToken,
      );

      final user = await _authRepository.currentUser;

      state = AuthState.authenticated(user: user);
      _emitState();

      AnalyticsService.instance.setUserId(user.email);
      AnalyticsService.instance.logLogin(method: 'pin');
    } catch (e, s) {
      if (e is AppAuthException && e.code == 'INVALID_PIN') {
        state = AuthState.error('Invalid PIN code. Please try again.');
      } else if (e is AppAuthException && e.code == 'PIN_ATTEMPTS_EXCEEDED') {
        state = AuthState.error(
          'Too many failed attempts. Please request a new magic link.',
        );
      } else {
        state = AuthState.error('Authentication failed: $e: $s');
      }
      _emitState();
      rethrow;
    }
  }

  Future<void> completeOnboarding({
    required String firstName,
    String? profileImagePath,
  }) async {
    try {
      if (!isAuthenticated) {
        throw AppAuthException.unauthenticated();
      }

      // state = state.copyWith(status: AuthStatus.loading);
      // _emitState();

      // Update profile with backend
      // final updatedUser = await _authRepository.updateProfile(
      //   userId: state.user!.id,
      //   firstName: firstName,
      //   profileImagePath: profileImagePath,
      // );

      // Update state with completed onboarding flag
      // state = AuthState.authenticated(user: updatedUser);
      // _emitState();

      AnalyticsService.instance.logEvent('onboarding_completed');
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        error: 'Failed to update profile: $e',
      );
      _emitState();
      rethrow;
    }
  }

  /// Log out the current user
  Future<void> logout() async {
    try {
      if (!isAuthenticated) return;

      state = AuthState.loading();
      _emitState();

      final jwtToken = await _secureStorage.read(key: AppConsts.jwtToken);
      if (jwtToken != null) await _authRepository.logout(jwtToken);
      await _secureStorage.delete(key: AppConsts.jwtToken);
      await _secureStorage.delete(key: AppConsts.accessToken);

      state = AuthState.unauthenticated();
      _emitState();

      AnalyticsService.instance.logEvent('user_logged_out');
      AnalyticsService.instance.setUserId(null);
    } catch (error, stack) {
      await _secureStorage.delete(key: AppConsts.jwtToken);
      await _secureStorage.delete(key: AppConsts.accessToken);
      state = AuthState.unauthenticated();
      _emitState();
      debugPrint('Error during logout: $error, $stack');
    }
  }

  Future<void> _checkExistingAuth() async {
    try {
      state = AuthState.loading();
      _emitState();

      final accessToken = await _secureStorage.read(key: AppConsts.accessToken);

      if (accessToken == null) {
        state = AuthState.unauthenticated();
        _emitState();
        return;
      }

      // TODO(bdlukaa): User profile should be stored in secure storage and
      //                retrieved here instead of making a network call for
      //                every app launch.
      final user = await _authRepository.currentUser;
      state = AuthState.authenticated(user: user);
      _emitState();

      AnalyticsService.instance.setUserId(user.email);
    } catch (e, stack) {
      await _secureStorage.delete(key: AppConsts.jwtToken);
      state = AuthState.unauthenticated();

      debugPrint('Error checking existing auth: $e $stack');
    } finally {
      _emitState();
    }
  }

  void _emitState() {
    _authStateController.add(state);

    if (state.status == AuthStatus.authenticated) {
      _updateFCMToken();
    }
  }

  Future<void> _updateFCMToken() async {
    if (!isAuthenticated) return;

    final fcmToken = await NotificationsService.instance.fcmToken;
    if (fcmToken == null) return;

    return _authRepository.updateFcmToken(fcmToken);
  }

  @override
  void dispose() {
    _authStateController.close();
    super.dispose();
  }
}

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

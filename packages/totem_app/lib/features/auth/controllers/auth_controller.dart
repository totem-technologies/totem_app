import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/features/auth/services/firebase_messaging_service.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/auth/repositories/auth_repository.dart';
import 'package:totem_core/auth/repositories/user_profile_repository.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/consts.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/analytics_service.dart';
import 'package:totem_core/core/services/cache_service.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/core/services/local_storage_service.dart';
import 'package:totem_core/core/services/secure_storage.dart';
import 'package:totem_core/shared/logger.dart';

part 'auth_controller.g.dart';

@riverpod
MobileAuthController mobileAuthController(Ref ref) {
  return ref.read(authControllerProvider.notifier) as MobileAuthController;
}

class MobileAuthController extends AuthController {
  MobileAuthController();

  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  UserRepository get _userRepository => ref.read(userRepositoryProvider);
  SecureStorage get _secureStorage => ref.read(secureStorageProvider);
  AnalyticsService get _analyticsService => ref.read(analyticsProvider);
  FirebaseMessagingService get _messagingService =>
      ref.read(firebaseMessagingServiceProvider);

  final _authStateController = StreamController<AuthState>.broadcast();
  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;
  int _sessionGeneration = 0;
  bool _endingSession = false;
  bool _disposed = false;

  @override
  AuthState build() {
    final messagingService = _messagingService;
    ref.onDispose(() async {
      _disposed = true;
      _sessionGeneration++;
      unawaited(messagingService.detach());
      await _authStateController.close();
    });

    _initialize();
    return AuthState.unauthenticated();
  }

  @override
  bool get isAuthenticated => state.status == AuthStatus.authenticated;

  bool get isAuthStateResolved =>
      state.status != AuthStatus.initial && state.status != AuthStatus.loading;

  bool get isOnboardingCompleted =>
      isAuthenticated &&
      (state.user?.name.value != null &&
          state.user!.name.requireValue!.isNotEmpty);

  @override
  UserSchema? get user => state.user;

  void _initialize() {
    _messagingService.start(isAuthenticated: () => isAuthenticated);
    checkExistingAuth();
  }

  Future<void> requestPin(String email) async {
    _setState(AuthState.loading());
    try {
      await _authRepository.requestPin(email, false);
      _setState(AuthState.awaitingVerification(email: email));
      _analyticsService.logEvent('pin_requested', parameters: {'email': email});
    } catch (error, stackTrace) {
      _handleAuthError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> verifyPin(String pin) async {
    final currentEmail = state.email;
    if (currentEmail == null) {
      _setState(AuthState.error('Something went wrong.'));
      return;
    }

    _setState(AuthState.loading());
    try {
      final authResponse = await _authRepository.verifyPin(currentEmail, pin);
      await _storeTokens(authResponse.accessToken, authResponse.refreshToken);

      final user = await _userRepository.currentUser;
      _setState(AuthState.authenticated(user: user));

      await _analyticsService.setUserId(user);
      _analyticsService.logLogin(method: 'pin');
      _endingSession = false;
      _registerForNotifications();
    } catch (error, stackTrace) {
      _handlePinVerificationError(
        error: error,
        stackTrace: stackTrace,
        email: currentEmail,
      );
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    if (!isAuthenticated || _endingSession) return;
    _endingSession = true;
    _sessionGeneration++;
    _messagingService.beginEndingSession();

    try {
      await _messagingService.unregister();
      final refreshToken = await _secureStorage.read(
        key: AppConsts.refreshTokenKey,
      );
      await _clearTokens();
      if (refreshToken != null) {
        _authRepository.logout(refreshToken);
      }
      _analyticsService.logLogout();
      _setState(AuthState.unauthenticated());
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Logout failed',
      );
      _setState(AuthState.unauthenticated());
      await _clearTokens();
    }
  }

  @override
  Future<void> deleteAccount() async {
    if (!isAuthenticated || _endingSession) return;

    _endingSession = true;
    _sessionGeneration++;
    _messagingService.beginEndingSession();
    await _messagingService.unregister();
    _setState(AuthState.loading());
    try {
      await _userRepository.deleteAccount();
      _setState(AuthState.unauthenticated());
      _analyticsService.logAccountDeleted();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Account deletion failed',
      );
      _setState(AuthState.unauthenticated());
    } finally {
      await _clearTokens();
      await _clearAllLocalStorage();
    }
  }

  Completer<void>? _checkExistingAuthCompleter;

  @override
  Future<void> checkExistingAuth() async {
    if (_checkExistingAuthCompleter == null) {
      _checkExistingAuthCompleter = Completer<void>();

      try {
        await _checkExistingAuth();
        _checkExistingAuthCompleter?.complete();
      } catch (error, stackTrace) {
        _checkExistingAuthCompleter?.completeError(error, stackTrace);
      } finally {
        _checkExistingAuthCompleter = null;
      }
    } else {
      await _checkExistingAuthCompleter!.future;
    }
  }

  var _isCheckingExistingAuth = false;

  Future<void> _checkExistingAuth() async {
    if (_isCheckingExistingAuth) return;
    _isCheckingExistingAuth = true;
    final generation = _sessionGeneration;
    _setState(AuthState.loading());

    try {
      final isOffline = await checkIsOffline(ref.read(connectivityProvider));

      final accessToken = await _secureStorage.read(
        key: AppConsts.accessTokenKey,
      );
      if (_disposed || generation != _sessionGeneration) return;

      if (accessToken == null) {
        logger.i('🔑 No token. Setting unauthenticated.');
        _setState(AuthState.unauthenticated());
        return;
      }

      final cachedUser = await ref.read(localStorageServiceProvider).getUser();
      if (_disposed || generation != _sessionGeneration) return;
      if (cachedUser != null) {
        logger.i('🔑 Using cached user (Optimistic).');
        _setState(AuthState.authenticated(user: cachedUser));
      }

      if (isOffline) {
        if (cachedUser == null) {
          _setState(AuthState.unauthenticated());
        } else {
          _endingSession = false;
          _registerForNotifications();
        }
      } else {
        await _validateTokenOnline(cachedUser, generation);
      }
    } catch (error, stackTrace) {
      if (_disposed || generation != _sessionGeneration) return;
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Check existing auth failed',
      );
      _endingSession = true;
      _messagingService.beginEndingSession();
      await _messagingService.unregister();
      await _clearTokens();
      _setState(AuthState.unauthenticated());
    } finally {
      _isCheckingExistingAuth = false;
    }
  }

  Future<void> _validateTokenOnline(
    UserSchema? cachedUser,
    int generation,
  ) async {
    bool timedOut = false;

    try {
      logger.i('🔑 Validating token with backend...');

      await (() async {
        final user = await _userRepository.currentUser;

        // The timeout does not cancel the operation, so ignore late results.
        if (timedOut || _disposed || generation != _sessionGeneration) return;

        await ref.read(localStorageServiceProvider).saveUser(user);
        if (timedOut || _disposed || generation != _sessionGeneration) return;
        _setState(AuthState.authenticated(user: user));

        _analyticsService.setUserId(user);
        _endingSession = false;
        _registerForNotifications();
      })().timeout(
        AppConsts.tokenValidationTimeout,
        onTimeout: () {
          timedOut = true;
          if (_disposed || generation != _sessionGeneration) return;
          logger.w('🔑 Validation timed out. Staying in current state.');
          // If we have a cached user, we just stay authenticated (Soft Fail).
          // If we don't, we might want to force unauthenticated here.
          if (cachedUser == null) {
            throw AppAuthException.timeout();
          }
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    try {
      await _secureStorage.write(
        key: AppConsts.accessTokenKey,
        value: accessToken,
      );
      await _secureStorage.write(
        key: AppConsts.refreshTokenKey,
        value: refreshToken,
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: '🔑 Failed to store tokens locally',
      );
      throw AppAuthException('Failed to store tokens');
    }
  }

  /// Deletes the user tokens and related user data from local storage.
  Future<void> _clearTokens() async {
    try {
      logger.i('🔑 Clearing stored tokens and user data');
      await _secureStorage.delete(key: AppConsts.accessTokenKey);
      await _secureStorage.delete(key: AppConsts.refreshTokenKey);
      await ref.read(localStorageServiceProvider).clearUser();
      await ref.read(cacheServiceProvider).clearCache();
      // Note: We intentionally don't clear welcome onboarding flag here
      // so returning users don't see welcome screens again unless they
      // reinstall the app.
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: '🔑 Error clearing tokens',
      );
      await _secureStorage.deleteAll();
    }
  }

  Future<void> _clearAllLocalStorage() async {
    await _secureStorage.deleteAll();
  }

  void _handleAuthError(Object error, StackTrace stackTrace) {
    ErrorHandler.logError(error, stackTrace: stackTrace);
    _setState(AuthState.error(error.toString()));
  }

  String _handlePinVerificationError({
    required dynamic error,
    required StackTrace stackTrace,
    required String email,
  }) {
    String errorMessage = 'Authentication failed. Please try again.';
    if (error is AppAuthException) {
      switch (error.code) {
        case 'INVALID_PIN':
          errorMessage = 'Invalid PIN code. Please try again.';
        case 'PIN_ATTEMPTS_EXCEEDED':
          errorMessage = 'Too many failed attempts. Please request a new PIN.';
        default:
          errorMessage = error.message;
      }
    }
    _setState(AuthState.awaitingVerification(email: email));
    ErrorHandler.logError(error, stackTrace: stackTrace, message: errorMessage);
    return errorMessage;
  }

  void _registerForNotifications() {
    if (_disposed || _endingSession) return;
    _messagingService.beginSession();
    _messagingService.register();
  }

  void _setState(AuthState newState) {
    if (_disposed) return;
    state = newState;
    _authStateController.add(state);
  }

  /// Bridge method allowing other controllers to update the user object
  /// without changing the core authentication status.
  void syncUser(UserSchema updatedUser) {
    if (isAuthenticated) {
      _setState(AuthState.authenticated(user: updatedUser));
    }
  }
}

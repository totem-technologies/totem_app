//
// ignore_for_file: avoid_public_notifier_properties
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/auth/repositories/auth_repository.dart';
import 'package:totem_app/core/config/consts.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/analytics_service.dart';
import 'package:totem_app/core/services/cache_service.dart';
import 'package:totem_app/core/services/local_storage_service.dart';
import 'package:totem_app/core/services/notifications_service.dart';
import 'package:totem_app/core/services/secure_storage.dart';
import 'package:totem_app/shared/logger.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
  name: 'Auth Controller Provider',
);

class AuthController extends Notifier<AuthState> {
  AuthController();

  late final AuthRepository _authRepository;
  late final SecureStorage _secureStorage;
  late final AnalyticsService _analyticsService;
  late final NotificationsService _notificationsService;

  final _authStateController = StreamController<AuthState>.broadcast();
  Stream<AuthState> get authStateChanges => _authStateController.stream;
  StreamSubscription<String>? _fcmTokenSubscription;

  @override
  AuthState build() {
    _authRepository = ref.watch(authRepositoryProvider);
    _secureStorage = ref.watch(secureStorageProvider);
    _analyticsService = ref.watch(analyticsProvider);
    _notificationsService = ref.watch(notificationsProvider);

    ref.onDispose(() async {
      await _fcmTokenSubscription?.cancel();
      _fcmTokenSubscription = null;
      await _authStateController.close();
    });

    _initialize();
    return AuthState.unauthenticated();
  }

  bool get isAuthenticated => state.status == AuthStatus.authenticated;
  bool get isOnboardingCompleted =>
      isAuthenticated &&
      (state.user?.name != null && state.user!.name!.isNotEmpty);

  UserSchema? get user => state.user;

  /// Check if the user has seen the welcome onboarding screens before
  /// This determines if they should see the intro screens on app launch
  Future<bool> get hasSeenWelcomeOnboarding async {
    return ref.read(localStorageServiceProvider).hasSeenWelcomeOnboarding();
  }

  /// Mark that the user has completed the welcome onboarding screens
  /// Called when user finishes the intro screens or skips them
  Future<void> markWelcomeOnboardingCompleted() async {
    await ref
        .read(localStorageServiceProvider)
        .markWelcomeOnboardingCompleted();
    _analyticsService.logEvent('welcome_onboarding_completed');
  }

  void _initialize() {
    unawaited(checkExistingAuth());
    _fcmTokenSubscription ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (_) => _updateFCMToken(),
      onError: (dynamic error, StackTrace stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          reason: 'FCM token refresh failed',
        );
      },
    );
  }

  Future<void> requestPin(String email, bool newsletterConsent) async {
    _setState(AuthState.loading());
    try {
      await _authRepository.requestPin(email, newsletterConsent);
      _setState(AuthState.awaitingVerification(email: email));
      _analyticsService.logEvent(
        'pin_requested',
        parameters: {'email': email, 'newsletterConsent': newsletterConsent},
      );
    } catch (error, stackTrace) {
      _handleAuthError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> verifyPin(String pin) async {
    final currentEmail = state.email;
    if (currentEmail == null) {
      // This should ideally not happen if UI flow is correct
      // _setState(AuthState.error('Invalid state for PIN verification.'));
      _setState(AuthState.error('Something went wrong.'));
      return;
    }

    _setState(AuthState.loading());
    try {
      final authResponse = await _authRepository.verifyPin(currentEmail, pin);
      await _storeTokens(authResponse.accessToken, authResponse.refreshToken);

      final user = await _authRepository.currentUser;
      _setState(AuthState.authenticated(user: user));

      await _analyticsService.setUserId(user);
      _analyticsService.logLogin(method: 'pin');
      await _updateFCMToken();
    } catch (error, stackTrace) {
      _handlePinVerificationError(
        error: error,
        stackTrace: stackTrace,
        email: currentEmail,
      );

      rethrow;
    }
  }

  Future<void> completeOnboarding({
    required String firstName,
    required int? age,
    required ReferralChoices? referralSource,
    required Set<String> interestTopics,
  }) async {
    if (!isAuthenticated || state.user == null) {
      _setState(AuthState.error('User not authenticated for onboarding.'));
      // Potentially throw AppAuthException.unauthenticated();
      return;
    }

    // _setState(state.copyWith(status: AuthStatus.loading)); // Optional: if there's a noticeable delay

    try {
      final updatedUser = await _authRepository.updateCurrentUserProfile(
        name: firstName,
      );

      unawaited(
        _authRepository
            .completeOnboarding(
              interestTopics: interestTopics,
              referralSource: referralSource,
              yearBorn: age == null ? null : (DateTime.now().year - age),
            )
            .then((_) {
              logger.i('🔑 Onboard completed!');
            }),
      );

      _setState(AuthState.authenticated(user: updatedUser));

      if (referralSource != null) {
        _analyticsService.logEvent(
          'referral_source',
          parameters: {
            'source': referralSource,
            'user_type': 'new_user',
            'signup_flow_step': 3,
          },
        );
      }

      _analyticsService.logEvent('onboarding_completed');
    } catch (error, stackTrace) {
      _setState(
        state.copyWith(
          status: AuthStatus.authenticated,
          error: 'Failed to update profile: $error',
        ),
      );
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: '🔑 Failed to complete onboarding',
      );
      rethrow;
    }
  }

  Future<bool> updateUserProfile({
    String? name,
    String? email,
    File? profileImage,
    ProfileAvatarTypeEnum? profileAvatarType,
    String? avatarSeed,
  }) async {
    assert(
      isAuthenticated,
      'Cannot update profile when user is not authenticated.',
    );

    assert(
      profileImage != null ||
          avatarSeed != null ||
          profileAvatarType != null ||
          name != null ||
          email != null,
      'At least one profile field must be provided for update.',
    );

    var overallSuccess = true;
    var finalUpdatedUser = state.user;

    if (profileImage != null) {
      try {
        final bool imageUpdateSuccess = await _authRepository
            .updateCurrentUserProfilePicture(profileImage);
        if (!imageUpdateSuccess) {
          overallSuccess = false;
        } else {
          // If image update was successful and you need to refresh user data
          // to get new image URL
          // you might need to call _authRepository.currentUser again or the
          // image update method should return the new UserSchema or at least
          // the new image URL. For simplicity, if it returns a new UserSchema:
          // finalUser = await _authRepository.currentUser;
        }
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          reason: 'Failed to update profile image',
        );
        overallSuccess = false;
      }
    }

    var shouldUpdateMetaProfile = false;
    final newName = (name != null && state.user?.name != name) ? name : null;
    final newEmail = (email != null && state.user?.email != email)
        ? email
        : null;
    final newProfileAvatarType =
        (profileAvatarType != null &&
            state.user?.profileAvatarType != profileAvatarType)
        ? profileAvatarType
        : null;
    final newAvatarSeed =
        (avatarSeed != null && state.user?.profileAvatarSeed != avatarSeed)
        ? avatarSeed
        : null;

    if (newName != null ||
        newEmail != null ||
        newProfileAvatarType != null ||
        newAvatarSeed != null) {
      shouldUpdateMetaProfile = true;
    }

    if (shouldUpdateMetaProfile) {
      try {
        final backendUpdatedUser = await _authRepository
            .updateCurrentUserProfile(
              name: newName,
              email: newEmail,
              profileAvatarType: profileAvatarType,
              avatarSeed: avatarSeed,
            );
        finalUpdatedUser = backendUpdatedUser;
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          reason: 'Failed to update name/email',
        );
        overallSuccess = false;
      }
    }

    if (overallSuccess &&
        finalUpdatedUser != null &&
        finalUpdatedUser != state.user) {
      _setState(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: finalUpdatedUser,
        ),
      );
    } else if (overallSuccess &&
        (profileImage != null || shouldUpdateMetaProfile)) {
      // If an update was attempted and reported success by the repo,
      // but we don't have a new user object from the repo calls,
      // it might be safest to re-fetch the user to ensure UI consistency.
      try {
        final refreshedUser = await _authRepository.currentUser;
        _setState(
          state.copyWith(status: AuthStatus.authenticated, user: refreshedUser),
        );
      } catch (e) {
        overallSuccess = false;
        ErrorHandler.logError(
          e,
          reason: 'Failed to refresh user after profile update',
        );
      }
    }

    return overallSuccess;
  }

  Future<void> logout() async {
    if (!isAuthenticated) return;

    // _setState(AuthState.loading());
    try {
      final refreshToken = await _secureStorage.read(
        key: AppConsts.refreshTokenKey,
      );
      await _clearTokens();
      if (refreshToken != null) {
        unawaited(_authRepository.logout(refreshToken));
      }
      unawaited(_analyticsService.logLogout());
      _setState(AuthState.unauthenticated());
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        reason: 'Logout failed',
      );
      _setState(AuthState.unauthenticated());
      await _clearTokens();
    }
  }

  Future<void> deleteAccount() async {
    if (!isAuthenticated) return;

    _setState(AuthState.loading());
    try {
      await _authRepository.deleteAccount();
      _setState(AuthState.unauthenticated());
      Sentry.configureScope((scope) => scope.setUser(null));
      _analyticsService.logEvent('account_deleted');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        reason: 'Account deletion failed',
      );
      _setState(AuthState.unauthenticated());
    } finally {
      await _clearTokens();
      await _clearAllLocalStorage();
    }
  }

  Completer<void>? _checkExistingAuthCompleter;
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

  /// Checks for existing authentication tokens and validates them.
  ///
  /// If valid, updates the auth state to authenticated.
  ///
  /// If the user is offline, relies on cached user data if available.
  /// If no valid tokens or cached data, sets state to unauthenticated.
  ///
  /// If the user is online, attempts to validate or refresh the token with the
  /// backend. Token refresh happens automatically in a middleware in the
  /// repository layer if needed.
  ///
  /// Prevents concurrent executions using [_isCheckingExistingAuth] flag.
  var _isCheckingExistingAuth = false;
  Future<void> _checkExistingAuth() async {
    if (_isCheckingExistingAuth) return;
    _isCheckingExistingAuth = true;
    _setState(AuthState.loading());

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult.contains(ConnectivityResult.none);

      final accessToken = await _secureStorage.read(
        key: AppConsts.accessTokenKey,
      );

      if (accessToken == null) {
        logger.i('🔑 No token. Setting unauthenticated.');
        _setState(AuthState.unauthenticated());
        return;
      }

      final cachedUser = await ref.read(localStorageServiceProvider).getUser();
      if (cachedUser != null) {
        logger.i('🔑 Using cached user (Optimistic).');
        _setState(AuthState.authenticated(user: cachedUser));
      }

      if (isOffline) {
        if (cachedUser == null) _setState(AuthState.unauthenticated());
      } else {
        await _validateTokenOnline(cachedUser);
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        reason: 'Auth Check Failed',
      );
      await _clearTokens();
      _setState(AuthState.unauthenticated());
    } finally {
      _isCheckingExistingAuth = false;
    }
  }

  Future<void> _validateTokenOnline(UserSchema? cachedUser) async {
    bool timedOut = false;

    try {
      logger.i('🔑 Validating token with backend...');

      await (() async {
        final user = await _authRepository.currentUser;

        // If we timed out while waiting for this, DO NOT update state to avoid
        // overwriting with potentially stale data.
        //
        // This is necessary because time [timout] helper doesn't cancel the
        // operation.
        if (timedOut) return;

        await ref.read(localStorageServiceProvider).saveUser(user);
        _setState(AuthState.authenticated(user: user));

        unawaited(_analyticsService.setUserId(user));
        await _updateFCMToken();
      })().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          timedOut = true;
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
        reason: '🔑 Failed to store tokens',
      );
      // Optionally rethrow or handle the error as needed
      throw const AppAuthException('Failed to store tokens');
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

    try {
      final token = await ref.read(notificationsProvider).fcmToken;
      if (token != null) {
        await _authRepository.unregisterFcmToken(token);
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (_) {
      // can ignore
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

  Future<void> _updateFCMToken() async {
    if (!isAuthenticated) return;

    try {
      final fcmToken = await _notificationsService.fcmToken;
      if (fcmToken != null) {
        await _authRepository.updateFcmToken(fcmToken);
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        reason: 'FCM token update failed',
      );
    }
  }

  void _setState(AuthState newState) {
    state = newState;
    _authStateController.add(state);
  }
}

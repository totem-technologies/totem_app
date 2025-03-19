import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_state.dart';
import '../repositories/auth_repository.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/services/secure_storage.dart';
import '../../core/services/analytics_service.dart';

/// Provider for the authentication controller
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    secureStorage: ref.watch(secureStorageProvider),
  ),
);

/// Controller responsible for managing authentication state and operations
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final SecureStorage _secureStorage;
  final _authStateController = StreamController<AuthState>.broadcast();

  /// Stream of auth state changes for widgets to listen to
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  /// Constructor initializes state and checks for existing credentials
  AuthController({
    required AuthRepository authRepository,
    required SecureStorage secureStorage,
  }) : _authRepository = authRepository,
       _secureStorage = secureStorage,
       super(AuthState.unauthenticated()) {
    // Check for existing authentication when controller is created
    _checkExistingAuth();
  }

  /// Check if user is authenticated
  bool get isAuthenticated => state.status == AuthStatus.authenticated;

  /// Check if onboarding is completed for authenticated users
  bool get isOnboardingCompleted =>
      state.status == AuthStatus.authenticated &&
      state.user?.hasCompletedOnboarding == true;

  /// Request a magic link to be sent to the provided email
  Future<void> requestMagicLink(String email) async {
    try {
      state = AuthState.loading();
      _emitState();

      // Request magic link from backend
      await _authRepository.requestMagicLink(email);

      // Update state to awaiting verification
      state = AuthState.awaitingVerification(email: email);
      _emitState();

      // Log analytics
      AnalyticsService.instance.logEvent(
        'magic_link_requested',
        parameters: {'email': email},
      );
    } catch (e) {
      // Handle error
      state = AuthState.error(e.toString());
      _emitState();
      rethrow;
    }
  }

  /// Verify a magic link token
  Future<void> verifyMagicLink(String token) async {
    try {
      state = AuthState.loading();
      _emitState();

      // Verify the magic link token with backend
      final authResponse = await _authRepository.verifyMagicLink(token);

      // Store the API key securely
      await _secureStorage.write(key: 'api_key', value: authResponse.apiKey);

      // Set authenticated state with user
      state = AuthState.authenticated(user: authResponse.user);
      _emitState();

      // Log analytics
      AnalyticsService.instance.setUserId(authResponse.user.id);
      AnalyticsService.instance.logLogin(method: 'magic_link');
    } catch (e) {
      // Handle specific errors
      if (e is AppAuthException && e.code == 'MAGIC_LINK_EXPIRED') {
        state = AuthState.error(
          'Magic link has expired. Please request a new one.',
        );
      } else {
        state = AuthState.error('Authentication failed: ${e.toString()}');
      }
      _emitState();
      rethrow;
    }
  }

  /// Verify PIN code for login
  Future<void> verifyPin(String email, String pin) async {
    try {
      state = AuthState.loading();
      _emitState();

      // Verify PIN with backend
      final authResponse = await _authRepository.verifyPin(email, pin);

      // Store the API key securely
      await _secureStorage.write(key: 'api_key', value: authResponse.apiKey);

      // Set authenticated state with user
      state = AuthState.authenticated(user: authResponse.user);
      _emitState();

      // Log analytics
      AnalyticsService.instance.setUserId(authResponse.user.id);
      AnalyticsService.instance.logLogin(method: 'pin');
    } catch (e) {
      // Handle specific errors
      if (e is AppAuthException && e.code == 'INVALID_PIN') {
        state = AuthState.error('Invalid PIN code. Please try again.');
      } else if (e is AppAuthException && e.code == 'PIN_ATTEMPTS_EXCEEDED') {
        state = AuthState.error(
          'Too many failed attempts. Please request a new magic link.',
        );
      } else {
        state = AuthState.error('Authentication failed: ${e.toString()}');
      }
      _emitState();
      rethrow;
    }
  }

  /// Complete user onboarding/profile setup
  Future<void> completeOnboarding({
    required String firstName,
    String? profileImagePath,
  }) async {
    try {
      if (!isAuthenticated) {
        throw AppAuthException.unauthenticated();
      }

      state = state.copyWith(status: AuthStatus.loading);
      _emitState();

      // Update profile with backend
      final updatedUser = await _authRepository.updateProfile(
        userId: state.user!.id,
        firstName: firstName,
        profileImagePath: profileImagePath,
      );

      // Update state with completed onboarding flag
      state = AuthState.authenticated(user: updatedUser);
      _emitState();

      // Log analytics
      AnalyticsService.instance.logEvent('onboarding_completed');
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        error: 'Failed to update profile: ${e.toString()}',
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

      // Get the API key to revoke
      final apiKey = await _secureStorage.read(key: 'api_key');

      if (apiKey != null) {
        // Revoke the API key on the server
        await _authRepository.revokeApiKey(apiKey);
      }

      // Clear stored credentials
      await _secureStorage.delete(key: 'api_key');

      // Update state
      state = AuthState.unauthenticated();
      _emitState();

      // Log analytics
      AnalyticsService.instance.logEvent('user_logged_out');
      AnalyticsService.instance.setUserId(null);
    } catch (e) {
      // Even if there's an error, we should still clear local state
      await _secureStorage.delete(key: 'api_key');
      state = AuthState.unauthenticated();
      _emitState();

      // Log error
      debugPrint('Error during logout: $e');
    }
  }

  /// Check for existing authentication when app starts
  Future<void> _checkExistingAuth() async {
    try {
      // Set loading state
      state = AuthState.loading();
      _emitState();

      // Check for saved API key
      final apiKey = await _secureStorage.read(key: 'api_key');

      if (apiKey == null) {
        // No saved credentials
        state = AuthState.unauthenticated();
        _emitState();
        return;
      }

      // Validate the API key with backend
      final user = await _authRepository.validateApiKey(apiKey);

      // Set authenticated state
      state = AuthState.authenticated(user: user);

      // Set analytics user ID
      AnalyticsService.instance.setUserId(user.id);
    } catch (e) {
      // Invalid or expired credentials
      await _secureStorage.delete(key: 'api_key');
      state = AuthState.unauthenticated();

      // Log error but don't rethrow
      debugPrint('Error checking existing auth: $e');
    } finally {
      _emitState();
    }
  }

  /// Helper to emit the current state to the stream
  void _emitState() {
    _authStateController.add(state);
  }

  @override
  void dispose() {
    _authStateController.close();
    super.dispose();
  }
}

/// Provider for secure storage
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

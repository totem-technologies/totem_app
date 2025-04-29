import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/auth/models/user.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/services/api_service.dart';

/// Provider for the auth repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AuthRepository(apiService: apiService);
});

/// Repository responsible for authentication-related API operations
class AuthRepository {
  const AuthRepository({required this.apiService});
  final RestClient apiService;

  /// Request a magic link to be sent to email
  Future<void> requestMagicLink(String email) async {
    try {
      // Simulate API call
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // In a real implementation, this would call the API:
      // await _apiService.post('/auth/magic-link', data: {'email': email});

      // For testing, we'll just return success
      return;
    } catch (e) {
      throw AppAuthException(
        'Failed to request magic link: $e',
        code: 'REQUEST_FAILED',
      );
    }
  }

  /// Verify a magic link token
  Future<AuthResponse> verifyMagicLink(String token) async {
    try {
      // Simulate API call
      await Future<void>.delayed(const Duration(seconds: 1));

      // In a real implementation, this would call the API:
      // final response = await _apiService.post(
      //   '/auth/verify-magic-link',
      //   data: {'token': token}
      // );
      // return AuthResponse.fromJson(response.data);

      // For testing, return a mock user
      return AuthResponse(
        user: User(
          id: 'user-123',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        ),
        apiKey: 'test-api-key-123',
      );
    } catch (e) {
      if (e.toString().contains('expired')) {
        throw AppAuthException.magicLinkExpired();
      }
      throw AppAuthException(
        'Failed to verify magic link: $e',
        code: 'VERIFICATION_FAILED',
      );
    }
  }

  /// Verify a PIN code
  Future<AuthResponse> verifyPin(String email, String pin) async {
    try {
      // Simulate API call
      await Future<void>.delayed(const Duration(seconds: 1));

      // In a real implementation, this would call the API:
      // final response = await _apiService.post(
      //   '/auth/verify-pin',
      //   data: {'email': email, 'pin': pin}
      // );
      // return AuthResponse.fromJson(response.data);

      // For testing, validate PIN (just accept "123456" for now)
      if (pin != '123456') {
        throw AppAuthException.invalidPin();
      }

      return AuthResponse(
        user: User(
          id: 'user-123',
          email: email,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        ),
        apiKey: 'test-api-key-123',
      );
    } catch (e) {
      if (e is AppAuthException) {
        rethrow;
      }
      throw AppAuthException(
        'Failed to verify PIN: $e',
        code: 'PIN_VERIFICATION_FAILED',
      );
    }
  }

  /// Update user profile during onboarding
  Future<User> updateProfile({
    required String userId,
    required String firstName,
    String? profileImagePath,
  }) async {
    try {
      // Simulate API call
      await Future<void>.delayed(const Duration(seconds: 1));

      // In a real implementation, this would call the API:
      // If there's an image, it would first upload it:
      // String? profileImageUrl;
      // if (profileImagePath != null) {
      //   final uploadResponse = await _apiService.uploadFile(
      //     '/users/profile-image',
      //     filePath: profileImagePath
      //   );
      //   profileImageUrl = uploadResponse.data['url'];
      // }
      //
      // final response = await _apiService.patch(
      //   '/users/$userId',
      //   data: {
      //     'first_name': firstName,
      //     'profile_image_url': profileImageUrl,
      //     'has_completed_onboarding': true,
      //   }
      // );
      // return User.fromJson(response.data);

      // For testing, return a mock updated user
      return User(
        id: userId,
        email: 'test@example.com',
        firstName: firstName,
        profileImageUrl:
            profileImagePath != null
                ? 'https://example.com/test-image.jpg'
                : null,
        hasCompletedOnboarding: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        lastLoginAt: DateTime.now(),
      );
    } catch (e) {
      throw AppDataException(
        'Failed to update profile: $e',
        code: 'PROFILE_UPDATE_FAILED',
      );
    }
  }

  /// Validate an API key and get the associated user
  Future<User> validateApiKey(String apiKey) async {
    try {
      // Simulate API call
      await Future<void>.delayed(const Duration(seconds: 1));

      // In a real implementation, this would call the API:
      // final response = await _apiService.get(
      //   '/auth/validate-key',
      //   options: Options(headers: {'Authorization': 'Bearer $apiKey'})
      // );
      // return User.fromJson(response.data['user']);

      // For testing, simulate validation
      if (apiKey != 'test-api-key-123') {
        throw AppAuthException.unauthenticated();
      }

      return User(
        id: 'user-123',
        email: 'test@example.com',
        firstName: 'Test',
        hasCompletedOnboarding: true,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        lastLoginAt: DateTime.now(),
      );
    } catch (e) {
      if (e is AppAuthException) {
        rethrow;
      }
      throw AppAuthException(
        'Failed to validate API key: $e',
        code: 'KEY_VALIDATION_FAILED',
      );
    }
  }

  /// Revoke an API key
  Future<void> revokeApiKey(String apiKey) async {
    try {
      // Simulate API call
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // In a real implementation, this would call the API:
      // await _apiService.post(
      //   '/auth/revoke-key',
      //   data: {'api_key': apiKey}
      // );

      // For testing, just return success
      return;
    } catch (e) {
      // Log but don't throw, as we want logout to succeed even if revoke fails
      debugPrint('Warning: Failed to revoke API key: $e');
    }
  }
}

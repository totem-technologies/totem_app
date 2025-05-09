import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
import 'package:totem_app/api/models/fcm_token_register_schema.dart';
import 'package:totem_app/api/models/message_response.dart';
import 'package:totem_app/api/models/pin_request_schema.dart';
import 'package:totem_app/api/models/refresh_token_schema.dart';
import 'package:totem_app/api/models/token_response.dart';
import 'package:totem_app/api/models/user_schema.dart';
import 'package:totem_app/api/models/validate_pin_schema.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/services/api_service.dart';

/// Provider for the auth repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiService = ref.watch(mobileApiServiceProvider);
  return AuthRepository(apiService: apiService);
});

/// Repository responsible for authentication-related API operations
class AuthRepository {
  const AuthRepository({required this.apiService});

  final MobileTotemApi apiService;

  Future<UserSchema> get currentUser async {
    try {
      return await apiService.client.totemApiMobileApiCurrentUser();
    } catch (e) {
      if (e is AppAuthException) rethrow;
      throw AppAuthException(
        'Failed to fetch current user: $e',
        code: 'CURRENT_USER_FETCH_FAILED',
      );
    }
  }

  Future<MessageResponse> requestPin(
    String email,
    bool newsletterConsent,
  ) async {
    try {
      return await apiService.client.totemApiAuthRequestPin(
        body: PinRequestSchema(
          email: email,
          newsletterConsent: newsletterConsent,
        ),
      );
    } catch (e) {
      if (e is AppAuthException) rethrow;
      throw AppAuthException(
        'Failed to request PIN: $e',
        code: 'PIN_REQUEST_FAILED',
      );
    }
  }

  /// Verify a PIN code
  Future<TokenResponse> verifyPin(String email, String pin) async {
    try {
      return await apiService.client.totemApiAuthValidatePin(
        body: ValidatePinSchema(email: email, pin: pin),
      );
    } catch (e) {
      if (e is AppAuthException) rethrow;
      throw AppAuthException(
        'Failed to verify PIN: $e',
        code: 'PIN_VERIFICATION_FAILED',
      );
    }
  }

  /// Logout by invalidating a refresh token
  Future<MessageResponse> logout(String refreshToken) async {
    try {
      return await apiService.client.totemApiAuthLogout(
        body: RefreshTokenSchema(refreshToken: refreshToken),
      );
    } catch (e) {
      if (e is AppAuthException) rethrow;
      throw AppAuthException('Failed to logout: $e', code: 'LOGOUT_FAILED');
    }
  }

  /// Check if the user is authenticated
  static bool isAuthenticated(String? jwtToken) {
    if (jwtToken == null) return false;
    return !isAccessTokenExpired(jwtToken);
  }

  static bool isAccessTokenExpired(String? jwtToken) {
    if (jwtToken == null) return true;

    try {
      final payload = jwtToken.split('.')[1];
      final normalizedPayload = base64Url.normalize(payload);
      final decodedPayload = utf8.decode(base64Url.decode(normalizedPayload));
      final Map<String, dynamic> payloadMap =
          (jsonDecode(decodedPayload) as Map).cast<String, dynamic>();

      final exp = payloadMap['exp'];
      if (exp is! int) return true;

      final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return expirationDate.isBefore(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  /// Update FCM token
  Future<void> updateFcmToken(String fcmToken) async {
    try {
      await apiService.client.totemApiMobileApiRegisterFcmToken(
        body: FcmTokenRegisterSchema(token: fcmToken),
      );
    } catch (e) {
      if (e is AppAuthException) rethrow;
      throw AppAuthException(
        'Failed to update FCM token: $e',
        code: 'FCM_TOKEN_UPDATE_FAILED',
      );
    }
  }

  /// Unregister FCM token
  Future<void> unregisterFcmToken(String fcmToken) async {
    try {
      await apiService.client.totemApiMobileApiUnregisterFcmToken(
        token: fcmToken,
      );
    } catch (e) {
      if (e is AppAuthException) rethrow;
      throw AppAuthException(
        'Failed to unregister FCM token: $e',
        code: 'FCM_TOKEN_UNREGISTER_FAILED',
      );
    }
  }
}

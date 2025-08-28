import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/api_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiService = ref.watch(mobileApiServiceProvider);
  return AuthRepository(apiService: apiService);
});

class AuthRepository {
  const AuthRepository({required this.apiService});

  final MobileTotemApi apiService;

  Future<T> _handleApiCall<T>(
    Future<T> Function() apiCall, {
    required String operationName,
    required String genericErrorCode,
  }) async {
    try {
      return await apiCall();
    } catch (error, stackTrace) {
      ErrorHandler.logError(error, stackTrace: stackTrace);
      if (error is AppAuthException) {
        rethrow;
      }
      if (error is DioException) {
        final response = error.response;
        if (response != null) {
          if (response.statusCode == 401) {
            throw AppAuthException(
              'Unauthorized: ${response.data}',
              code: 'UNAUTHORIZED',
            );
          }
          throw AppAuthException(
            'Failed to $operationName (${response.statusCode}): '
            '${response.data}',
            code: genericErrorCode,
            details: error.message ?? error.toString(),
          );
        } else {
          throw AppAuthException(
            'Failed to $operationName due to a network or unknown error: '
            '${error.message ?? error.toString()}',
            code: genericErrorCode,
          );
        }
      }
      throw AppAuthException(
        'Failed to $operationName: $error',
        code: genericErrorCode,
      );
    }
  }

  Future<UserSchema> get currentUser async {
    return _handleApiCall<UserSchema>(
      () => apiService.fallback.totemUsersMobileApiGetCurrentUser(),
      operationName: 'fetch current user',
      genericErrorCode: 'CURRENT_USER_FETCH_FAILED',
    );
  }

  Future<bool> updateCurrentUserProfilePicture(File file) {
    return _handleApiCall<bool>(
      () => apiService.fallback.totemUsersMobileApiUpdateCurrentUserImage(
        profileImage: file,
      ),
      operationName: 'update current user profile picture',
      genericErrorCode: 'CURRENT_USER_PROFILE_PICTURE_UPDATE_FAILED',
    );
  }

  /// Update the current user's profile.
  Future<UserSchema> updateCurrentUserProfile({
    String? name,
    String? email,
    String? timezone,
    bool? newsletterConsent,
    ProfileAvatarTypeEnum? profileAvatarType,
    String? avatarSeed,
  }) async {
    return _handleApiCall<UserSchema>(
      () => apiService.fallback.totemUsersMobileApiUpdateCurrentUser(
        body: UserUpdateSchema(
          name: name,
          email: email,
          timezone: timezone,
          newsletterConsent: newsletterConsent,
          profileAvatarType: profileAvatarType,
          profileAvatarSeed: avatarSeed,
        ),
      ),
      operationName: 'update current user profile',
      genericErrorCode: 'CURRENT_USER_PROFILE_UPDATE_FAILED',
    );
  }

  Future<OnboardSchema> get onboardStatus async {
    return _handleApiCall<OnboardSchema>(
      () => apiService.fallback.totemOnboardMobileApiOnboardGet(),
      operationName: 'fetch onboard status',
      genericErrorCode: 'ONBOARD_STATUS_FETCH_FAILED',
    );
  }

  Future<OnboardSchema> completeOnboarding({
    required ReferralChoices? referralSource,
    required Set<String> interestTopics,
    int? yearBorn,
    String? referralOther,
  }) async {
    return _handleApiCall<OnboardSchema>(
      () => apiService.fallback.totemOnboardMobileApiOnboardPost(
        body: OnboardSchema(
          referralSource: referralSource ?? ReferralChoices.valueDefault,
          referralOther: referralOther ?? '',
          hopes: interestTopics.join(', '),
          yearBorn: yearBorn,
        ),
      ),
      operationName: 'complete onboarding',
      genericErrorCode: 'ONBOARDING_COMPLETION_FAILED',
    );
  }

  Future<MessageResponse> requestPin(
    String email,
    bool newsletterConsent,
  ) async {
    return _handleApiCall<MessageResponse>(
      () => apiService.fallback.totemApiAuthRequestPin(
        body: PinRequestSchema(
          email: email,
          newsletterConsent: newsletterConsent,
        ),
      ),
      operationName: 'request PIN',
      genericErrorCode: 'PIN_REQUEST_FAILED',
    );
  }

  /// Verify a PIN code
  Future<TokenResponse> verifyPin(String email, String pin) async {
    return _handleApiCall<TokenResponse>(
      () => apiService.fallback.totemApiAuthValidatePin(
        body: ValidatePinSchema(email: email, pin: pin),
      ),
      operationName: 'verify PIN',
      genericErrorCode: 'PIN_VERIFICATION_FAILED',
    );
  }

  /// Logout by invalidating a refresh token
  Future<MessageResponse> logout(String refreshToken) async {
    return _handleApiCall<MessageResponse>(
      () => apiService.fallback.totemApiAuthLogout(
        body: RefreshTokenSchema(refreshToken: refreshToken),
      ),
      operationName: 'logout',
      genericErrorCode: 'LOGOUT_FAILED',
    );
  }

  Future<void> deleteAccount() async {
    return _handleApiCall<void>(
      () => apiService.fallback.totemUsersMobileApiDeleteCurrentUser(),
      operationName: 'delete account',
      genericErrorCode: 'ACCOUNT_DELETION_FAILED',
    );
  }

  /// Check if the user is authenticated
  static bool isAuthenticated(String? jwtToken) {
    if (jwtToken == null) return false;
    return !isAccessTokenExpired(jwtToken);
  }

  static bool isAccessTokenExpired(String? jwtToken) {
    if (jwtToken == null) return true;

    try {
      final parts = jwtToken.split('.');
      if (parts.length != 3) return true;

      final payload = parts[1];
      final normalizedPayload = base64Url.normalize(payload);
      final decodedPayload = utf8.decode(base64Url.decode(normalizedPayload));
      final payloadMap = jsonDecode(decodedPayload) as Map<String, dynamic>;

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
    return _handleApiCall(
      () => apiService.fallback.totemApiMobileApiRegisterFcmToken(
        body: FcmTokenRegisterSchema(token: fcmToken),
      ),
      operationName: 'update FCM token',
      genericErrorCode: 'FCM_TOKEN_UPDATE_FAILED',
    );
  }

  /// Unregister FCM token
  Future<void> unregisterFcmToken(String fcmToken) async {
    return _handleApiCall(
      () => apiService.fallback.totemApiMobileApiUnregisterFcmToken(
        token: fcmToken,
      ),
      operationName: 'unregister FCM token',
      genericErrorCode: 'FCM_TOKEN_UNREGISTER_FAILED',
    );
  }
}

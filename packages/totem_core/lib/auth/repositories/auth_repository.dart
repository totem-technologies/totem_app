import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/repository_utils.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiService = ref.read(mobileApiServiceProvider);
  return AuthRepository(apiService: apiService);
}, name: 'Auth Repository Provider');

class AuthRepository {
  const AuthRepository({required this.apiService});

  final TotemMobileApi apiService;

  Future<UserSchema> get currentUser async {
    return RepositoryUtils.handleApiCall<UserSchema>(
      apiCall: () => apiService.users.totemUsersMobileApiGetCurrentUser(),
      operationName: 'fetch current user',
    );
  }

  Future<bool> updateCurrentUserProfilePicture(File file) async {
    final bytes = await file.readAsBytes();
    return RepositoryUtils.handleApiCall<bool>(
      apiCall: () => apiService.users.totemUsersMobileApiUpdateCurrentUserImage(
        body: UpdateCurrentUserImageRequest(profileImage: bytes),
      ),
      operationName: 'update current user profile picture',
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
    return RepositoryUtils.handleApiCall<UserSchema>(
      apiCall: () => apiService.users.totemUsersMobileApiUpdateCurrentUser(
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
    );
  }

  Future<OnboardSchema> get onboardStatus async {
    return RepositoryUtils.handleApiCall<OnboardSchema>(
      apiCall: () => apiService.$default.totemOnboardMobileApiOnboardGet(),
      operationName: 'fetch onboard status',
    );
  }

  Future<OnboardSchema> completeOnboarding({
    required ReferralChoices? referralSource,
    required Set<String> interestTopics,
    int? yearBorn,
    String? referralOther,
  }) async {
    return RepositoryUtils.handleApiCall<OnboardSchema>(
      apiCall: () => apiService.$default.totemOnboardMobileApiOnboardPost(
        body: OnboardSchema(
          referralSource: referralSource ?? ReferralChoices.$default,
          referralOther: referralOther ?? '',
          hopes: interestTopics.join(', '),
          yearBorn: yearBorn,
        ),
      ),
      operationName: 'complete onboarding',
    );
  }

  Future<MessageResponse> requestPin(
    String email,
    bool newsletterConsent,
  ) async {
    return RepositoryUtils.handleApiCall<MessageResponse>(
      apiCall: () => apiService.$default.totemApiAuthRequestPin(
        body: PinRequestSchema(
          email: email,
          newsletterConsent: newsletterConsent,
        ),
      ),
      operationName: 'request PIN',
    );
  }

  /// Verifcly a PIN code
  Future<TokenResponse> verifyPin(String email, String pin) async {
    return RepositoryUtils.handleApiCall<TokenResponse>(
      apiCall: () => apiService.$default.totemApiAuthValidatePin(
        body: ValidatePinSchema(email: email, pin: pin),
      ),
      operationName: 'verify PIN',
    );
  }

  /// Refresh access token using a refresh token
  Future<TokenResponse> refreshAccessToken(String refreshToken) async {
    return RepositoryUtils.handleApiCall<TokenResponse>(
      apiCall: () => apiService.$default.totemApiAuthRefreshToken(
        body: RefreshTokenSchema(refreshToken: refreshToken),
      ),
      operationName: 'refresh access token',
    );
  }

  /// Logout by invalidating a refresh token
  Future<MessageResponse> logout(String refreshToken) async {
    return RepositoryUtils.handleApiCall<MessageResponse>(
      apiCall: () => apiService.$default.totemApiAuthLogout(
        body: RefreshTokenSchema(refreshToken: refreshToken),
      ),
      operationName: 'logout',
    );
  }

  Future<void> deleteAccount() async {
    return RepositoryUtils.handleApiCall<void>(
      apiCall: () => apiService.users.totemUsersMobileApiDeleteCurrentUser(),
      operationName: 'delete account',
    );
  }

  bool isAccessTokenExpired(String? jwtToken) {
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
    return RepositoryUtils.handleApiCall(
      apiCall: () => apiService.$default.totemApiMobileApiRegisterFcmToken(
        body: FcmTokenRegisterSchema(token: fcmToken),
      ),
      operationName: 'update FCM token',
    );
  }

  /// Unregister FCM token
  Future<void> unregisterFcmToken(String fcmToken) async {
    return RepositoryUtils.handleApiCall(
      apiCall: () => apiService.$default.totemApiMobileApiUnregisterFcmToken(
        token: fcmToken,
      ),
      operationName: 'unregister FCM token',
    );
  }
}

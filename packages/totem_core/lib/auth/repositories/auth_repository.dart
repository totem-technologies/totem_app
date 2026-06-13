import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/core/services/repository_utils.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return AuthRepository(apiService: apiService);
}, name: 'Auth Repository Provider');

class AuthRepository {
  const AuthRepository({required this.apiService});

  final ClientApi apiService;

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

  Future<TokenResponse> verifyPin(String email, String pin) async {
    return RepositoryUtils.handleApiCall<TokenResponse>(
      apiCall: () => apiService.$default.totemApiAuthValidatePin(
        body: ValidatePinSchema(email: email, pin: pin),
      ),
      operationName: 'verify PIN',
    );
  }

  Future<TokenResponse> refreshAccessToken(String refreshToken) async {
    return RepositoryUtils.handleApiCall<TokenResponse>(
      apiCall: () => apiService.$default.totemApiAuthRefreshToken(
        body: RefreshTokenSchema(refreshToken: refreshToken),
      ),
      operationName: 'refresh access token',
    );
  }

  Future<MessageResponse> logout(String refreshToken) async {
    return RepositoryUtils.handleApiCall<MessageResponse>(
      apiCall: () => apiService.$default.totemApiAuthLogout(
        body: RefreshTokenSchema(refreshToken: refreshToken),
      ),
      operationName: 'logout',
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

  Future<void> updateFcmToken(String fcmToken) async {
    return RepositoryUtils.handleApiCall(
      apiCall: () => apiService.$default.totemApiMobileApiRegisterFcmToken(
        body: FcmTokenRegisterSchema(token: fcmToken),
      ),
      operationName: 'update FCM token',
    );
  }

  Future<void> unregisterFcmToken(String fcmToken) async {
    return RepositoryUtils.handleApiCall(
      apiCall: () => apiService.$default.totemApiMobileApiUnregisterFcmToken(
        token: fcmToken,
      ),
      operationName: 'unregister FCM token',
    );
  }
}

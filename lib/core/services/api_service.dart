import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
import 'package:totem_app/api/models/refresh_token_schema.dart';
import 'package:totem_app/api/totem_api.dart';
import 'package:totem_app/auth/repositories/auth_repository.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/config/consts.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/secure_storage.dart';
import 'package:totem_app/shared/logger.dart';

/// Provider for secure storage
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

/// Provider for the API service
final apiServiceProvider = Provider<TotemApi>((ref) {
  final dio = _initDio(ref);
  return TotemApi(dio, baseUrl: AppConfig.apiUrl);
});

/// Provider for the API service
final mobileApiServiceProvider = Provider<MobileTotemApi>((ref) {
  final dio = _initDio(ref);
  return MobileTotemApi(dio, baseUrl: AppConfig.mobileApiUrl);
});

/// Initialize Dio instance with interceptors and base configuration
Dio _initDio(Ref ref) {
  final dio = Dio();

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final secureStorage = ref.read(secureStorageProvider);
        String? accessToken = await secureStorage.read(
          key: AppConsts.accessToken,
        );

        // Refresh if expired
        if (AuthRepository.isAccessTokenExpired(accessToken)) {
          logger.d('🔑 Access token expired, refreshing...');
          final refreshToken = await secureStorage.read(
            key: AppConsts.refreshToken,
          );

          if (refreshToken != null) {
            try {
              final response =
                  await MobileTotemApi(
                    Dio(),
                    baseUrl: AppConfig.mobileApiUrl,
                  ).client.totemApiAuthRefreshToken(
                    body: RefreshTokenSchema(refreshToken: refreshToken),
                  );
              accessToken = response.accessToken;

              logger.d(
                '🔑 Token refreshed successfully! New token: $accessToken',
              );

              await secureStorage.write(
                key: AppConsts.accessToken,
                value: response.accessToken,
              );
              await secureStorage.write(
                key: AppConsts.refreshToken,
                value: response.refreshToken,
              );
            } catch (error, stackTrace) {
              await secureStorage.delete(key: AppConsts.accessToken);
              await secureStorage.delete(key: AppConsts.refreshToken);

              ErrorHandler.logError(
                error,
                stackTrace: stackTrace,
                message: '🔑 Error refreshing access token',
              );

              return handler.reject(
                DioException(
                  requestOptions: options,
                  error: AppAuthException.unauthenticated(),
                ),
              );
            }
          } else {
            logger.d('🔑 Refresh token not found, redirecting to login...');
          }
        }

        // Add Authorization header if not already present
        if (accessToken != null &&
            !options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }

        return handler.next(options);
      },

      onError: (DioException error, handler) {
        // Convert to app-specific exception
        final appException = _handleDioError(error);

        return handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            error: appException,
            response: error.response,
            type: error.type,
            message: appException.toString(),
          ),
        );
      },
    ),
  );

  if (AppConfig.isDevelopment) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  return dio;
}

/// Handle Dio errors and convert them to app-specific exceptions
Exception _handleDioError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return AppNetworkException.timeout();

    case DioExceptionType.unknown:
      if (error.error != null &&
          error.error.toString().contains('SocketException')) {
        return AppNetworkException.noConnection();
      }
      return AppNetworkException(
        'Unknown error occurred: ${error.message}',
        details: error,
      );

    case DioExceptionType.badCertificate:
      return AppNetworkException(
        'Invalid certificate',
        code: 'BAD_CERTIFICATE',
        details: error,
      );

    case DioExceptionType.badResponse:
      final statusCode = error.response?.statusCode;

      // Handle authentication errors
      if (statusCode == 401) {
        return AppAuthException.unauthenticated();
      }
      if (statusCode == 403) {
        return AppAuthException(
          'Access denied',
          code: 'FORBIDDEN',
          details: error.response?.data,
        );
      }

      // Handle server errors
      if (statusCode != null && statusCode >= 500) {
        return AppNetworkException.serverError(
          statusCode,
          details: error.response?.data,
        );
      }

      // Handle other response errors
      return AppNetworkException(
        'Error status code: $statusCode',
        code: 'HTTP_ERROR_$statusCode',
        details: error.response?.data,
      );

    default:
      return AppNetworkException(
        'Network error: ${error.message}',
        details: error,
      );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
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
}, name: 'Secure Storage Provider');

/// Provider for the API service
final mobileApiServiceProvider = Provider<MobileTotemApi>((ref) {
  final dio = _initDio(ref);
  return MobileTotemApi(dio, baseUrl: AppConfig.mobileApiUrl);
}, name: 'Mobile Totem API Service Provider');

final _dio = Dio();

/// Initialize Dio instance with interceptors and base configuration
Dio _initDio(Ref ref) {
  _dio.options = BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  );

  _dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final secureStorage = ref.read(secureStorageProvider);
        String? accessToken = await secureStorage.read(
          key: AppConsts.accessTokenKey,
        );

        // Don't try to refresh the token for the refresh token endpoint itself
        if (options.path.endsWith('/auth/refresh') ||
            options.path.endsWith('/auth/request-pin')) {
          logger.d('🔑 Skipping token refresh for ${options.path}');
          return handler.next(options);
        }

        final authRepository = ref.read(authRepositoryProvider);

        // Refresh if expired
        if (authRepository.isAccessTokenExpired(accessToken)) {
          logger.d('🔑 Access token expired, refreshing...');
          final refreshToken = await secureStorage.read(
            key: AppConsts.refreshTokenKey,
          );

          if (refreshToken != null) {
            try {
              final response = await authRepository.refreshAccessToken(
                refreshToken,
              );
              accessToken = response.accessToken;

              logger.d('🔑 Access Token refreshed successfully');

              await secureStorage.write(
                key: AppConsts.accessTokenKey,
                value: response.accessToken,
              );
              await secureStorage.write(
                key: AppConsts.refreshTokenKey,
                value: response.refreshToken,
              );
            } on DioException catch (error, stackTrace) {
              // This is the critical part: if token refresh fails due to
              // network, we don't want to log the user out.
              if (error.type != DioExceptionType.badResponse) {
                // It's a network error, not an auth error.
                // Let the original request fail with a network error.
                return handler.next(options);
              }

              // If it's a bad response (like 401), then it's a real auth issue.
              await secureStorage.delete(key: AppConsts.accessTokenKey);
              await secureStorage.delete(key: AppConsts.refreshTokenKey);

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
            logger.d('🔑 Refresh token not found, user needs to log in.');
          }
        }

        // Add Authorization header if not already present
        if (accessToken != null &&
            !options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }

        return handler.next(options);
      },
      onError: (error, handler) {
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
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );
  }

  _dio.addSentry();

  return _dio;
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
        code: error.type.name,
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
          code: 'FORBIDDEN (403)',
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

Future<Response<dynamic>> postData(
  String url, {
  Map<String, dynamic> data = const {},
}) async {
  final body = {
    ...data,
  };

  final response = await _dio.post<dynamic>(
    url,
    data: FormData.fromMap(body),
    options: Options(
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    ),
  );

  return response;
}

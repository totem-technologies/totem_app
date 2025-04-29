import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/rest_client.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/services/secure_storage.dart';

/// Provider for secure storage
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

/// Provider for the API service
final apiServiceProvider = Provider<RestClient>((ref) {
  final dio = _initDio(ref);
  return RestClient(dio, baseUrl: AppConfig.apiUrl);
});

/// Initialize Dio instance with interceptors and base configuration
Dio _initDio(Ref ref) {
  final dio = Dio();

  // Add auth interceptor to inject API key
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Only add auth header if the request doesn't already have one
        if (!options.headers.containsKey('Authorization')) {
          final apiKey = await ref
              .read(secureStorageProvider)
              .read(key: 'api_key');
          if (apiKey != null) {
            options.headers['Authorization'] = 'Bearer $apiKey';
          }
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) {
        // Convert DioExceptions to our app-specific exceptions before
        // propagating
        final appException = _handleDioError(error);
        return handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            error: appException,
            // Pass through the original data
            response: error.response,
            type: error.type,
            message: appException.toString(),
          ),
        );
      },
    ),
  );

  // Add logging interceptor in debug mode
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

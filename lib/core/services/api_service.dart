import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../errors/app_exceptions.dart';
import '../config/app_config.dart';
import '../constants/api_endpoints.dart';
import 'secure_storage.dart';

/// Provider for secure storage
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

/// Provider for the API service
final apiServiceProvider = Provider<ApiService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return ApiService(secureStorage: secureStorage);
});

/// Service for making API requests with authentication and error handling
class ApiService {
  late final Dio _dio;
  final SecureStorage _secureStorage;

  ApiService({required SecureStorage secureStorage})
    : _secureStorage = secureStorage {
    _initDio();
  }

  /// Initialize Dio instance with interceptors and base configuration
  void _initDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add auth interceptor to inject API key
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Only add auth header if the request doesn't already have one
          if (!options.headers.containsKey('Authorization')) {
            final apiKey = await _secureStorage.read(key: 'api_key');
            if (apiKey != null) {
              options.headers['Authorization'] = 'Bearer $apiKey';
            }
          }
          return handler.next(options);
        },
      ),
    );

    // Add logging interceptor in debug mode
    if (AppConfig.isDevelopment) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
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

  /// GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PATCH request
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Upload a file
  Future<Response> uploadFile(
    String path, {
    required String filePath,
    String fileKey = 'file',
    Map<String, dynamic>? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        ...?data,
        fileKey: await MultipartFile.fromFile(filePath),
      });

      return await _dio.post(
        path,
        data: formData,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Download a file
  Future<Response> downloadFile(
    String path,
    String savePath, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.download(
        path,
        savePath,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Create a cancellation token for requests that may need to be cancelled
  CancelToken createCancelToken() {
    return CancelToken();
  }

  /// Set a custom header for all future requests (e.g., for device info)
  void setCustomHeader(String key, String value) {
    _dio.options.headers[key] = value;
  }

  /// Set the auth token directly (alternative to the interceptor)
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear the auth token (e.g., during logout)
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Update the base URL (e.g., for environment switching)
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  /// Update timeout settings
  void updateTimeouts({Duration? connectTimeout, Duration? receiveTimeout}) {
    if (connectTimeout != null) {
      _dio.options.connectTimeout = connectTimeout;
    }

    if (receiveTimeout != null) {
      _dio.options.receiveTimeout = receiveTimeout;
    }
  }
}

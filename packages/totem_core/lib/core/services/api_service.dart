import 'package:degenerate_dio/degenerate_dio.dart';
import 'package:dio/dio.dart' hide Interceptor, RequestOptions;
import 'package:dio/dio.dart'
    as dio
    show Interceptor, RequestInterceptorHandler, RequestOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:totem_core/auth/repositories/auth_repository.dart';
import 'package:totem_core/core/api/api_client/api_client.dart' as api;
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/config/consts.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/secure_storage.dart';
import 'package:totem_core/shared/logger.dart';

/// Provider for secure storage
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
}, name: 'Secure Storage Provider');

/// Provider for the API service.
///
/// Mobile uses the default bearer-token + refresh-token flow. Web can override
/// this provider at the app boundary with a cookie-based client.
final apiServiceProvider = Provider<api.ClientApi>((ref) {
  final dio = _initDio(ref);
  return api.ClientApi(
    api.ApiConfig(
      client: DioApiClient(
        baseUrl: Uri.parse(AppConfig.instance.apiUrl),
        inner: dio,
      ),
      // timeout: Duration(seconds: 10), // or use a single overall deadline here
    ),
  );
}, name: 'Totem API Service Provider');

class AuthTokenInterceptor extends dio.Interceptor {
  const AuthTokenInterceptor({
    required this.secureStorage,
    required this.authRepository,
  });

  final SecureStorage secureStorage;
  final AuthRepository Function() authRepository;

  @override
  Future<void> onRequest(
    dio.RequestOptions options,
    dio.RequestInterceptorHandler handler,
  ) async {
    String? accessToken = await secureStorage.read(
      key: AppConsts.accessTokenKey,
    );

    // Refresh endpoints must be callable without a valid access token.
    if (options.path.endsWith('/auth/refresh') ||
        options.path.endsWith('/auth/request-pin')) {
      logger.d('🔑 Skipping token refresh for ${options.path}');
      handler.next(options);
      return;
    }

    final authRepository = this.authRepository();
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
        } on Exception catch (error, stackTrace) {
          // Network failures should not log the user out.
          if (error is DioException &&
              error.type != DioExceptionType.badResponse) {
            handler.next(options);
            return;
          }

          await secureStorage.delete(key: AppConsts.accessTokenKey);
          await secureStorage.delete(key: AppConsts.refreshTokenKey);
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: '🔑 Error refreshing access token',
          );

          handler.reject(
            DioException(
              requestOptions: options,
              error: AppAuthException.unauthenticated(),
            ),
          );
          return;
        }
      } else {
        logger.d('🔑 Refresh token not found, user needs to log in.');
      }
    }

    if (accessToken != null && !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }
}

final _dio = Dio(BaseOptions(responseType: ResponseType.json));

void addSharedApiInterceptors(Dio dio) {
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) {
        // A preceding interceptor may already have classified this failure.
        // Preserve that exception instance so RepositoryUtils can avoid
        // reporting the same failure again at another layer.
        if (error.error is AppException) {
          return handler.next(error);
        }
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

  if (AppConfig.instance.isDevelopment) {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  dio.addSentry();
}

/// Initialize Dio instance with interceptors and base configuration
Dio _initDio(Ref ref) {
  _dio.options = BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  );

  _dio.interceptors.add(
    AuthTokenInterceptor(
      secureStorage: ref.read(secureStorageProvider),
      authRepository: () => ref.read(authRepositoryProvider),
    ),
  );

  addSharedApiInterceptors(_dio);

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
  final body = {...data};

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

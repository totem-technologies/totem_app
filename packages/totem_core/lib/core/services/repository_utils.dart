import 'dart:async';

import 'package:dio/dio.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/shared/logger.dart';

typedef ErrorReporter =
    void Function(
      Object error, {
      StackTrace? stackTrace,
      String? message,
      Map<String, Object?>? diagnostics,
    });

typedef ShouldReportError = bool Function(Object error);

/// Shared utility functions for repository error handling.
///
/// Provides consistent error handling patterns across all repositories.
class RepositoryUtils {
  const RepositoryUtils._();

  /// Handles API calls with consistent error handling and optional retry logic.
  ///
  /// [apiCall] - The API call function to execute
  /// [operationName] - Human-readable name for the operation (used in logs)
  /// [retryOnNetworkError] - Whether to retry on network errors
  /// [maxRetries] - Maximum number of retry attempts (0 = no retries, just 1 attempt)
  /// [timeout] - Optional timeout for each attempt
  /// [diagnostics] - Non-sensitive request context attached to the report
  /// [shouldReport] - Suppresses reporting for expected domain responses
  ///
  /// Returns the result of [apiCall] if successful.
  /// Throws [AppAuthException] for authentication errors.
  /// Throws [AppNetworkException] for network errors.
  /// Throws [AppDataException] for data/validation errors.
  static Future<T> handleApiCall<T>({
    required Future<ApiResult<T, dynamic>> Function() apiCall,
    required String operationName,
    bool retryOnNetworkError = false,
    int maxRetries = 1,
    Duration? timeout,
    Map<String, Object?> diagnostics = const {},
    ShouldReportError? shouldReport,
    ErrorReporter? errorReporter,
  }) async {
    final totalAttempts = retryOnNetworkError ? maxRetries + 1 : 1;

    for (int attempt = 0; attempt < totalAttempts; attempt++) {
      try {
        final future = apiCall();
        final result = await (timeout != null
            ? future.timeout(timeout)
            : future);

        return result.dataOrThrow;
      } catch (error, stackTrace) {
        if (error is AppAuthException) {
          rethrow;
        }

        final normalizedError = _normalizeError(error, operationName);
        if (normalizedError is AppAuthException) {
          Error.throwWithStackTrace(normalizedError, stackTrace);
        }
        final isLastAttempt = attempt >= totalAttempts - 1;

        final isRetryableError =
            normalizedError is AppNetworkException ||
            (normalizedError is ApiError && normalizedError.statusCode >= 500);

        if (!isLastAttempt && retryOnNetworkError && isRetryableError) {
          logger.d(
            'Retrying $operationName (attempt ${attempt + 2}/$totalAttempts)...',
          );
          await Future<void>.delayed(_getRetryDelay(attempt));
          continue;
        }

        if (shouldReport?.call(normalizedError) ?? true) {
          final report = errorReporter ?? ErrorHandler.logError;
          report(
            normalizedError,
            stackTrace: stackTrace,
            message:
                'Error in $operationName '
                '(attempt ${attempt + 1}/$totalAttempts)',
            diagnostics: {
              'operation': operationName,
              'attempt': attempt + 1,
              'total_attempts': totalAttempts,
              'retry_on_network_error': retryOnNetworkError,
              if (timeout != null) 'timeout_ms': timeout.inMilliseconds,
              ...diagnostics,
              ..._errorDiagnostics(error),
            },
          );
        }

        Error.throwWithStackTrace(normalizedError, stackTrace);
      }
    }

    throw AppNetworkException(
      'Unexpected error in $operationName: all attempts exhausted',
    );
  }

  static Object _normalizeError(Object error, String operationName) {
    if (error is FormatException) {
      return AppDataException(
        'Data is in an invalid format',
        code: 'INVALID_FORMAT',
        details: {'cause': error.toString()},
      );
    }
    if (error is DioException) {
      final innerError = error.error;
      if (innerError is AppException) return innerError;
      return _convertDioException(error, operationName);
    }
    if (error is TimeoutException) {
      return AppNetworkException(
        'Request timed out',
        code: 'TIMEOUT',
        details: {'cause': error.toString()},
      );
    }
    return error;
  }

  static Map<String, Object?> _errorDiagnostics(Object error) {
    if (error is DioException) {
      return {
        'error_type': error.runtimeType.toString(),
        'dio_type': error.type.name,
        'request_method': error.requestOptions.method,
        'request_path': error.requestOptions.path,
        'status_code': ?error.response?.statusCode,
        'error_message': ?error.message,
        if (error.response?.data case final responseData?)
          'response_data': _truncate(responseData.toString()),
        if (error.error case final cause?) 'cause': _truncate(cause.toString()),
      };
    }
    if (error is ApiError) {
      return {
        'error_type': error.runtimeType.toString(),
        'status_code': error.statusCode,
        if (error.error case final typedError?)
          'response_error': _truncate(typedError.toString()),
        if (error.rawError case final rawError?)
          'raw_response': _truncate(rawError),
      };
    }
    return {
      'error_type': error.runtimeType.toString(),
      'cause': _truncate(error.toString()),
    };
  }

  static String _truncate(String value) {
    const maxLength = 2000;
    return value.length <= maxLength
        ? value
        : '${value.substring(0, maxLength)}…';
  }

  /// Converts DioException to app-specific exceptions.
  static Exception _convertDioException(
    DioException error,
    String operationName,
  ) {
    final statusCode = error.response?.statusCode;
    final details = _errorDiagnostics(error);

    if (statusCode == 401) {
      return AppAuthException(
        'User is not authenticated',
        code: 'UNAUTHENTICATED',
        details: details,
      );
    }
    if (statusCode == 403) {
      return AppAuthException(
        'Access denied',
        code: 'FORBIDDEN',
        details: details,
      );
    }
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return AppDataException(
        'Failed to $operationName',
        code: 'HTTP_ERROR_$statusCode',
        details: details,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return AppNetworkException.serverError(
        statusCode,
        details: details,
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppNetworkException(
          'Request timed out',
          code: 'TIMEOUT',
          details: details,
        );
      case DioExceptionType.unknown:
        if (error.error != null &&
            error.error.toString().contains('SocketException')) {
          return AppNetworkException(
            'No internet connection available',
            code: 'NO_CONNECTION',
            details: details,
          );
        }
        return AppNetworkException(
          'Network error during $operationName',
          details: details,
        );
      default:
        return AppNetworkException(
          'Network error during $operationName: ${error.message}',
          details: details,
        );
    }
  }

  /// Calculates retry delay using exponential backoff.
  static Duration _getRetryDelay(int attempt) {
    return Duration(milliseconds: 500 * (1 << attempt)); // 500ms, 1s, 2s
  }
}

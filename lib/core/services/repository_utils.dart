import 'dart:async';

import 'package:dio/dio.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/shared/logger.dart';

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
  /// [maxRetries] - Maximum number of retry attempts
  ///
  /// Returns the result of [apiCall] if successful.
  /// Throws [AppAuthException] for authentication errors.
  /// Throws [AppNetworkException] for network errors.
  /// Throws [AppDataException] for data/validation errors.
  static Future<T> handleApiCall<T>({
    required Future<T> Function() apiCall,
    required String operationName,
    bool retryOnNetworkError = false,
    int maxRetries = 2,
  }) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        return await apiCall();
      } catch (error, stackTrace) {
        // Don't retry on auth errors or client errors (4xx)
        if (error is AppAuthException) {
          rethrow;
        }

        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Error in $operationName',
        );

        if (error is DioException) {
          final statusCode = error.response?.statusCode;
          // Don't retry on client errors (4xx)
          if (statusCode != null && statusCode >= 400 && statusCode < 500) {
            attempt = maxRetries;
            rethrow;
          }
        }

        // Retry logic for network errors
        if (retryOnNetworkError &&
            attempt < maxRetries &&
            (error is AppNetworkException ||
                error is DioException ||
                error is TimeoutException)) {
          attempt++;
          logger.d('Retrying $operationName (attempt $attempt/$maxRetries)...');
          await Future<void>.delayed(_getRetryDelay(attempt - 1));
          continue;
        }

        // Convert DioException to app-specific exceptions
        if (error is DioException) {
          throw _convertDioException(error, operationName);
        }

        rethrow;
      }
    }
    throw AppNetworkException.noConnection();
  }

  /// Converts DioException to app-specific exceptions.
  static Exception _convertDioException(
    DioException error,
    String operationName,
  ) {
    final statusCode = error.response?.statusCode;

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
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return AppDataException(
        'Failed to $operationName',
        code: 'HTTP_ERROR_$statusCode',
        details: error.response?.data,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return AppNetworkException.serverError(
        statusCode,
        details: error.response?.data,
      );
    }

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
          'Network error during $operationName',
          details: error,
        );
      default:
        return AppNetworkException(
          'Network error during $operationName: ${error.message}',
          details: error,
        );
    }
  }

  /// Calculates retry delay using exponential backoff.
  static Duration _getRetryDelay(int attempt) {
    return Duration(milliseconds: 500 * (1 << attempt)); // 500ms, 1s, 2s
  }
}

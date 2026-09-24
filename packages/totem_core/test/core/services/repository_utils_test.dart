import 'dart:io';

import 'package:checks/checks.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart' show ApiError;
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/repository_utils.dart';

import '../../setup.dart';

void main() {
  setUp(() {
    setupAppConfig();
    silenceLogger();
  });

  group('RepositoryUtils.handleApiCall', () {
    test(
      'converts FormatException into AppDataException.invalidFormat',
      () async {
        try {
          await RepositoryUtils.handleApiCall<String>(
            apiCall: () async {
              throw const FormatException('Unexpected character');
            },
            operationName: 'request PIN',
          );
          fail('Expected AppDataException.invalidFormat to be thrown');
        } on AppDataException catch (error) {
          check(error.code).equals('INVALID_FORMAT');
          check(error.message).equals('Data is in an invalid format');
        }
      },
    );

    test('rethrows AppAuthException without wrapping it', () async {
      final authException = AppAuthException.invalidCredentials();

      check(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async {
            throw authException;
          },
          operationName: 'request PIN',
        ),
      ).throws((it) => it.identicalTo(authException));
    });

    test('converts DioException 401 into unauthenticated exception', () async {
      check(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async {
            throw DioException(
              requestOptions: RequestOptions(path: '/auth/request-pin'),
              response: Response<dynamic>(
                requestOptions: RequestOptions(path: '/auth/request-pin'),
                statusCode: 401,
                data: {'message': 'Unauthorized'},
              ),
              type: DioExceptionType.badResponse,
            );
          },
          operationName: 'request PIN',
        ),
      ).throws<AppAuthException>((error) {
        error.has((it) => it.code, 'code').equals('UNAUTHENTICATED');
        error
            .has((it) => it.message, 'message')
            .equals('User is not authenticated');
      });
    });

    test('converts DioException 403 into forbidden exception', () async {
      check(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async {
            throw DioException(
              requestOptions: RequestOptions(path: '/auth/request-pin'),
              response: Response<dynamic>(
                requestOptions: RequestOptions(path: '/auth/request-pin'),
                statusCode: 403,
                data: {'message': 'Forbidden'},
              ),
              type: DioExceptionType.badResponse,
            );
          },
          operationName: 'request PIN',
        ),
      ).throws<AppAuthException>((error) {
        error.has((it) => it.code, 'code').equals('FORBIDDEN');
        error.has((it) => it.message, 'message').equals('Access denied');
      });
    });

    test('converts DioException 400 into data exception', () async {
      check(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async {
            throw DioException(
              requestOptions: RequestOptions(path: '/auth/request-pin'),
              response: Response<dynamic>(
                requestOptions: RequestOptions(path: '/auth/request-pin'),
                statusCode: 400,
                data: {'message': 'Bad request'},
              ),
              type: DioExceptionType.badResponse,
            );
          },
          operationName: 'request PIN',
        ),
      ).throws<AppDataException>((error) {
        error.has((it) => it.code, 'code').equals('HTTP_ERROR_400');
        error
            .has((it) => it.message, 'message')
            .equals('Failed to request PIN');
      });
    });

    test('converts DioException socket failures into no connection', () async {
      check(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async {
            throw DioException(
              requestOptions: RequestOptions(path: '/auth/request-pin'),
              error: const SocketException('Failed host lookup'),
              type: DioExceptionType.unknown,
            );
          },
          operationName: 'request PIN',
        ),
      ).throws<AppNetworkException>((error) {
        error.has((it) => it.code, 'code').equals('NO_CONNECTION');
        error
            .has((it) => it.message, 'message')
            .equals('No internet connection available');
      });
    });

    test('reports a non-retried failure exactly once', () async {
      final failure = StateError('boom');
      var attempts = 0;
      var reports = 0;
      Object? reportedError;
      Map<String, Object?>? reportedDiagnostics;

      void report(
        Object error, {
        StackTrace? stackTrace,
        String? message,
        Map<String, Object?>? diagnostics,
      }) {
        reports++;
        reportedError = error;
        reportedDiagnostics = diagnostics;
      }

      await check(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async {
            attempts++;
            throw failure;
          },
          operationName: 'load a session',
          diagnostics: const {'event_slug': 'session-1'},
          errorReporter: report,
        ),
      ).throws((it) => it.identicalTo(failure));

      check(attempts).equals(1);
      check(reports).equals(1);
      check(reportedError).identicalTo(failure);
      check(reportedDiagnostics!['event_slug']).equals('session-1');
      check(reportedDiagnostics!['attempt']).equals(1);
      check(reportedDiagnostics!['total_attempts']).equals(1);
    });

    test('reports only the terminal failure after internal retries', () async {
      var attempts = 0;
      var reports = 0;
      Map<String, Object?>? reportedDiagnostics;

      await check(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async {
            attempts++;
            throw AppNetworkException('offline attempt $attempts');
          },
          operationName: 'load a session',
          retryOnNetworkError: true,
          maxRetries: 1,
          errorReporter: (error, {stackTrace, message, diagnostics}) {
            reports++;
            reportedDiagnostics = diagnostics;
          },
        ),
      ).throws<AppNetworkException>();

      check(attempts).equals(2);
      check(reports).equals(1);
      check(reportedDiagnostics!['attempt']).equals(2);
      check(reportedDiagnostics!['total_attempts']).equals(2);
    });

    test('does not report an expected domain response', () async {
      const conflict = ApiError<String, String>(
        statusCode: 409,
        error: 'overlapping session',
      );
      var reports = 0;

      await check(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async => conflict,
          operationName: 'confirm RSVP',
          shouldReport: (error) => false,
          errorReporter: (error, {stackTrace, message, diagnostics}) =>
              reports++,
        ),
      ).throws((it) => it.identicalTo(conflict));

      check(reports).equals(0);
    });

    test('reports and throws the same normalized network exception', () async {
      Object? reportedError;

      final future = RepositoryUtils.handleApiCall<String>(
        apiCall: () async {
          throw DioException(
            requestOptions: RequestOptions(
              path: '/spaces/session/session-1',
              method: 'GET',
            ),
            error: const SocketException('Failed host lookup'),
            type: DioExceptionType.unknown,
          );
        },
        operationName: 'load a session',
        errorReporter: (error, {stackTrace, message, diagnostics}) =>
            reportedError = error,
      );

      try {
        await future;
        fail('Expected a network exception');
      } on AppNetworkException catch (error) {
        check(error).identicalTo(reportedError! as AppNetworkException);
        check(error.code).equals('NO_CONNECTION');

        final details = error.details as Map<String, dynamic>;
        check(details['request_method']).equals('GET');
        check(details['request_path']).equals('/spaces/session/session-1');
      }
    });

    test(
      'preserves an AppException already classified by an interceptor',
      () async {
        final classifiedError = AppNetworkException.noConnection();
        Object? reportedError;

        await check(
          RepositoryUtils.handleApiCall<String>(
            apiCall: () async {
              throw DioException(
                requestOptions: RequestOptions(path: '/spaces'),
                error: classifiedError,
                type: DioExceptionType.unknown,
              );
            },
            operationName: 'list spaces',
            errorReporter: (error, {stackTrace, message, diagnostics}) =>
                reportedError = error,
          ),
        ).throws((it) => it.identicalTo(classifiedError));

        check(reportedError).identicalTo(classifiedError);
      },
    );
  });

  group('ErrorHandler', () {
    test('marks the same exception as reported only once', () {
      final error = StateError('one failure');

      check(ErrorHandler.logError(error)).equals(true);
      check(ErrorHandler.logError(error)).equals(false);
      check(ErrorHandler.wasReported(error)).equals(true);
    });

    test('reports separate factory exception occurrences independently', () {
      final factories = <String, Object Function()>{
        'network timeout': AppNetworkException.timeout,
        'no connection': AppNetworkException.noConnection,
        'unauthenticated': AppAuthException.unauthenticated,
        'token expired': AppAuthException.tokenExpired,
        'invalid credentials': AppAuthException.invalidCredentials,
        'magic link expired': AppAuthException.magicLinkExpired,
        'invalid PIN': AppAuthException.invalidPin,
        'PIN attempts exceeded': AppAuthException.pinAttemptsExceeded,
        'auth timeout': AppAuthException.timeout,
        'invalid format': AppDataException.invalidFormat,
        'missing data': AppDataException.missingData,
        'feature unavailable': AppFeatureException.notAvailable,
        'permission denied': AppFeatureException.permissionDenied,
        'video connection failed': VideoSessionException.connectionFailed,
        'media permission denied': VideoSessionException.mediaPermissionDenied,
        'session ended': VideoSessionException.sessionEnded,
      };

      for (final MapEntry(key: name, value: create) in factories.entries) {
        final first = create();
        final second = create();

        check(because: name, identical(first, second)).equals(false);
        check(because: name, ErrorHandler.logError(first)).equals(true);
        check(because: name, ErrorHandler.logError(first)).equals(false);
        check(because: name, ErrorHandler.wasReported(second)).equals(false);
        check(because: name, ErrorHandler.logError(second)).equals(true);
      }
    });

    test('safely reports values unsupported as Expando keys', () {
      final errors = <Object?>[
        'message',
        42,
        3.14,
        true,
        (code: 'failure'),
        null,
      ];

      for (final error in errors) {
        check(ErrorHandler.wasReported(error)).equals(false);
        check(ErrorHandler.logError(error)).equals(true);
        check(ErrorHandler.wasReported(error)).equals(false);
        check(ErrorHandler.logError(error)).equals(true);
      }
    });
  });
}

import 'dart:io';

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
          expect(error.code, 'INVALID_FORMAT');
          expect(error.message, 'Data is in an invalid format');
        }
      },
    );

    test('rethrows AppAuthException without wrapping it', () async {
      final authException = AppAuthException.invalidCredentials();

      expect(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async {
            throw authException;
          },
          operationName: 'request PIN',
        ),
        throwsA(same(authException)),
      );
    });

    test('converts DioException 401 into unauthenticated exception', () async {
      expect(
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
        throwsA(
          isA<AppAuthException>().having(
            (error) => error.code,
            'code',
            'UNAUTHENTICATED',
          ),
        ),
      );
    });

    test('converts DioException 403 into forbidden exception', () async {
      expect(
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
        throwsA(
          isA<AppAuthException>()
              .having((error) => error.code, 'code', 'FORBIDDEN')
              .having((error) => error.message, 'message', 'Access denied'),
        ),
      );
    });

    test('converts DioException 400 into data exception', () async {
      expect(
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
        throwsA(
          isA<AppDataException>()
              .having((error) => error.code, 'code', 'HTTP_ERROR_400')
              .having(
                (error) => error.message,
                'message',
                'Failed to request PIN',
              ),
        ),
      );
    });

    test('converts DioException socket failures into no connection', () async {
      expect(
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
        throwsA(
          isA<AppNetworkException>().having(
            (error) => error.code,
            'code',
            'NO_CONNECTION',
          ),
        ),
      );
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

      await expectLater(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async {
            attempts++;
            throw failure;
          },
          operationName: 'load a session',
          diagnostics: const {'event_slug': 'session-1'},
          errorReporter: report,
        ),
        throwsA(same(failure)),
      );

      expect(attempts, 1);
      expect(reports, 1);
      expect(reportedError, same(failure));
      expect(
        reportedDiagnostics,
        containsPair('event_slug', 'session-1'),
      );
      expect(reportedDiagnostics, containsPair('attempt', 1));
      expect(reportedDiagnostics, containsPair('total_attempts', 1));
    });

    test('reports only the terminal failure after internal retries', () async {
      var attempts = 0;
      var reports = 0;
      Map<String, Object?>? reportedDiagnostics;

      await expectLater(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async {
            attempts++;
            throw AppNetworkException('offline attempt $attempts');
          },
          operationName: 'load a session',
          retryOnNetworkError: true,
          maxRetries: 1,
          errorReporter:
              (
                error, {
                stackTrace,
                message,
                diagnostics,
              }) {
                reports++;
                reportedDiagnostics = diagnostics;
              },
        ),
        throwsA(isA<AppNetworkException>()),
      );

      expect(attempts, 2);
      expect(reports, 1);
      expect(reportedDiagnostics, containsPair('attempt', 2));
      expect(reportedDiagnostics, containsPair('total_attempts', 2));
    });

    test('does not report an expected domain response', () async {
      const conflict = ApiError<String, String>(
        statusCode: 409,
        error: 'overlapping session',
      );
      var reports = 0;

      await expectLater(
        RepositoryUtils.handleApiCall<String>(
          apiCall: () async => conflict,
          operationName: 'confirm RSVP',
          shouldReport: (error) => false,
          errorReporter:
              (
                error, {
                stackTrace,
                message,
                diagnostics,
              }) => reports++,
        ),
        throwsA(same(conflict)),
      );

      expect(reports, 0);
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
        errorReporter:
            (
              error, {
              stackTrace,
              message,
              diagnostics,
            }) => reportedError = error,
      );

      try {
        await future;
        fail('Expected a network exception');
      } on AppNetworkException catch (error) {
        expect(error, same(reportedError));
        expect(error.code, 'NO_CONNECTION');
        expect(error.details, containsPair('request_method', 'GET'));
        expect(
          error.details,
          containsPair('request_path', '/spaces/session/session-1'),
        );
      }
    });

    test(
      'preserves an AppException already classified by an interceptor',
      () async {
        final classifiedError = AppNetworkException.noConnection();
        Object? reportedError;

        await expectLater(
          RepositoryUtils.handleApiCall<String>(
            apiCall: () async {
              throw DioException(
                requestOptions: RequestOptions(path: '/spaces'),
                error: classifiedError,
                type: DioExceptionType.unknown,
              );
            },
            operationName: 'list spaces',
            errorReporter:
                (
                  error, {
                  stackTrace,
                  message,
                  diagnostics,
                }) => reportedError = error,
          ),
          throwsA(same(classifiedError)),
        );

        expect(reportedError, same(classifiedError));
      },
    );
  });

  group('ErrorHandler', () {
    test('marks the same exception as reported only once', () {
      final error = StateError('one failure');

      expect(ErrorHandler.logError(error), isTrue);
      expect(ErrorHandler.logError(error), isFalse);
      expect(ErrorHandler.wasReported(error), isTrue);
    });
  });
}

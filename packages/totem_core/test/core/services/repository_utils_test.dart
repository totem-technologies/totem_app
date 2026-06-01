import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/services/repository_utils.dart';

import '../../setup.dart';

void main() {
  setUp(setupAppConfig);

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
  });
}

import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/repositories/auth_repository.dart';
import 'package:totem_core/core/api/api_client/models/token_response.dart';
import 'package:totem_core/core/config/consts.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/services/api_service.dart';
import 'package:totem_core/core/services/secure_storage.dart';

import '../../setup.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockSecureStorage extends Mock implements SecureStorage {}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;
  DioException? failure;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (failure != null) throw failure!;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setupAppConfig();
  silenceLogger();

  late _MockAuthRepository authRepository;
  late _MockSecureStorage secureStorage;
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    authRepository = _MockAuthRepository();
    secureStorage = _MockSecureStorage();
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://test.example.com'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthTokenInterceptor(
          secureStorage: secureStorage,
          authRepository: authRepository,
        ),
      );

    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => secureStorage.delete(key: any(named: 'key')),
    ).thenAnswer((_) async {});
  });

  test('refreshes expired credentials and persists rotated tokens', () async {
    when(
      () => secureStorage.read(key: AppConsts.accessTokenKey),
    ).thenAnswer((_) async => 'expired-access');
    when(
      () => secureStorage.read(key: AppConsts.refreshTokenKey),
    ).thenAnswer((_) async => 'refresh-1');
    when(
      () => authRepository.isAccessTokenExpired('expired-access'),
    ).thenReturn(true);
    when(() => authRepository.refreshAccessToken('refresh-1')).thenAnswer(
      (_) async => const TokenResponse(
        accessToken: 'access-2',
        refreshToken: 'refresh-2',
        expiresIn: 3600,
      ),
    );

    await dio.get<void>('/protected');

    check(adapter.request!.headers['Authorization']).equals('Bearer access-2');
    verify(
      () =>
          secureStorage.write(key: AppConsts.accessTokenKey, value: 'access-2'),
    ).called(1);
    verify(
      () => secureStorage.write(
        key: AppConsts.refreshTokenKey,
        value: 'refresh-2',
      ),
    ).called(1);
  });

  test(
    'does not overwrite an authorization header supplied by the caller',
    () async {
      when(
        () => secureStorage.read(key: AppConsts.accessTokenKey),
      ).thenAnswer((_) async => 'valid-access');
      when(
        () => authRepository.isAccessTokenExpired('valid-access'),
      ).thenReturn(false);

      await dio.get<void>(
        '/protected',
        options: Options(headers: {'Authorization': 'Bearer caller-token'}),
      );

      check(
        adapter.request!.headers['Authorization'],
      ).equals('Bearer caller-token');
    },
  );

  test(
    'keeps credentials when refresh fails because the network is unavailable',
    () async {
      when(
        () => secureStorage.read(key: AppConsts.accessTokenKey),
      ).thenAnswer((_) async => 'expired-access');
      when(
        () => secureStorage.read(key: AppConsts.refreshTokenKey),
      ).thenAnswer((_) async => 'refresh-1');
      when(
        () => authRepository.isAccessTokenExpired('expired-access'),
      ).thenReturn(true);
      when(() => authRepository.refreshAccessToken('refresh-1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          type: DioExceptionType.connectionError,
        ),
      );
      adapter.failure = DioException(
        requestOptions: RequestOptions(path: '/protected'),
        type: DioExceptionType.connectionError,
      );

      await check(dio.get<void>('/protected')).throws<DioException>();

      verifyNever(() => secureStorage.delete(key: any(named: 'key')));
    },
  );

  test(
    'clears credentials when refresh is rejected as unauthenticated',
    () async {
      when(
        () => secureStorage.read(key: AppConsts.accessTokenKey),
      ).thenAnswer((_) async => 'expired-access');
      when(
        () => secureStorage.read(key: AppConsts.refreshTokenKey),
      ).thenAnswer((_) async => 'refresh-1');
      when(
        () => authRepository.isAccessTokenExpired('expired-access'),
      ).thenReturn(true);
      when(() => authRepository.refreshAccessToken('refresh-1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/auth/refresh'),
            statusCode: 401,
          ),
        ),
      );

      DioException? error;
      try {
        await dio.get<void>('/protected');
      } on DioException catch (caught) {
        error = caught;
      }

      check(error).isNotNull();
      check(error!.error).isA<AppAuthException>();
      verify(
        () => secureStorage.delete(key: AppConsts.accessTokenKey),
      ).called(1);
      verify(
        () => secureStorage.delete(key: AppConsts.refreshTokenKey),
      ).called(1);
    },
  );
}

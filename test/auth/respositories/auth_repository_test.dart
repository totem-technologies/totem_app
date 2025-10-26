// We need a few lines to be longer than 80 chars.
// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/auth/repositories/auth_repository.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';

class MockMobileTotemApi extends Mock implements MobileTotemApi {}

class MockUsersClient extends Mock implements UsersClient {}

class MockFallbackClient extends Mock implements FallbackClient {}

void main() {
  late MockMobileTotemApi mockMobileTotemApi;
  late MockUsersClient mockUsersClient;
  late MockFallbackClient mockFallbackClient;
  late AuthRepository authRepository;

  const testEmail = 'test@example.com';
  const testPin = '123456';
  const testRefreshToken = 'fake_refresh_token';
  const testFcmToken = 'fake_fcm_token';

  const testTokenResponse = TokenResponse(
    accessToken: 'fake_access_token',
    refreshToken: testRefreshToken,
    expiresIn: 3600,
  );

  final testUser = UserSchema(
    email: testEmail,
    name: 'Test User',
    profileAvatarType: ProfileAvatarTypeEnum.td,
    circleCount: 0,
    dateCreated: DateTime.now(),
  );

  const testOnboardSchema = OnboardSchema(
    hopes: 'test, interests',
    yearBorn: 1990,
  );

  const testPinRequest = PinRequestSchema(email: testEmail);
  const testValidatePin = ValidatePinSchema(email: testEmail, pin: testPin);
  const testRefreshTokenSchema = RefreshTokenSchema(
    refreshToken: testRefreshToken,
  );
  const testFcmTokenSchema = FcmTokenRegisterSchema(token: testFcmToken);
  final testFcmTokenResponse = FcmTokenResponseSchema(
    token: testFcmToken,
    active: true,
    createdAt: DateTime.now(),
  );

  setUp(() {
    mockMobileTotemApi = MockMobileTotemApi();
    mockUsersClient = MockUsersClient();
    mockFallbackClient = MockFallbackClient();

    when(() => mockMobileTotemApi.users).thenReturn(mockUsersClient);
    when(() => mockMobileTotemApi.fallback).thenReturn(mockFallbackClient);

    authRepository = AuthRepository(apiService: mockMobileTotemApi);

    registerFallbackValue(testPinRequest);
    registerFallbackValue(testValidatePin);
    registerFallbackValue(testRefreshTokenSchema);
    registerFallbackValue(testFcmTokenSchema);
    registerFallbackValue(const UserUpdateSchema());
    registerFallbackValue(const OnboardSchema(yearBorn: 1990, hopes: 'test'));
    registerFallbackValue(File('test_file.jpg'));
  });

  tearDown(() {
    reset(mockMobileTotemApi);
    reset(mockUsersClient);
    reset(mockFallbackClient);
  });

  group('AuthRepository Tests', () {
    group('requestPin', () {
      test('should call apiService.fallback.requestPin successfully', () async {
        when(
          () => mockFallbackClient.totemApiAuthRequestPin(
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => const MessageResponse(message: 'PIN sent successfully'),
        );

        final response = await authRepository.requestPin(testEmail, true);

        expect(response, isA<MessageResponse>());
        expect(response.message, equals('PIN sent successfully'));
        verify(
          () => mockFallbackClient.totemApiAuthRequestPin(
            body: any(named: 'body'),
          ),
        ).called(1);
      });

      test('should handle DioException with 401 status', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/auth/request-pin'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/request-pin'),
            statusCode: 401,
            data: 'Unauthorized',
          ),
        );

        when(
          () => mockFallbackClient.totemApiAuthRequestPin(
            body: any(named: 'body'),
          ),
        ).thenThrow(dioException);

        expect(
          () => authRepository.requestPin(testEmail, true),
          throwsA(isA<AppAuthException>()),
        );
      });

      test('should handle DioException with other status codes', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/auth/request-pin'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/request-pin'),
            statusCode: 500,
            data: 'Internal Server Error',
          ),
        );

        when(
          () => mockFallbackClient.totemApiAuthRequestPin(
            body: any(named: 'body'),
          ),
        ).thenThrow(dioException);

        expect(
          () => authRepository.requestPin(testEmail, true),
          throwsA(isA<AppAuthException>()),
        );
      });

      test('should handle DioException without response', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/auth/request-pin'),
        );

        when(
          () => mockFallbackClient.totemApiAuthRequestPin(
            body: any(named: 'body'),
          ),
        ).thenThrow(dioException);

        expect(
          () => authRepository.requestPin(testEmail, true),
          throwsA(isA<AppAuthException>()),
        );
      });
    });

    group('verifyPin', () {
      test(
        'should call apiService.fallback.validatePin successfully',
        () async {
          when(
            () => mockFallbackClient.totemApiAuthValidatePin(
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => testTokenResponse);

          final response = await authRepository.verifyPin(testEmail, testPin);

          expect(response, isA<TokenResponse>());
          expect(response.accessToken, equals('fake_access_token'));
          expect(response.refreshToken, equals(testRefreshToken));
          verify(
            () => mockFallbackClient.totemApiAuthValidatePin(
              body: any(named: 'body'),
            ),
          ).called(1);
        },
      );

      test('should handle DioException in verifyPin', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/auth/validate-pin'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/validate-pin'),
            statusCode: 400,
            data: 'Invalid PIN',
          ),
        );

        when(
          () => mockFallbackClient.totemApiAuthValidatePin(
            body: any(named: 'body'),
          ),
        ).thenThrow(dioException);

        expect(
          () => authRepository.verifyPin(testEmail, testPin),
          throwsA(isA<AppAuthException>()),
        );
      });
    });

    group('logout', () {
      test('should call apiService.fallback.logout successfully', () async {
        when(
          () => mockFallbackClient.totemApiAuthLogout(
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async =>
              const MessageResponse(message: 'Logged out successfully'),
        );

        final response = await authRepository.logout(testRefreshToken);

        expect(response, isA<MessageResponse>());
        expect(response.message, equals('Logged out successfully'));
        verify(
          () => mockFallbackClient.totemApiAuthLogout(
            body: any(named: 'body'),
          ),
        ).called(1);
      });

      test('should handle DioException in logout', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/auth/logout'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/logout'),
            statusCode: 500,
            data: 'Logout failed',
          ),
        );

        when(
          () => mockFallbackClient.totemApiAuthLogout(
            body: any(named: 'body'),
          ),
        ).thenThrow(dioException);

        expect(
          () => authRepository.logout(testRefreshToken),
          throwsA(isA<AppAuthException>()),
        );
      });
    });

    group('currentUser', () {
      test(
        'should call apiService.users.getCurrentUser successfully',
        () async {
          when(
            () => mockUsersClient.totemUsersMobileApiGetCurrentUser(),
          ).thenAnswer((_) async => testUser);

          final response = await authRepository.currentUser;

          expect(response, isA<UserSchema>());
          expect(response.email, equals(testEmail));
          verify(
            () => mockUsersClient.totemUsersMobileApiGetCurrentUser(),
          ).called(1);
        },
      );

      test('should handle DioException in currentUser', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/users/current'),
          response: Response(
            requestOptions: RequestOptions(path: '/users/current'),
            statusCode: 401,
            data: 'Unauthorized',
          ),
        );

        when(
          () => mockUsersClient.totemUsersMobileApiGetCurrentUser(),
        ).thenThrow(dioException);

        expect(
          () => authRepository.currentUser,
          throwsA(isA<AppAuthException>()),
        );
      });
    });

    group('updateCurrentUserProfile', () {
      test(
        'should call apiService.users.updateCurrentUser successfully',
        () async {
          final updatedUser = UserSchema(
            email: 'updated@example.com',
            name: 'Updated User',
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime.now(),
          );

          when(
            () => mockUsersClient.totemUsersMobileApiUpdateCurrentUser(
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => updatedUser);

          final response = await authRepository.updateCurrentUserProfile(
            name: 'Updated User',
            email: 'updated@example.com',
          );

          expect(response, isA<UserSchema>());
          expect(response.name, equals('Updated User'));
          expect(response.email, equals('updated@example.com'));
          verify(
            () => mockUsersClient.totemUsersMobileApiUpdateCurrentUser(
              body: any(named: 'body'),
            ),
          ).called(1);
        },
      );

      test('should handle DioException in updateCurrentUserProfile', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/users/current'),
          response: Response(
            requestOptions: RequestOptions(path: '/users/current'),
            statusCode: 400,
            data: 'Invalid data',
          ),
        );

        when(
          () => mockUsersClient.totemUsersMobileApiUpdateCurrentUser(
            body: any(named: 'body'),
          ),
        ).thenThrow(dioException);

        expect(
          () => authRepository.updateCurrentUserProfile(name: 'Test'),
          throwsA(isA<AppAuthException>()),
        );
      });
    });

    group('updateCurrentUserProfilePicture', () {
      test(
        'should call apiService.users.updateCurrentUserImage successfully',
        () async {
          final testFile = File('test_image.jpg');

          when(
            () => mockUsersClient.totemUsersMobileApiUpdateCurrentUserImage(
              profileImage: any(named: 'profileImage'),
            ),
          ).thenAnswer((_) async => true);

          final response = await authRepository.updateCurrentUserProfilePicture(
            testFile,
          );

          expect(response, isTrue);
          verify(
            () => mockUsersClient.totemUsersMobileApiUpdateCurrentUserImage(
              profileImage: any(named: 'profileImage'),
            ),
          ).called(1);
        },
      );

      test(
        'should handle DioException in updateCurrentUserProfilePicture',
        () async {
          final testFile = File('test_image.jpg');
          final dioException = DioException(
            requestOptions: RequestOptions(path: '/users/current/image'),
            response: Response(
              requestOptions: RequestOptions(path: '/users/current/image'),
              statusCode: 413,
              data: 'File too large',
            ),
          );

          when(
            () => mockUsersClient.totemUsersMobileApiUpdateCurrentUserImage(
              profileImage: any(named: 'profileImage'),
            ),
          ).thenThrow(dioException);

          expect(
            () => authRepository.updateCurrentUserProfilePicture(testFile),
            throwsA(isA<AppAuthException>()),
          );
        },
      );
    });

    group('onboardStatus', () {
      test('should call apiService.fallback.getOnboard successfully', () async {
        when(
          () => mockFallbackClient.totemOnboardMobileApiOnboardGet(),
        ).thenAnswer((_) async => testOnboardSchema);

        final response = await authRepository.onboardStatus;

        expect(response, isA<OnboardSchema>());
        expect(response.referralSource, equals(ReferralChoices.valueDefault));
        verify(
          () => mockFallbackClient.totemOnboardMobileApiOnboardGet(),
        ).called(1);
      });

      test('should handle DioException in onboardStatus', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/onboard'),
          response: Response(
            requestOptions: RequestOptions(path: '/onboard'),
            statusCode: 500,
            data: 'Server error',
          ),
        );

        when(
          () => mockFallbackClient.totemOnboardMobileApiOnboardGet(),
        ).thenThrow(dioException);

        expect(
          () => authRepository.onboardStatus,
          throwsA(isA<AppAuthException>()),
        );
      });
    });

    group('completeOnboarding', () {
      test(
        'should call apiService.fallback.postOnboard successfully',
        () async {
          when(
            () => mockFallbackClient.totemOnboardMobileApiOnboardPost(
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => testOnboardSchema);

          final response = await authRepository.completeOnboarding(
            referralSource: ReferralChoices.valueDefault,
            interestTopics: {'test', 'interests'},
            yearBorn: 1990,
          );

          expect(response, isA<OnboardSchema>());
          verify(
            () => mockFallbackClient.totemOnboardMobileApiOnboardPost(
              body: any(named: 'body'),
            ),
          ).called(1);
        },
      );

      test('should handle DioException in completeOnboarding', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/onboard'),
          response: Response(
            requestOptions: RequestOptions(path: '/onboard'),
            statusCode: 400,
            data: 'Invalid onboarding data',
          ),
        );

        when(
          () => mockFallbackClient.totemOnboardMobileApiOnboardPost(
            body: any(named: 'body'),
          ),
        ).thenThrow(dioException);

        expect(
          () => authRepository.completeOnboarding(
            referralSource: ReferralChoices.valueDefault,
            interestTopics: {'test'},
          ),
          throwsA(isA<AppAuthException>()),
        );
      });
    });

    group('deleteAccount', () {
      test(
        'should call apiService.users.deleteCurrentUser successfully',
        () async {
          when(
            () => mockUsersClient.totemUsersMobileApiDeleteCurrentUser(),
          ).thenAnswer((_) async => true);

          await authRepository.deleteAccount();

          verify(
            () => mockUsersClient.totemUsersMobileApiDeleteCurrentUser(),
          ).called(1);
        },
      );

      test('should handle DioException in deleteAccount', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/users/current'),
          response: Response(
            requestOptions: RequestOptions(path: '/users/current'),
            statusCode: 500,
            data: 'Deletion failed',
          ),
        );

        when(
          () => mockUsersClient.totemUsersMobileApiDeleteCurrentUser(),
        ).thenThrow(dioException);

        expect(
          () => authRepository.deleteAccount(),
          throwsA(isA<AppAuthException>()),
        );
      });
    });

    group('updateFcmToken', () {
      test(
        'should call apiService.fallback.registerFcmToken successfully',
        () async {
          when(
            () => mockFallbackClient.totemApiMobileApiRegisterFcmToken(
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => testFcmTokenResponse);

          await authRepository.updateFcmToken(testFcmToken);

          verify(
            () => mockFallbackClient.totemApiMobileApiRegisterFcmToken(
              body: any(named: 'body'),
            ),
          ).called(1);
        },
      );

      test('should handle DioException in updateFcmToken', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/fcm/register'),
          response: Response(
            requestOptions: RequestOptions(path: '/fcm/register'),
            statusCode: 400,
            data: 'Invalid token',
          ),
        );

        when(
          () => mockFallbackClient.totemApiMobileApiRegisterFcmToken(
            body: any(named: 'body'),
          ),
        ).thenThrow(dioException);

        expect(
          () => authRepository.updateFcmToken(testFcmToken),
          throwsA(isA<AppAuthException>()),
        );
      });
    });

    group('unregisterFcmToken', () {
      test(
        'should call apiService.fallback.unregisterFcmToken successfully',
        () async {
          when(
            () => mockFallbackClient.totemApiMobileApiUnregisterFcmToken(
              token: any(named: 'token'),
            ),
          ).thenAnswer((_) async {});

          await authRepository.unregisterFcmToken(testFcmToken);

          verify(
            () => mockFallbackClient.totemApiMobileApiUnregisterFcmToken(
              token: any(named: 'token'),
            ),
          ).called(1);
        },
      );

      test('should handle DioException in unregisterFcmToken', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/fcm/unregister'),
          response: Response(
            requestOptions: RequestOptions(path: '/fcm/unregister'),
            statusCode: 404,
            data: 'Token not found',
          ),
        );

        when(
          () => mockFallbackClient.totemApiMobileApiUnregisterFcmToken(
            token: any(named: 'token'),
          ),
        ).thenThrow(dioException);

        expect(
          () => authRepository.unregisterFcmToken(testFcmToken),
          throwsA(isA<AppAuthException>()),
        );
      });
    });

    group('Static Methods', () {
      group('isAuthenticated', () {
        test('should return false for null token', () {
          expect(AuthRepository.isAuthenticated(null), isFalse);
        });

        test('should return false for expired token', () {
          // Create an expired JWT token
          const expiredToken =
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
          expect(AuthRepository.isAuthenticated(expiredToken), isFalse);
        });

        test('should return true for valid token', () {
          // Create a valid JWT token (expires in 1 hour)
          final futureTime = DateTime.now().add(const Duration(hours: 1));
          final exp = (futureTime.millisecondsSinceEpoch / 1000).round();
          // Create proper base64 encoded payload
          final payloadJson =
              '{"sub":"1234567890","name":"John Doe","iat":1516239022,"exp":$exp}';
          final payload = base64Url.encode(utf8.encode(payloadJson));
          const header = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
          const signature = 'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
          final validToken = '$header.$payload.$signature';
          expect(AuthRepository.isAuthenticated(validToken), isTrue);
        });
      });

      group('isAccessTokenExpired', () {
        test('should return true for null token', () {
          expect(AuthRepository.isAccessTokenExpired(null), isTrue);
        });

        test('should return true for invalid token format', () {
          expect(AuthRepository.isAccessTokenExpired('invalid.token'), isTrue);
        });

        test('should return true for expired token', () {
          const expiredToken =
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
          expect(AuthRepository.isAccessTokenExpired(expiredToken), isTrue);
        });

        test('should return false for valid token', () {
          final futureTime = DateTime.now().add(const Duration(hours: 1));
          final exp = (futureTime.millisecondsSinceEpoch / 1000).round();
          // Create proper base64 encoded payload
          final payloadJson =
              '{"sub":"1234567890","name":"John Doe","iat":1516239022,"exp":$exp}';
          final payload = base64Url.encode(utf8.encode(payloadJson));
          const header = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
          const signature = 'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
          final validToken = '$header.$payload.$signature';
          expect(AuthRepository.isAccessTokenExpired(validToken), isFalse);
        });
      });
    });
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
import 'package:totem_app/api/models/profile_avatar_type_enum.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/api/users/users_client.dart';

class MockUsersClient extends Mock implements UsersClient {}

class MockMobileTotemApi extends Mock implements MobileTotemApi {}

Future<PublicUserSchema> testGetUserProfile(
  MobileTotemApi apiService,
  String slug,
) async {
  return apiService.users.totemUsersMobileApiGetUserProfile(userSlug: slug);
}

void main() {
  group('User Repository Tests', () {
    late MockUsersClient mockUsersClient;
    late MockMobileTotemApi mockMobileTotemApi;

    setUpAll(() {
      registerFallbackValue(
        PublicUserSchema(
          profileAvatarType: ProfileAvatarTypeEnum.td,
          dateCreated: DateTime.now(),
          slug: 'test-user',
          name: 'Test User',
        ),
      );
    });

    setUp(() {
      mockUsersClient = MockUsersClient();
      mockMobileTotemApi = MockMobileTotemApi();

      when(() => mockMobileTotemApi.users).thenReturn(mockUsersClient);
    });

    group('userProfile', () {
      test('should return user profile successfully', () async {
        const testSlug = 'test-user-slug';
        final testUserProfile = PublicUserSchema(
          slug: testSlug,
          name: 'Test User Name',
          profileAvatarType: ProfileAvatarTypeEnum.td,
          dateCreated: DateTime.now(),
        );

        when(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: any(named: 'userSlug'),
          ),
        ).thenAnswer((_) async => testUserProfile);

        final result = await testGetUserProfile(mockMobileTotemApi, testSlug);

        expect(result, equals(testUserProfile));
        expect(result.slug, equals(testSlug));
        expect(result.name, equals('Test User Name'));
        verify(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: testSlug,
          ),
        ).called(1);
      });

      test('should handle DioException in userProfile', () async {
        const testSlug = 'test-user-slug';
        when(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: any(named: 'userSlug'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/users/$testSlug'),
            response: Response(
              requestOptions: RequestOptions(path: '/users/$testSlug'),
              statusCode: 404,
            ),
          ),
        );

        expect(
          () => testGetUserProfile(mockMobileTotemApi, testSlug),
          throwsA(isA<DioException>()),
        );
        verify(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: testSlug,
          ),
        ).called(1);
      });
    });
  });
}

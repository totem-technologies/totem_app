import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
import 'package:totem_app/api/models/keeper_profile_schema.dart';
import 'package:totem_app/api/models/profile_avatar_type_enum.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/api/users/users_client.dart';

class MockUsersClient extends Mock implements UsersClient {}

class MockMobileTotemApi extends Mock implements MobileTotemApi {}

Future<KeeperProfileSchema> testGetKeeperProfile(
  MobileTotemApi apiService,
  String slug,
) async {
  return apiService.users.totemUsersMobileApiKeeper(slug: slug);
}

void main() {
  group('Keeper Repository Tests', () {
    late MockUsersClient mockUsersClient;
    late MockMobileTotemApi mockMobileTotemApi;

    setUpAll(() {
      registerFallbackValue(
        KeeperProfileSchema(
          user: PublicUserSchema(
            profileAvatarType: ProfileAvatarTypeEnum.td,
            dateCreated: DateTime.now(),
            slug: 'test-keeper',
            name: 'Test Keeper',
          ),
          circleCount: 5,
          monthJoined: 'January 2024',
          bio: 'Test bio',
        ),
      );
    });

    setUp(() {
      mockUsersClient = MockUsersClient();
      mockMobileTotemApi = MockMobileTotemApi();

      when(() => mockMobileTotemApi.users).thenReturn(mockUsersClient);
    });

    group('keeperProfile', () {
      test('should return keeper profile successfully', () async {
        const testSlug = 'test-keeper-slug';
        final testKeeperProfile = KeeperProfileSchema(
          user: PublicUserSchema(
            profileAvatarType: ProfileAvatarTypeEnum.td,
            dateCreated: DateTime.now(),
            slug: testSlug,
            name: 'Test Keeper Name',
          ),
          circleCount: 10,
          monthJoined: 'January 2024',
          bio: 'Test keeper bio',
        );

        when(
          () => mockUsersClient.totemUsersMobileApiKeeper(
            slug: any(named: 'slug'),
          ),
        ).thenAnswer((_) async => testKeeperProfile);

        final result = await testGetKeeperProfile(mockMobileTotemApi, testSlug);

        expect(result, equals(testKeeperProfile));
        expect(result.user.slug, equals(testSlug));
        expect(result.user.name, equals('Test Keeper Name'));
        expect(result.bio, equals('Test keeper bio'));
        verify(
          () => mockUsersClient.totemUsersMobileApiKeeper(slug: testSlug),
        ).called(1);
      });

      test('should handle DioException in keeperProfile', () async {
        const testSlug = 'test-keeper-slug';
        when(
          () => mockUsersClient.totemUsersMobileApiKeeper(
            slug: any(named: 'slug'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/keepers/$testSlug'),
            response: Response(
              requestOptions: RequestOptions(path: '/keepers/$testSlug'),
              statusCode: 404,
            ),
          ),
        );

        expect(
          () => testGetKeeperProfile(mockMobileTotemApi, testSlug),
          throwsA(isA<DioException>()),
        );
        verify(
          () => mockUsersClient.totemUsersMobileApiKeeper(slug: testSlug),
        ).called(1);
      });
    });
  });
}

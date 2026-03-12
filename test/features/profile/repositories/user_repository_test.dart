import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
import 'package:totem_app/api/models/profile_avatar_type_enum.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/api/users/users_client.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';

import '../../../setup.dart';

class MockUsersClient extends Mock implements UsersClient {}

class MockMobileTotemApi extends Mock implements MobileTotemApi {}

void main() {
  group('User Repository Tests', () {
    late MockUsersClient mockUsersClient;
    late MockMobileTotemApi mockMobileTotemApi;
    late PublicUserProfileCache cache;
    late DateTime now;

    PublicUserSchema buildUser(String slug, String name) {
      return PublicUserSchema(
        slug: slug,
        name: name,
        profileAvatarType: ProfileAvatarTypeEnum.td,
        dateCreated: now,
      );
    }

    setUpAll(() {
      setupDotenv();
      silenceLogger();
    });

    setUp(() {
      mockUsersClient = MockUsersClient();
      mockMobileTotemApi = MockMobileTotemApi();
      now = DateTime(2026, 3, 10, 12);
      cache = PublicUserProfileCache(now: () => now);

      when(() => mockMobileTotemApi.users).thenReturn(mockUsersClient);
    });

    group('PublicUserProfileCache', () {
      test('caches a fetched profile within the TTL', () async {
        const testSlug = 'test-user-slug';
        final testUserProfile = buildUser(testSlug, 'Test User Name');

        when(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: any(named: 'userSlug'),
          ),
        ).thenAnswer((_) async => testUserProfile);

        final result1 = await cache.getProfile(mockMobileTotemApi, testSlug);
        now = now.add(const Duration(minutes: 5));
        final result2 = await cache.getProfile(mockMobileTotemApi, testSlug);

        expect(result1, equals(testUserProfile));
        expect(result2, equals(testUserProfile));
        verify(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: testSlug,
          ),
        ).called(1);
      });

      test('refetches a profile after the TTL expires', () async {
        const testSlug = 'test-user-slug';
        final firstProfile = buildUser(testSlug, 'First Name');
        final secondProfile = buildUser(testSlug, 'Updated Name');
        final responses = <PublicUserSchema>[firstProfile, secondProfile];

        when(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: any(named: 'userSlug'),
          ),
        ).thenAnswer((_) async => responses.removeAt(0));

        final result1 = await cache.getProfile(mockMobileTotemApi, testSlug);
        now = now.add(userProfileCacheTtl + const Duration(seconds: 1));
        final result2 = await cache.getProfile(mockMobileTotemApi, testSlug);

        expect(result1.name, 'First Name');
        expect(result2.name, 'Updated Name');
        verify(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: testSlug,
          ),
        ).called(2);
      });

      test('dedupes concurrent requests for the same slug', () async {
        const testSlug = 'test-user-slug';
        final completer = Completer<PublicUserSchema>();

        when(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: any(named: 'userSlug'),
          ),
        ).thenAnswer((_) => completer.future);

        final future1 = cache.getProfile(mockMobileTotemApi, testSlug);
        final future2 = cache.getProfile(mockMobileTotemApi, testSlug);

        expect(identical(future1, future2), isTrue);

        completer.complete(buildUser(testSlug, 'Test User Name'));

        final results = await Future.wait([future1, future2]);
        expect(results[0].name, 'Test User Name');
        expect(results[1].name, 'Test User Name');
        verify(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: testSlug,
          ),
        ).called(1);
      });

      test('propagates DioException and clears the inflight request', () async {
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

        await expectLater(
          () => cache.getProfile(mockMobileTotemApi, testSlug),
          throwsA(isA<DioException>()),
        );

        await expectLater(
          () => cache.getProfile(mockMobileTotemApi, testSlug),
          throwsA(isA<DioException>()),
        );

        verify(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: testSlug,
          ),
        ).called(2);
      });
    });

    group('userProfile provider', () {
      ProviderContainer createContainer() {
        return ProviderContainer(
          overrides: [
            mobileApiServiceProvider.overrideWithValue(mockMobileTotemApi),
            publicUserProfileCacheProvider.overrideWithValue(cache),
          ],
        );
      }

      test(
        'reuses cached data after provider invalidation within TTL',
        () async {
          const testSlug = 'test-user-slug';
          final testUserProfile = buildUser(testSlug, 'Test User Name');

          when(
            () => mockUsersClient.totemUsersMobileApiGetUserProfile(
              userSlug: any(named: 'userSlug'),
            ),
          ).thenAnswer((_) async => testUserProfile);

          final container = createContainer();
          addTearDown(container.dispose);

          final result1 = await container.read(
            userProfileProvider(testSlug).future,
          );
          container.invalidate(userProfileProvider(testSlug));
          final result2 = await container.read(
            userProfileProvider(testSlug).future,
          );

          expect(result1.name, 'Test User Name');
          expect(result2.name, 'Test User Name');
          verify(
            () => mockUsersClient.totemUsersMobileApiGetUserProfile(
              userSlug: testSlug,
            ),
          ).called(1);
        },
      );

      test('refetches after TTL once the provider is invalidated', () async {
        const testSlug = 'test-user-slug';
        final firstProfile = buildUser(testSlug, 'First Name');
        final secondProfile = buildUser(testSlug, 'Updated Name');
        final responses = <PublicUserSchema>[firstProfile, secondProfile];

        when(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: any(named: 'userSlug'),
          ),
        ).thenAnswer((_) async => responses.removeAt(0));

        final container = createContainer();
        addTearDown(container.dispose);

        final result1 = await container.read(
          userProfileProvider(testSlug).future,
        );
        now = now.add(userProfileCacheTtl + const Duration(seconds: 1));
        container.invalidate(userProfileProvider(testSlug));
        final result2 = await container.read(
          userProfileProvider(testSlug).future,
        );

        expect(result1.name, 'First Name');
        expect(result2.name, 'Updated Name');
        verify(
          () => mockUsersClient.totemUsersMobileApiGetUserProfile(
            userSlug: testSlug,
          ),
        ).called(2);
      });
    });
  });
}

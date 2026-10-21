import 'dart:io';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/controllers/user_profile_controller.dart';
import 'package:totem_core/auth/repositories/user_profile_repository.dart';

import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/services/analytics_service.dart';
import 'package:totem_core/core/services/local_storage_service.dart';

import '../auth/controllers/auth_test_support.dart';

class _MockAuthController extends Mock implements MobileAuthController {}

class _MockFile extends Mock implements File {}

void main() {
  setUpAll(() {
    AppConfig.instance = AppConfig(
      environment: Environment.development,
      apiUrl: 'https://test.example.com/',
      liveKitUrl: 'wss://test.livekit.cloud',
      maxPinAttempts: 5,
      vapidKey: null,
      analyticsEnabled: false,
      sentryDsn: null,
      posthogApiKey: null,
      posthogHost: 'https://us.i.posthog.com',
      privacyPolicyUrl: Uri.parse('https://example.com/privacy'),
      termsOfServiceUrl: Uri.parse('https://example.com/tos'),
      communityGuidelinesUrl: Uri.parse('https://example.com/guidelines'),
    );
  });

  late MockUserRepository repository;
  late MockAnalyticsService analytics;
  late _MockAuthController auth;
  late MockLocalStorageService localStorage;
  late ProviderContainer container;

  setUp(() {
    repository = MockUserRepository();
    analytics = MockAnalyticsService();
    auth = _MockAuthController();
    localStorage = MockLocalStorageService();
    container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(repository),
        analyticsProvider.overrideWithValue(analytics),
        mobileAuthControllerProvider.overrideWithValue(auth),
        localStorageServiceProvider.overrideWithValue(localStorage),
      ],
    );
    when(() => auth.isAuthenticated).thenReturn(true);
    when(
      () => auth.user,
    ).thenReturn(testUserSchema(slug: 'user', name: 'Alex'));
  });

  tearDown(() => container.dispose());

  UserProfileController controller() =>
      container.read(userProfileControllerProvider.notifier);

  test(
    'profile image failure is reported and a later retry can succeed',
    () async {
      final file = _MockFile();
      final refreshed = testUserSchema(
        slug: 'user',
        name: 'Alex',
        profileAvatarSeed: 'new-seed',
      );
      when(
        () => repository.updateCurrentUserProfilePicture(file),
      ).thenThrow(StateError('upload failed'));

      check(
        await controller().updateUserProfile(profileImage: file),
      ).equals(false);

      reset(repository);
      when(
        () => repository.updateCurrentUserProfilePicture(file),
      ).thenAnswer((_) async => true);
      when(() => repository.currentUser).thenAnswer((_) async => refreshed);

      check(
        await controller().updateUserProfile(profileImage: file),
      ).equals(true);
      verify(() => auth.syncUser(refreshed)).called(1);
    },
  );

  test(
    'profile metadata failure does not sync a partial user and can recover',
    () async {
      final updated = testUserSchema(slug: 'user', name: 'New name');
      when(
        () => repository.updateCurrentUserProfile(
          name: 'New name',
          email: any(named: 'email'),
          profileAvatarType: any(named: 'profileAvatarType'),
          avatarSeed: any(named: 'avatarSeed'),
        ),
      ).thenThrow(StateError('save failed'));

      check(
        await controller().updateUserProfile(name: 'New name'),
      ).equals(false);

      reset(repository);
      when(
        () => repository.updateCurrentUserProfile(
          name: 'New name',
          email: any(named: 'email'),
          profileAvatarType: any(named: 'profileAvatarType'),
          avatarSeed: any(named: 'avatarSeed'),
        ),
      ).thenAnswer((_) async => updated);

      check(
        await controller().updateUserProfile(name: 'New name'),
      ).equals(true);
      verify(() => auth.syncUser(updated)).called(1);
    },
  );

  test(
    'refresh failure after an image update is surfaced as a failed save',
    () async {
      final file = _MockFile();
      when(
        () => repository.updateCurrentUserProfilePicture(file),
      ).thenAnswer((_) async => true);
      when(
        () => repository.currentUser,
      ).thenThrow(StateError('refresh failed'));

      check(
        await controller().updateUserProfile(profileImage: file),
      ).equals(false);
    },
  );
}

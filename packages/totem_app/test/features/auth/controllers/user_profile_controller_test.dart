import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/controllers/user_profile_controller.dart';
import 'package:totem_core/auth/repositories/user_profile_repository.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/analytics_service.dart';
import 'package:totem_core/core/services/local_storage_service.dart';

// --- Mocks ---
class MockUserRepository extends Mock implements UserRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockMobileAuthController extends Mock implements MobileAuthController {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockFile extends Mock implements File {}

UserSchema _buildUserSchema(
  String slug,
  String name, {
  String? profileAvatarSeed,
  String? email,
}) {
  return UserSchema(
    slug: slug,
    name: name,
    profileAvatarType: ProfileAvatarTypeEnum.td,
    circleCount: 0,
    isStaff: false,
    apiKey: null,
    profileAvatarSeed: profileAvatarSeed,
    profileImage: null,
    email: email ?? '',
    dateCreated: DateTime.now(),
  );
}

void main() {
  late MockUserRepository mockUserRepository;
  late MockAnalyticsService mockAnalyticsService;
  late MockMobileAuthController mockAuthController;
  late MockLocalStorageService mockLocalStorageService;
  late ProviderContainer container;

  setUp(() {
    mockUserRepository = MockUserRepository();
    mockAnalyticsService = MockAnalyticsService();
    mockAuthController = MockMobileAuthController();
    mockLocalStorageService = MockLocalStorageService();

    container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWithValue(mockUserRepository),
        analyticsProvider.overrideWithValue(mockAnalyticsService),
        mobileAuthControllerProvider.overrideWithValue(mockAuthController),
        localStorageServiceProvider.overrideWithValue(mockLocalStorageService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  UserProfileController getController() =>
      container.read(userProfileControllerProvider.notifier);

  group('UserProfileController - Welcome Onboarding', () {
    test('hasSeenWelcomeOnboarding returns value from local storage', () async {
      when(
        () => mockLocalStorageService.hasSeenWelcomeOnboarding(),
      ).thenAnswer((_) async => true);

      final result = await getController().hasSeenWelcomeOnboarding;

      expect(result, isTrue);
      verify(
        () => mockLocalStorageService.hasSeenWelcomeOnboarding(),
      ).called(1);
    });

    test(
      'markWelcomeOnboardingCompleted updates local storage and logs event',
      () async {
        when(
          () => mockLocalStorageService.markWelcomeOnboardingCompleted(),
        ).thenAnswer((_) async {});
        when(
          () => mockAnalyticsService.logEvent(
            any(),
            parameters: any(named: 'parameters'),
          ),
        ).thenReturn(null);

        await getController().markWelcomeOnboardingCompleted();

        verify(
          () => mockLocalStorageService.markWelcomeOnboardingCompleted(),
        ).called(1);
        verify(
          () => mockAnalyticsService.logEvent('welcome_onboarding_completed'),
        ).called(1);
      },
    );
  });

  group('UserProfileController - completeOnboarding', () {
    test('throws Exception if user is unauthenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      when(() => mockAuthController.user).thenReturn(null);

      expectLater(
        () => getController().completeOnboarding(
          firstName: 'John',
          age: 30,
          referralSource: null,
          interestTopics: {'Sports'},
          newsletterConsent: true,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('successfully completes onboarding and syncs user', () async {
      final mockUser = _buildUserSchema('1', 'John');
      final mockUpdatedUser = _buildUserSchema('1', 'John Doe');

      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      when(() => mockAuthController.user).thenReturn(mockUser);

      when(
        () => mockUserRepository.updateCurrentUserProfile(
          name: any(named: 'name'),
          newsletterConsent: any(named: 'newsletterConsent'),
        ),
      ).thenAnswer((_) async => mockUpdatedUser);

      when(
        () => mockUserRepository.completeOnboarding(
          interestTopics: any(named: 'interestTopics'),
          referralSource: any(named: 'referralSource'),
          referralOther: any(named: 'referralOther'),
          yearBorn: any(named: 'yearBorn'),
        ),
      ).thenAnswer((_) async => OnboardSchema(hopes: 'Sports'));

      when(
        () => mockAnalyticsService.logEvent(
          any(),
          parameters: any(named: 'parameters'),
        ),
      ).thenReturn(null);

      await getController().completeOnboarding(
        firstName: 'John Doe',
        age: 30,
        referralSource: null,
        interestTopics: {'Sports'},
        newsletterConsent: true,
      );

      verify(() => mockAuthController.syncUser(mockUpdatedUser)).called(1);
      verify(
        () => mockAnalyticsService.logEvent('onboarding_completed'),
      ).called(1);

      expect(
        container.read(userProfileControllerProvider),
        const AsyncData<void>(null),
      );
    });
  });

  group('UserProfileController - updateUserProfile', () {
    test('throws assertion error if unauthenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(false);

      expectLater(
        () => getController().updateUserProfile(name: 'Jane'),
        throwsA(isA<Exception>()),
      );
    });

    test('updates image successfully and fetches refreshed user', () async {
      final mockUser = _buildUserSchema('1', 'John');
      final mockRefreshedUser = _buildUserSchema(
        '1',
        'John',
        profileAvatarSeed: 'new_seed',
      );
      final mockFile = MockFile();

      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      when(() => mockAuthController.user).thenReturn(mockUser);

      when(
        () => mockUserRepository.updateCurrentUserProfilePicture(mockFile),
      ).thenAnswer((_) async => true);

      when(
        () => mockUserRepository.currentUser,
      ).thenAnswer((_) async => mockRefreshedUser);

      final success = await getController().updateUserProfile(
        profileImage: mockFile,
      );

      expect(success, isTrue);
      verify(
        () => mockUserRepository.updateCurrentUserProfilePicture(mockFile),
      ).called(1);
      verify(() => mockUserRepository.currentUser).called(1);
      verify(() => mockAuthController.syncUser(mockRefreshedUser)).called(1);
    });

    test(
      'updates meta profile data successfully and syncs user directly',
      () async {
        final mockUser = _buildUserSchema('1', 'John');
        final mockUpdatedUser = _buildUserSchema(
          '1',
          'John Doe',
          email: 'john@doe.com',
        );

        when(() => mockAuthController.isAuthenticated).thenReturn(true);
        when(() => mockAuthController.user).thenReturn(mockUser);

        when(
          () => mockUserRepository.updateCurrentUserProfile(
            name: any(named: 'name'),
            email: any(named: 'email'),
            profileAvatarType: any(named: 'profileAvatarType'),
            avatarSeed: any(named: 'avatarSeed'),
          ),
        ).thenAnswer((_) async => mockUpdatedUser);

        final success = await getController().updateUserProfile(
          name: 'John Doe',
          email: 'john@doe.com',
        );

        expect(success, isTrue);
        verify(
          () => mockUserRepository.updateCurrentUserProfile(
            name: 'John Doe',
            email: 'john@doe.com',
          ),
        ).called(1);
        verify(() => mockAuthController.syncUser(mockUpdatedUser)).called(1);
        verifyNever(() => mockUserRepository.currentUser);
      },
    );
  });
}

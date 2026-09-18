import 'package:checks/checks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/services/notifications_service.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/auth/repositories/auth_repository.dart';
import 'package:totem_core/auth/repositories/user_profile_repository.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/consts.dart';
import 'package:totem_core/core/services/analytics_service.dart';
import 'package:totem_core/core/services/cache_service.dart';
import 'package:totem_core/core/services/local_storage_service.dart';
import 'package:totem_core/core/services/secure_storage.dart';

UserSchema _buildUserSchema({
  String? slug,
  String? name,
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

// --- Firebase Mock Configuration ---
void setupFirebaseMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_core'),
        (methodCall) async {
          if (methodCall.method == 'Firebase#initializeCore') {
            return [
              {
                'name': '[DEFAULT]',
                'options': {
                  'apiKey': '123',
                  'appId': '123',
                  'messagingSenderId': '123',
                  'projectId': '123',
                },
                'pluginConstants': <void, void>{},
              },
            ];
          }
          if (methodCall.method == 'Firebase#initializeApp') {
            final args = methodCall.arguments as Map<String, dynamic>;
            return {
              'name': args['appName'] ?? '[DEFAULT]',
              'options': args['options'],
              'pluginConstants': <void, void>{},
            };
          }
          return null;
        },
      );

  // Mock messaging channel to prevent FCM crash during initialization
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_messaging'),
        (methodCall) async => null,
      );
}

// --- Mocks ---
class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockNotificationsService extends Mock implements NotificationsService {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockCacheService extends Mock implements CacheService {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockUserRepository mockUserRepository;
  late MockSecureStorage mockSecureStorage;
  late MockAnalyticsService mockAnalyticsService;
  late MockNotificationsService mockNotificationsService;
  late MockLocalStorageService mockLocalStorageService;
  late MockCacheService mockCacheService;
  late ProviderContainer container;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(_buildUserSchema());

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (methodCall) async => ['wifi'],
        );

    setupFirebaseMocks();
    try {
      await Firebase.initializeApp();
    } catch (_) {}
  });

  setUp(() async {
    mockAuthRepository = MockAuthRepository();
    mockUserRepository = MockUserRepository();
    mockSecureStorage = MockSecureStorage();
    mockAnalyticsService = MockAnalyticsService();
    mockNotificationsService = MockNotificationsService();
    mockLocalStorageService = MockLocalStorageService();
    mockCacheService = MockCacheService();

    when(
      () => mockSecureStorage.read(key: AppConsts.accessTokenKey),
    ).thenAnswer((_) async => null);
    when(() => mockLocalStorageService.getUser()).thenAnswer((_) async => null);

    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(MobileAuthController.new),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        userRepositoryProvider.overrideWithValue(mockUserRepository),
        secureStorageProvider.overrideWithValue(mockSecureStorage),
        analyticsProvider.overrideWithValue(mockAnalyticsService),
        notificationsProvider.overrideWithValue(mockNotificationsService),
        localStorageServiceProvider.overrideWithValue(mockLocalStorageService),
        cacheServiceProvider.overrideWithValue(mockCacheService),
      ],
    );

    await container.read(mobileAuthControllerProvider).checkExistingAuth();
  });

  tearDown(() {
    container.dispose();
  });

  MobileAuthController getController() =>
      container.read(mobileAuthControllerProvider);

  AuthState getState() => container.read(authControllerProvider);

  group('MobileAuthController - requestPin', () {
    test('successfully requests PIN and updates state', () async {
      const email = 'test@example.com';
      when(
        () => mockAuthRepository.requestPin(email, false),
      ).thenAnswer((_) async => const MessageResponse(message: 'Success'));
      when(
        () => mockAnalyticsService.logEvent(
          any(),
          parameters: any(named: 'parameters'),
        ),
      ).thenReturn(null);

      await getController().requestPin(email);

      check(getState().status).equals(AuthStatus.awaitingVerification);
      check(getState().email).equals(email);
      verify(() => mockAuthRepository.requestPin(email, false)).called(1);
      verify(
        () => mockAnalyticsService.logEvent(
          'pin_requested',
          parameters: {'email': email},
        ),
      ).called(1);
    });
  });

  group('MobileAuthController - verifyPin', () {
    test('aborts if no email is in current state', () async {
      await getController().verifyPin('123456');
      check(getState().status).equals(AuthStatus.error);
    });

    test(
      'successfully verifies PIN, stores tokens, and authenticates',
      () async {
        const email = 'test@example.com';
        const pin = '123456';
        final mockUser = _buildUserSchema(
          slug: '1',
          name: 'John',
          email: email,
        );
        const mockTokenResponse = TokenResponse(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresIn: 3600,
        );

        when(
          () => mockAuthRepository.requestPin(email, false),
        ).thenAnswer((_) async => const MessageResponse(message: 'OK'));
        when(
          () => mockAnalyticsService.logEvent(
            any(),
            parameters: any(named: 'parameters'),
          ),
        ).thenReturn(null);
        await getController().requestPin(email);

        when(
          () => mockAuthRepository.verifyPin(email, pin),
        ).thenAnswer((_) async => mockTokenResponse);
        when(
          () => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockUserRepository.currentUser,
        ).thenAnswer((_) async => mockUser);
        when(
          () => mockAnalyticsService.setUserId(mockUser),
        ).thenAnswer((_) async {});
        when(
          () => mockAnalyticsService.logLogin(method: 'pin'),
        ).thenReturn(null);
        when(
          () => mockNotificationsService.fcmToken,
        ).thenAnswer((_) async => 'fcm_token');
        when(
          () => mockAuthRepository.updateFcmToken('fcm_token'),
        ).thenAnswer((_) async {});

        await getController().verifyPin(pin);

        check(getState().status).equals(AuthStatus.authenticated);
        check(getState().user).equals(mockUser);
        check(getController().isAuthenticated).equals(true);

        verify(() => mockAuthRepository.verifyPin(email, pin)).called(1);
        verify(
          () => mockSecureStorage.write(
            key: AppConsts.accessTokenKey,
            value: 'access',
          ),
        ).called(1);
        verify(
          () => mockSecureStorage.write(
            key: AppConsts.refreshTokenKey,
            value: 'refresh',
          ),
        ).called(1);
        verify(() => mockUserRepository.currentUser).called(1);
      },
    );
  });

  group('MobileAuthController - logout & deleteAccount', () {
    // Helper to setup an authenticated state before testing logout/delete
    Future<void> authenticateUser() async {
      const email = 'test@example.com';
      when(
        () => mockAuthRepository.requestPin(email, false),
      ).thenAnswer((_) async => const MessageResponse(message: 'OK'));
      when(() => mockAuthRepository.verifyPin(email, '123456')).thenAnswer(
        (_) async => const TokenResponse(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresIn: 3600,
        ),
      );
      when(
        () => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockUserRepository.currentUser,
      ).thenAnswer((_) async => _buildUserSchema(slug: '1', name: 'John'));
      when(
        () => mockAnalyticsService.setUserId(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockAnalyticsService.logLogin(method: any(named: 'method')),
      ).thenReturn(null);
      when(
        () => mockAnalyticsService.logEvent(
          any(),
          parameters: any(named: 'parameters'),
        ),
      ).thenReturn(null);
      when(
        () => mockNotificationsService.fcmToken,
      ).thenAnswer((_) async => null);

      await getController().requestPin(email);
      await getController().verifyPin('123456');
    }

    test('logout successfully clears tokens and resets state', () async {
      await authenticateUser();

      when(
        () => mockSecureStorage.read(key: AppConsts.refreshTokenKey),
      ).thenAnswer((_) async => 'refresh_token');
      when(
        () => mockSecureStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
      when(() => mockLocalStorageService.clearUser()).thenAnswer((_) async {});
      when(() => mockCacheService.clearCache()).thenAnswer((_) async {});
      when(
        () => mockAuthRepository.logout('refresh_token'),
      ).thenAnswer((_) async => const MessageResponse(message: 'OK'));

      when(() => mockAnalyticsService.logLogout()).thenAnswer((_) async {});

      await getController().logout();

      check(getState().status).equals(AuthStatus.unauthenticated);
      check(getController().isAuthenticated).equals(false);
      verify(() => mockAuthRepository.logout('refresh_token')).called(1);
      verify(
        () => mockSecureStorage.delete(key: AppConsts.accessTokenKey),
      ).called(1);
      verify(() => mockLocalStorageService.clearUser()).called(1);
    });

    test('deleteAccount successfully deletes user and resets state', () async {
      await authenticateUser();

      when(() => mockUserRepository.deleteAccount()).thenAnswer((_) async {});

      when(
        () => mockAnalyticsService.logAccountDeleted(),
      ).thenAnswer((_) async {});
      when(
        () => mockSecureStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
      when(() => mockSecureStorage.deleteAll()).thenAnswer((_) async {});
      when(() => mockLocalStorageService.clearUser()).thenAnswer((_) async {});
      when(() => mockCacheService.clearCache()).thenAnswer((_) async {});

      await getController().deleteAccount();

      check(getState().status).equals(AuthStatus.unauthenticated);
      verify(() => mockUserRepository.deleteAccount()).called(1);
      verify(() => mockAnalyticsService.logAccountDeleted()).called(1);
      verify(() => mockSecureStorage.deleteAll()).called(1);
    });
  });

  group('MobileAuthController - syncUser', () {
    test('syncUser updates user object if authenticated', () async {
      const email = 'test@example.com';
      final initialUser = _buildUserSchema(slug: '1', name: 'John');
      final updatedUser = _buildUserSchema(slug: '1', name: 'John Doe');

      when(
        () => mockAuthRepository.requestPin(email, false),
      ).thenAnswer((_) async => const MessageResponse(message: 'OK'));
      when(() => mockAuthRepository.verifyPin(email, '123456')).thenAnswer(
        (_) async => const TokenResponse(
          accessToken: 'a',
          refreshToken: 'r',
          expiresIn: 3600,
        ),
      );
      when(
        () => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockUserRepository.currentUser,
      ).thenAnswer((_) async => initialUser);
      when(
        () => mockAnalyticsService.setUserId(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockAnalyticsService.logLogin(method: any(named: 'method')),
      ).thenReturn(null);
      when(
        () => mockAnalyticsService.logEvent(
          any(),
          parameters: any(named: 'parameters'),
        ),
      ).thenReturn(null);
      when(
        () => mockNotificationsService.fcmToken,
      ).thenAnswer((_) async => null);

      await getController().requestPin(email);
      await getController().verifyPin('123456');

      check(getState().user?.name).equals('John');

      getController().syncUser(updatedUser);

      check(getState().status).equals(AuthStatus.authenticated);
      check(getState().user?.name).equals('John Doe');
    });

    test('syncUser does nothing if not authenticated', () {
      final updatedUser = _buildUserSchema(slug: '1', name: 'John Doe');

      getController().syncUser(updatedUser);

      check(getState().status).equals(AuthStatus.unauthenticated);
      check(getState().user).isNull();
    });
  });
}

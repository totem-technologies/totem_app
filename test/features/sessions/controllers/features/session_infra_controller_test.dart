import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/riverpod.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/services/screen_protection_service.dart';
import 'package:totem_app/features/sessions/controllers/features/session_infra_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import '../../../../auth/controllers/auth_controller_mock.dart';
import '../../../../core/services/screen_protection_service_mock.dart';
import '../../../../mocks/flutter_foreground_task_mock.dart';
import '../../../../setup.dart';

class _FakeWakelockPlusPlatform extends WakelockPlusPlatformInterface {
  @override
  bool get isMock => true;

  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WakelockPlusPlatformInterface previousWakelockPlatform;

  setUpAll(() {
    setupDotenv();

    setupMockFlutterForegroundTask();
    previousWakelockPlatform = WakelockPlusPlatformInterface.instance;
    WakelockPlusPlatformInterface.instance = _FakeWakelockPlusPlatform();
    wakelockPlusPlatformInstance = WakelockPlusPlatformInterface.instance;
  });

  tearDownAll(() {
    WakelockPlusPlatformInterface.instance = previousWakelockPlatform;
    wakelockPlusPlatformInstance = previousWakelockPlatform;
  });

  group('SessionInfraController', () {
    late MockScreenProtectionService mockScreenProtection;

    setUp(() {
      mockScreenProtection = MockScreenProtectionService();
      when(
        () => mockScreenProtection.setCaptureProtectionEnabled(any()),
      ).thenAnswer((_) async {});
    });

    ProviderContainer createContainer(
      AuthState authState, {
      bool registerTearDown = true,
    }) {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(authState),
          ),
          screenProtectionProvider.overrideWithValue(mockScreenProtection),
        ],
      );
      if (registerTearDown) {
        addTearDown(container.dispose);
      }
      return container;
    }

    test('activate sets screen protection for general user', () async {
      final authState = AuthState.authenticated(
        user: UserSchema(
          email: 'test@example.com',
          name: 'Test User',
          profileAvatarType: ProfileAvatarTypeEnum.td,
          circleCount: 0,
          dateCreated: DateTime.now(),
        ),
      );
      final container = createContainer(authState);
      final controller = container.read(
        sessionInfraControllerProvider.notifier,
      );

      await controller.activate();

      verify(
        () => mockScreenProtection.setCaptureProtectionEnabled(true),
      ).called(1);
    });

    test(
      'activate disables screen protection for allowed totem emails',
      () async {
        final authState = AuthState.authenticated(
          user: UserSchema(
            email: 'admin@totem.org',
            name: 'Admin',
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime.now(),
          ),
        );
        final container = createContainer(authState);
        final controller = container.read(
          sessionInfraControllerProvider.notifier,
        );

        await controller.activate();

        verify(
          () => mockScreenProtection.setCaptureProtectionEnabled(false),
        ).called(1);
      },
    );

    test('deactivate disables screen protection', () async {
      final authState = AuthState.authenticated(
        user: UserSchema(
          email: 'test@example.com',
          name: 'Test User',
          profileAvatarType: ProfileAvatarTypeEnum.td,
          circleCount: 0,
          dateCreated: DateTime.now(),
        ),
      );
      final container = createContainer(authState);
      final controller = container.read(
        sessionInfraControllerProvider.notifier,
      );

      await controller.activate();
      verify(
        () => mockScreenProtection.setCaptureProtectionEnabled(true),
      ).called(1);

      await controller.deactivate();
      verify(
        () => mockScreenProtection.setCaptureProtectionEnabled(false),
      ).called(1);
    });

    test('disposing the container clears screen protection', () async {
      final authState = AuthState.authenticated(
        user: UserSchema(
          email: 'test@example.com',
          name: 'Test User',
          profileAvatarType: ProfileAvatarTypeEnum.td,
          circleCount: 0,
          dateCreated: DateTime.now(),
        ),
      );
      final container = createContainer(
        authState,
        registerTearDown: false,
      )..read(sessionInfraControllerProvider);

      final controller = container.read(
        sessionInfraControllerProvider.notifier,
      );
      await controller.activate();
      verify(
        () => mockScreenProtection.setCaptureProtectionEnabled(true),
      ).called(1);

      container.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 10));
      verify(
        () => mockScreenProtection.setCaptureProtectionEnabled(false),
      ).called(1);
    });
  });
}

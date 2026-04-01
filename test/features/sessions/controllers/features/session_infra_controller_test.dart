import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/riverpod.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/services/screen_protection_service.dart';
import 'package:totem_app/features/sessions/controllers/features/session_infra_controller.dart';

import '../../../../auth/controllers/auth_controller_mock.dart';
import '../../../../core/services/screen_protection_service_mock.dart';
import '../../../../mocks/flutter_foreground_task_mock.dart';
import '../../../../setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupDotenv();

    setupMockFlutterForegroundTask();
  });

  group('SessionInfraController', () {
    late MockScreenProtectionService mockScreenProtection;

    setUp(() {
      mockScreenProtection = MockScreenProtectionService();
      when(
        () => mockScreenProtection.setCaptureProtectionEnabled(any()),
      ).thenAnswer((_) async {});
    });

    ProviderContainer createContainer(AuthState authState) {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(authState),
          ),
          screenProtectionProvider.overrideWithValue(mockScreenProtection),
        ],
      );
      addTearDown(container.dispose);
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

    test('dispose calls deactivate', () async {
      final authState = AuthState.authenticated(
        user: UserSchema(
          email: 'test@example.com',
          name: 'Test User',
          profileAvatarType: ProfileAvatarTypeEnum.td,
          circleCount: 0,
          dateCreated: DateTime.now(),
        ),
      );
      final container = createContainer(authState)
        ..read(sessionInfraControllerProvider);

      final controller = container.read(
        sessionInfraControllerProvider.notifier,
      );
      await controller.activate();
      verify(
        () => mockScreenProtection.setCaptureProtectionEnabled(true),
      ).called(1);

      controller.dispose();

      await Future<void>.delayed(const Duration(milliseconds: 10));
      verify(
        () => mockScreenProtection.setCaptureProtectionEnabled(false),
      ).called(1);
    });
  });
}

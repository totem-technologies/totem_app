import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/messages/providers/is_current_user_keeper_provider.dart';

import '../../../auth/controllers/auth_controller_mock.dart';

UserSchema _user({required bool isStaff}) => UserSchema(
  profileAvatarType: ProfileAvatarTypeEnum.td,
  circleCount: 0,
  email: 'user@test.com',
  dateCreated: DateTime(2024),
  name: 'Test User',
  slug: 'test-user',
  isStaff: isStaff,
);

ProviderContainer _containerFor(AuthState authState) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => FakeAuthController(authState)),
    ],
  );
}

void main() {
  group('isCurrentMessagingUserKeeper', () {
    test('is true when the current user is staff', () {
      final container = _containerFor(
        AuthState.authenticated(user: _user(isStaff: true)),
      );
      addTearDown(container.dispose);

      expect(container.read(isCurrentMessagingUserKeeperProvider), isTrue);
    });

    test('is false when the current user is not staff', () {
      final container = _containerFor(
        AuthState.authenticated(user: _user(isStaff: false)),
      );
      addTearDown(container.dispose);

      expect(container.read(isCurrentMessagingUserKeeperProvider), isFalse);
    });

    test('is false when there is no authenticated user', () {
      final container = _containerFor(AuthState.unauthenticated());
      addTearDown(container.dispose);

      expect(container.read(isCurrentMessagingUserKeeperProvider), isFalse);
    });
  });
}

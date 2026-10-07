import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/auth/repositories/user_profile_repository.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/analytics_service.dart';
import 'package:totem_web/auth/controllers/auth_controller.dart';

final _user = UserSchema(
  slug: const Omittable('xvt124jmb'),
  profileAvatarType: ProfileAvatarTypeEnum.td,
  circleCount: 0,
  email: 'test@totem.org',
  dateCreated: DateTime(2024),
);

class _FakeUserRepository implements UserRepository {
  _FakeUserRepository(this._currentUser);

  final Future<UserSchema> Function() _currentUser;

  @override
  Future<UserSchema> get currentUser => _currentUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAnalyticsService implements AnalyticsService {
  final identified = <UserSchema>[];

  @override
  Future<void> setUserId(UserSchema user) async => identified.add(user);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(
  Future<UserSchema> Function() currentUser,
  _FakeAnalyticsService analytics,
) {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(WebAuthController.new),
      userRepositoryProvider.overrideWithValue(
        _FakeUserRepository(currentUser),
      ),
      analyticsProvider.overrideWithValue(analytics),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('identifies the signed-in user for error reporting', () async {
    final analytics = _FakeAnalyticsService();
    final container = _container(() async => _user, analytics);

    await container.read(authControllerProvider.notifier).checkExistingAuth();

    check(
      container.read(authControllerProvider).status,
    ).equals(AuthStatus.authenticated);
    check(analytics.identified).deepEquals([_user]);
  });

  test('does not identify anyone when the session is invalid', () async {
    final analytics = _FakeAnalyticsService();
    final container = _container(() async => throw Exception('401'), analytics);

    await container.read(authControllerProvider.notifier).checkExistingAuth();

    check(
      container.read(authControllerProvider).status,
    ).equals(AuthStatus.unauthenticated);
    check(analytics.identified).isEmpty();
  });
}

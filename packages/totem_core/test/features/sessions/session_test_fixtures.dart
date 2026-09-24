import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';

AuthState testAuthenticatedState({String slug = 'user-1'}) {
  return AuthState.authenticated(
    user: UserSchema(
      email: 'test@test.com',
      name: const Omittable('Test User'),
      slug: Omittable(slug),
      profileAvatarType: ProfileAvatarTypeEnum.td,
      circleCount: 0,
      dateCreated: DateTime.utc(2024),
    ),
  );
}

import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/models/profile_avatar_type_enum.dart';
import 'package:totem_core/core/api/api_client/models/user_schema.dart';

AuthState testAuthenticatedState({String slug = 'user-1'}) {
  return AuthState.authenticated(
    user: UserSchema(
      email: 'test@test.com',
      name: 'Test User',
      slug: slug,
      profileAvatarType: ProfileAvatarTypeEnum.td,
      circleCount: 0,
      dateCreated: DateTime.utc(2024),
    ),
  );
}

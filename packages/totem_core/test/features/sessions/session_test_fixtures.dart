import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

class TestAdmittedSessionParticipantIdentities
    extends AdmittedSessionParticipantIdentities {
  TestAdmittedSessionParticipantIdentities(this.identities);

  final Set<String> identities;

  @override
  Set<String> build() => Set.unmodifiable(identities);
}

AuthState testAuthenticatedState({
  String slug = 'user-1',
  bool isStaff = false,
}) {
  return AuthState.authenticated(
    user: UserSchema(
      email: 'test@test.com',
      name: const Omittable('Test User'),
      slug: Omittable(slug),
      profileAvatarType: ProfileAvatarTypeEnum.td,
      circleCount: 0,
      dateCreated: DateTime.utc(2024),
      isStaff: isStaff,
    ),
  );
}

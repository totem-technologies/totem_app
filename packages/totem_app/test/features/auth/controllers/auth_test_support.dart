import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/repositories/user_profile_repository.dart';
import 'package:totem_core/core/api/api_client/models/profile_avatar_type_enum.dart';
import 'package:totem_core/core/api/api_client/models/user_schema.dart';
import 'package:totem_core/core/services/analytics_service.dart';
import 'package:totem_core/core/services/local_storage_service.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

UserSchema testUserSchema({
  String? slug,
  String? name,
  String? profileAvatarSeed,
  String email = '',
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
    email: email,
    dateCreated: DateTime.utc(2024),
  );
}

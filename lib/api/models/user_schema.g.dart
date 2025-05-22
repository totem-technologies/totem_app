// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserSchema _$UserSchemaFromJson(Map<String, dynamic> json) => UserSchema(
  profileAvatarType: ProfileAvatarTypeEnum.fromJson(
    json['profile_avatar_type'] as String,
  ),
  apiKey: json['api_key'] as String,
  profileAvatarSeed: json['profile_avatar_seed'] as String,
  email: json['email'] as String,
  isStaff: json['is_staff'] as bool? ?? false,
  name: json['name'] as String?,
  profileImage: json['profile_image'] as String?,
);

Map<String, dynamic> _$UserSchemaToJson(UserSchema instance) =>
    <String, dynamic>{
      'profile_avatar_type':
          _$ProfileAvatarTypeEnumEnumMap[instance.profileAvatarType]!,
      'name': instance.name,
      'is_staff': instance.isStaff,
      'api_key': instance.apiKey,
      'profile_avatar_seed': instance.profileAvatarSeed,
      'profile_image': instance.profileImage,
      'email': instance.email,
    };

const _$ProfileAvatarTypeEnumEnumMap = {
  ProfileAvatarTypeEnum.tD: 'TD',
  ProfileAvatarTypeEnum.iM: 'IM',
  ProfileAvatarTypeEnum.$unknown: r'$unknown',
};

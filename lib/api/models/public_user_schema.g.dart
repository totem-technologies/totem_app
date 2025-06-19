// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_user_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicUserSchema _$PublicUserSchemaFromJson(Map<String, dynamic> json) =>
    PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.fromJson(
        json['profile_avatar_type'] as String,
      ),
      profileAvatarSeed: json['profile_avatar_seed'] as String,
      isStaff: json['is_staff'] as bool? ?? false,
      keeperProfileUsername: json['keeper_profile_username'] as String?,
      name: json['name'] as String?,
      profileImage: json['profile_image'] as String?,
    );

Map<String, dynamic> _$PublicUserSchemaToJson(PublicUserSchema instance) =>
    <String, dynamic>{
      'profile_avatar_type':
          _$ProfileAvatarTypeEnumEnumMap[instance.profileAvatarType]!,
      'keeper_profile_username': instance.keeperProfileUsername,
      'name': instance.name,
      'is_staff': instance.isStaff,
      'profile_avatar_seed': instance.profileAvatarSeed,
      'profile_image': instance.profileImage,
    };

const _$ProfileAvatarTypeEnumEnumMap = {
  ProfileAvatarTypeEnum.tD: 'TD',
  ProfileAvatarTypeEnum.iM: 'IM',
  ProfileAvatarTypeEnum.$unknown: r'$unknown',
};

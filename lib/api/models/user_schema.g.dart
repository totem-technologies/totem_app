// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserSchema _$UserSchemaFromJson(Map<String, dynamic> json) => UserSchema(
  profileAvatarType: ProfileAvatarTypeEnum.fromJson(
    json['profile_avatar_type'] as String,
  ),
  circleCount: (json['circle_count'] as num).toInt(),
  email: json['email'] as String,
  dateCreated: DateTime.parse(json['date_created'] as String),
  isStaff: json['is_staff'] as bool? ?? false,
  name: json['name'] as String?,
  slug: json['slug'] as String?,
  apiKey: json['api_key'] as String?,
  profileAvatarSeed: json['profile_avatar_seed'] as String?,
  profileImage: json['profile_image'] as String?,
);

Map<String, dynamic> _$UserSchemaToJson(UserSchema instance) =>
    <String, dynamic>{
      'profile_avatar_type':
          _$ProfileAvatarTypeEnumEnumMap[instance.profileAvatarType]!,
      'circle_count': instance.circleCount,
      'name': instance.name,
      'slug': instance.slug,
      'is_staff': instance.isStaff,
      'api_key': instance.apiKey,
      'profile_avatar_seed': instance.profileAvatarSeed,
      'profile_image': instance.profileImage,
      'email': instance.email,
      'date_created': instance.dateCreated.toIso8601String(),
    };

const _$ProfileAvatarTypeEnumEnumMap = {
  ProfileAvatarTypeEnum.td: 'TD',
  ProfileAvatarTypeEnum.im: 'IM',
  ProfileAvatarTypeEnum.$unknown: r'$unknown',
};

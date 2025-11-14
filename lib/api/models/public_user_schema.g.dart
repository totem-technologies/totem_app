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
      dateCreated: DateTime.parse(json['date_created'] as String),
      isStaff: json['is_staff'] as bool? ?? false,
      circleCount: (json['circle_count'] as num?)?.toInt(),
      name: json['name'] as String?,
      slug: json['slug'] as String?,
      profileAvatarSeed: json['profile_avatar_seed'] as String?,
      profileImage: json['profile_image'] as String?,
    );

Map<String, dynamic> _$PublicUserSchemaToJson(PublicUserSchema instance) =>
    <String, dynamic>{
      'profile_avatar_type':
          _$ProfileAvatarTypeEnumEnumMap[instance.profileAvatarType]!,
      'circle_count': instance.circleCount,
      'name': instance.name,
      'slug': instance.slug,
      'is_staff': instance.isStaff,
      'profile_avatar_seed': instance.profileAvatarSeed,
      'profile_image': instance.profileImage,
      'date_created': instance.dateCreated.toIso8601String(),
    };

const _$ProfileAvatarTypeEnumEnumMap = {
  ProfileAvatarTypeEnum.td: 'TD',
  ProfileAvatarTypeEnum.im: 'IM',
  ProfileAvatarTypeEnum.$unknown: r'$unknown',
};

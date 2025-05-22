// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_update_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserUpdateSchema _$UserUpdateSchemaFromJson(Map<String, dynamic> json) =>
    UserUpdateSchema(
      name: json['name'] as String?,
      email: json['email'] as String?,
      timezone: json['timezone'] as String?,
      newsletterConsent: json['newsletter_consent'] as bool?,
      profileAvatarType:
          json['profile_avatar_type'] == null
              ? null
              : ProfileAvatarTypeEnum.fromJson(
                json['profile_avatar_type'] as String,
              ),
      randomizeAvatarSeed: json['randomize_avatar_seed'] as bool?,
    );

Map<String, dynamic> _$UserUpdateSchemaToJson(UserUpdateSchema instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'timezone': instance.timezone,
      'newsletter_consent': instance.newsletterConsent,
      'profile_avatar_type':
          _$ProfileAvatarTypeEnumEnumMap[instance.profileAvatarType],
      'randomize_avatar_seed': instance.randomizeAvatarSeed,
    };

const _$ProfileAvatarTypeEnumEnumMap = {
  ProfileAvatarTypeEnum.tD: 'TD',
  ProfileAvatarTypeEnum.iM: 'IM',
  ProfileAvatarTypeEnum.$unknown: r'$unknown',
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AvatarUpdate _$AvatarUpdateFromJson(Map<String, dynamic> json) => AvatarUpdate(
  avatarType:
      json['avatar_type'] == null
          ? null
          : ProfileAvatarTypeEnum.fromJson(json['avatar_type'] as String),
  updateAvatarSeed: json['update_avatar_seed'] as bool?,
);

Map<String, dynamic> _$AvatarUpdateToJson(AvatarUpdate instance) =>
    <String, dynamic>{
      'avatar_type': _$ProfileAvatarTypeEnumEnumMap[instance.avatarType],
      'update_avatar_seed': instance.updateAvatarSeed,
    };

const _$ProfileAvatarTypeEnumEnumMap = {
  ProfileAvatarTypeEnum.tD: 'TD',
  ProfileAvatarTypeEnum.iM: 'IM',
  ProfileAvatarTypeEnum.$unknown: r'$unknown',
};

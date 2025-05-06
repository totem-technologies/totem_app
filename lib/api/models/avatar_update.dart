// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'profile_avatar_type_enum.dart';

part 'avatar_update.g.dart';

@JsonSerializable()
class AvatarUpdate {
  const AvatarUpdate({
    required this.avatarType,
    required this.updateAvatarSeed,
  });
  
  factory AvatarUpdate.fromJson(Map<String, Object?> json) => _$AvatarUpdateFromJson(json);
  
  @JsonKey(name: 'avatar_type')
  final ProfileAvatarTypeEnum? avatarType;
  @JsonKey(name: 'update_avatar_seed')
  final bool? updateAvatarSeed;

  Map<String, Object?> toJson() => _$AvatarUpdateToJson(this);
}

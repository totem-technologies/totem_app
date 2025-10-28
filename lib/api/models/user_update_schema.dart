// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'profile_avatar_type_enum.dart';

part 'user_update_schema.g.dart';

@JsonSerializable()
class UserUpdateSchema {
  const UserUpdateSchema({
    this.name,
    this.email,
    this.timezone,
    this.newsletterConsent,
    this.profileAvatarType,
    this.profileAvatarSeed,
  });

  factory UserUpdateSchema.fromJson(Map<String, Object?> json) =>
      _$UserUpdateSchemaFromJson(json);

  final String? name;
  final String? email;
  final String? timezone;
  @JsonKey(name: 'newsletter_consent')
  final bool? newsletterConsent;
  @JsonKey(name: 'profile_avatar_type')
  final ProfileAvatarTypeEnum? profileAvatarType;

  /// Should be a random UUID
  @JsonKey(name: 'profile_avatar_seed')
  final String? profileAvatarSeed;

  Map<String, Object?> toJson() => _$UserUpdateSchemaToJson(this);
}

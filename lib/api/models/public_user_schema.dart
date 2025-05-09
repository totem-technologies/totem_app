// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'profile_avatar_type_enum.dart';

part 'public_user_schema.g.dart';

@JsonSerializable()
class PublicUserSchema {
  const PublicUserSchema({
    required this.profileAvatarType,
    required this.profileAvatarSeed,
    this.isStaff = false,
    this.name,
    this.profileImage,
  });

  factory PublicUserSchema.fromJson(Map<String, Object?> json) =>
      _$PublicUserSchemaFromJson(json);

  @JsonKey(name: 'profile_avatar_type')
  final ProfileAvatarTypeEnum profileAvatarType;
  final String? name;

  /// Designates whether the user can log into this admin site.
  @JsonKey(name: 'is_staff')
  final bool isStaff;
  @JsonKey(name: 'profile_avatar_seed')
  final String profileAvatarSeed;

  /// Profile image, must be under 5mb. Will be cropped to a square.
  @JsonKey(name: 'profile_image')
  final String? profileImage;

  Map<String, Object?> toJson() => _$PublicUserSchemaToJson(this);
}

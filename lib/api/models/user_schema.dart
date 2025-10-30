// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'profile_avatar_type_enum.dart';

part 'user_schema.g.dart';

@JsonSerializable()
class UserSchema {
  const UserSchema({
    required this.profileAvatarType,
    required this.circleCount,
    required this.email,
    required this.dateCreated,
    this.isStaff = false,
    this.name,
    this.slug,
    this.apiKey,
    this.profileAvatarSeed,
    this.profileImage,
  });

  factory UserSchema.fromJson(Map<String, Object?> json) =>
      _$UserSchemaFromJson(json);

  @JsonKey(name: 'profile_avatar_type')
  final ProfileAvatarTypeEnum profileAvatarType;
  @JsonKey(name: 'circle_count')
  final int circleCount;
  final String? name;
  final String? slug;

  /// Designates whether the user can log into this admin site.
  @JsonKey(name: 'is_staff')
  final bool isStaff;
  @JsonKey(name: 'api_key')
  final String? apiKey;
  @JsonKey(name: 'profile_avatar_seed')
  final String? profileAvatarSeed;

  /// Profile image, must be under 5mb. Will be cropped to a square.
  @JsonKey(name: 'profile_image')
  final String? profileImage;
  final String email;
  @JsonKey(name: 'date_created')
  final DateTime dateCreated;

  Map<String, Object?> toJson() => _$UserSchemaToJson(this);
}

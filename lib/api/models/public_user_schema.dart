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
    required this.dateCreated,
    this.isStaff = false,
    this.circleCount,
    this.name,
    this.slug,
    this.profileAvatarSeed,
    this.profileImage,
  });

  factory PublicUserSchema.fromJson(Map<String, Object?> json) =>
      _$PublicUserSchemaFromJson(json);

  @JsonKey(name: 'profile_avatar_type')
  final ProfileAvatarTypeEnum profileAvatarType;
  @JsonKey(name: 'circle_count')
  final int? circleCount;
  final String? name;
  final String? slug;

  /// Designates whether the user can log into this admin site.
  @JsonKey(name: 'is_staff')
  final bool isStaff;
  @JsonKey(name: 'profile_avatar_seed')
  final String? profileAvatarSeed;

  /// Profile image, must be under 5mb. Will be cropped to a square.
  @JsonKey(name: 'profile_image')
  final String? profileImage;
  @JsonKey(name: 'date_created')
  final DateTime dateCreated;

  Map<String, Object?> toJson() => _$PublicUserSchemaToJson(this);
}

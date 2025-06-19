// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'public_user_schema.dart';

part 'keeper_profile_schema.g.dart';

@JsonSerializable()
class KeeperProfileSchema {
  const KeeperProfileSchema({
    required this.user,
    this.username,
    this.bio,
    this.instagramUsername,
    this.website,
    this.xUsername,
    this.circleCount = 0,
    this.title = 'Keeper',
    this.location = 'Earth',
  });

  factory KeeperProfileSchema.fromJson(Map<String, Object?> json) =>
      _$KeeperProfileSchemaFromJson(json);

  final PublicUserSchema? user;
  @JsonKey(name: 'circle_count')
  final int circleCount;

  /// Your unique username.
  final String? username;
  final String title;
  final String? bio;

  /// Where are you located? (City, State, Country)
  final String location;

  /// Your Instagram username, no @ symbol
  @JsonKey(name: 'instagram_username')
  final String? instagramUsername;

  /// Your personal website.
  final String? website;

  /// Your X username, no @ symbol
  @JsonKey(name: 'x_username')
  final String? xUsername;

  Map<String, Object?> toJson() => _$KeeperProfileSchemaToJson(this);
}

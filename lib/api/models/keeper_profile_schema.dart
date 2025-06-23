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
    required this.circleCount,
    required this.monthJoined,
    this.title = 'Keeper',
    this.location = 'Earth',
    this.languages = 'English',
    this.bioHtml,
    this.username,
    this.bio,
    this.instagramUsername,
    this.website,
    this.xUsername,
  });

  factory KeeperProfileSchema.fromJson(Map<String, Object?> json) =>
      _$KeeperProfileSchemaFromJson(json);

  final PublicUserSchema user;
  @JsonKey(name: 'circle_count')
  final int circleCount;
  @JsonKey(name: 'month_joined')
  final String monthJoined;
  @JsonKey(name: 'bio_html')
  final String? bioHtml;

  /// Your unique username.
  final String? username;
  final String title;
  final String? bio;

  /// Where are you located? (City, State, Country)
  final String location;

  /// What languages do you speak? (English, Spanish, etc.)
  final String languages;

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

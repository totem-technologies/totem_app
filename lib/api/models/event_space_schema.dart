// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'public_user_schema.dart';

part 'event_space_schema.g.dart';

@JsonSerializable()
class EventSpaceSchema {
  const EventSpaceSchema({
    required this.author,
    required this.title,
    required this.dateCreated,
    required this.dateModified,
    required this.subtitle,
    required this.categories,
    required this.recurring,
    this.slug,
    this.shortDescription,
    this.image,
  });
  
  factory EventSpaceSchema.fromJson(Map<String, Object?> json) => _$EventSpaceSchemaFromJson(json);
  
  final PublicUserSchema author;
  final String title;
  final String? slug;
  @JsonKey(name: 'date_created')
  final DateTime dateCreated;
  @JsonKey(name: 'date_modified')
  final DateTime dateModified;
  final String subtitle;
  final List<int> categories;

  /// Short description, max 255 characters
  @JsonKey(name: 'short_description')
  final String? shortDescription;

  /// Example: Once a month (or week, day, etc). Do not put specific times or days of the week.
  final String recurring;

  /// Image for the Space header, must be under 5mb
  final String? image;

  Map<String, Object?> toJson() => _$EventSpaceSchemaToJson(this);
}

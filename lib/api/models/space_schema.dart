// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'public_user_schema.dart';

part 'space_schema.g.dart';

@JsonSerializable()
class SpaceSchema {
  const SpaceSchema({
    required this.author,
    required this.title,
    required this.dateCreated,
    required this.dateModified,
    required this.subtitle,
    this.slug,
  });
  
  factory SpaceSchema.fromJson(Map<String, Object?> json) => _$SpaceSchemaFromJson(json);
  
  final PublicUserSchema author;
  final String title;
  final String? slug;
  @JsonKey(name: 'date_created')
  final DateTime dateCreated;
  @JsonKey(name: 'date_modified')
  final DateTime dateModified;
  final String subtitle;

  Map<String, Object?> toJson() => _$SpaceSchemaToJson(this);
}

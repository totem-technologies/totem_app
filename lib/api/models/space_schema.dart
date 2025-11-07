// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'next_event_schema.dart';
import 'public_user_schema.dart';

part 'space_schema.g.dart';

@JsonSerializable()
class SpaceSchema {
  const SpaceSchema({
    required this.title,
    required this.slug,
    required this.dateCreated,
    required this.dateModified,
    required this.subtitle,
    required this.author,
    required this.nextEvent,
    required this.imageUrl,
    required this.categories,
  });

  factory SpaceSchema.fromJson(Map<String, Object?> json) =>
      _$SpaceSchemaFromJson(json);

  final String title;
  final String slug;
  @JsonKey(name: 'date_created')
  final DateTime dateCreated;
  @JsonKey(name: 'date_modified')
  final DateTime dateModified;
  final String subtitle;
  final PublicUserSchema author;
  @JsonKey(name: 'next_event')
  final NextEventSchema? nextEvent;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  final List<String> categories;

  Map<String, Object?> toJson() => _$SpaceSchemaToJson(this);
}

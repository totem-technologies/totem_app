// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'next_event_schema.dart';
import 'user_schema.dart';

part 'space_detail_schema.g.dart';

@JsonSerializable()
class SpaceDetailSchema {
  const SpaceDetailSchema({
    required this.slug,
    required this.title,
    required this.imageLink,
    required this.description,
    required this.author,
    required this.nextEvent,
    required this.category,
  });
  
  factory SpaceDetailSchema.fromJson(Map<String, Object?> json) => _$SpaceDetailSchemaFromJson(json);
  
  final String slug;
  final String title;
  @JsonKey(name: 'image_link')
  final String? imageLink;
  final String description;
  final UserSchema author;
  final NextEventSchema nextEvent;
  final String? category;

  Map<String, Object?> toJson() => _$SpaceDetailSchemaToJson(this);
}

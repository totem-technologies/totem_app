// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'next_event_schema.dart';
import 'public_user_schema.dart';

part 'space_detail_schema.g.dart';

@JsonSerializable()
class SpaceDetailSchema {
  const SpaceDetailSchema({
    required this.slug,
    required this.title,
    required this.imageLink,
    required this.shortDescription,
    required this.content,
    required this.author,
    required this.nextEvent,
    required this.category,
    required this.subscribers,
    required this.recurring,
    required this.price,
  });

  factory SpaceDetailSchema.fromJson(Map<String, Object?> json) =>
      _$SpaceDetailSchemaFromJson(json);

  final String slug;
  final String title;
  @JsonKey(name: 'image_link')
  final String? imageLink;
  @JsonKey(name: 'short_description')
  final String shortDescription;
  final String content;
  final PublicUserSchema author;
  @JsonKey(name: 'next_event')
  final NextEventSchema? nextEvent;
  final String? category;
  final int subscribers;
  final String? recurring;
  final int price;

  Map<String, Object?> toJson() => _$SpaceDetailSchemaToJson(this);
}

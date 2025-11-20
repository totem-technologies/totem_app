// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'next_event_schema.dart';
import 'public_user_schema.dart';

part 'mobile_space_detail_schema.g.dart';

@JsonSerializable()
class MobileSpaceDetailSchema {
  const MobileSpaceDetailSchema({
    required this.slug,
    required this.title,
    required this.imageLink,
    required this.shortDescription,
    required this.content,
    required this.author,
    required this.category,
    required this.subscribers,
    required this.recurring,
    required this.price,
    required this.nextEvents,
  });

  factory MobileSpaceDetailSchema.fromJson(Map<String, Object?> json) =>
      _$MobileSpaceDetailSchemaFromJson(json);

  final String slug;
  final String title;
  @JsonKey(name: 'image_link')
  final String? imageLink;
  @JsonKey(name: 'short_description')
  final String shortDescription;
  final String content;
  final PublicUserSchema author;
  final String? category;
  final int subscribers;
  final String? recurring;
  final int price;
  @JsonKey(name: 'next_events')
  final List<NextEventSchema> nextEvents;

  Map<String, Object?> toJson() => _$MobileSpaceDetailSchemaToJson(this);
}

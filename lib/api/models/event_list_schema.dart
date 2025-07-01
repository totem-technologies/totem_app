// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'space_schema.dart';

part 'event_list_schema.g.dart';

@JsonSerializable()
class EventListSchema {
  const EventListSchema({
    required this.space,
    required this.url,
    required this.start,
    required this.dateCreated,
    required this.dateModified,
    this.slug,
    this.title,
  });

  factory EventListSchema.fromJson(Map<String, Object?> json) =>
      _$EventListSchemaFromJson(json);

  final SpaceSchema space;
  final String url;
  final DateTime start;
  final String? slug;
  @JsonKey(name: 'date_created')
  final DateTime dateCreated;
  @JsonKey(name: 'date_modified')
  final DateTime dateModified;
  final String? title;

  Map<String, Object?> toJson() => _$EventListSchemaToJson(this);
}

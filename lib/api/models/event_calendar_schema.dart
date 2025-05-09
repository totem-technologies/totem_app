// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'event_calendar_schema.g.dart';

@JsonSerializable()
class EventCalendarSchema {
  const EventCalendarSchema({
    required this.title,
    required this.start,
    required this.slug,
    required this.url,
  });

  factory EventCalendarSchema.fromJson(Map<String, Object?> json) =>
      _$EventCalendarSchemaFromJson(json);

  final String title;
  final String start;
  final String slug;
  final String url;

  Map<String, Object?> toJson() => _$EventCalendarSchemaToJson(this);
}

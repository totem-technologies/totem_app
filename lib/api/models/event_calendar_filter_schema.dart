// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'event_calendar_filter_schema.g.dart';

@JsonSerializable()
class EventCalendarFilterSchema {
  const EventCalendarFilterSchema({
    this.spaceSlug = '',
    this.month = 5,
    this.year = 2025,
  });
  
  factory EventCalendarFilterSchema.fromJson(Map<String, Object?> json) => _$EventCalendarFilterSchemaFromJson(json);
  
  /// Space slug
  @JsonKey(name: 'space_slug')
  final String spaceSlug;

  /// Month of the year, 1-12
  final int month;

  /// Year of the month, e.g. 2024
  final int year;

  Map<String, Object?> toJson() => _$EventCalendarFilterSchemaToJson(this);
}

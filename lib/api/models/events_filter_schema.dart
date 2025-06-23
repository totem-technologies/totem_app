// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'events_filter_schema.g.dart';

@JsonSerializable()
class EventsFilterSchema {
  const EventsFilterSchema({
    required this.category,
    required this.author,
  });

  factory EventsFilterSchema.fromJson(Map<String, Object?> json) =>
      _$EventsFilterSchemaFromJson(json);

  final String? category;
  final String? author;

  Map<String, Object?> toJson() => _$EventsFilterSchemaToJson(this);
}

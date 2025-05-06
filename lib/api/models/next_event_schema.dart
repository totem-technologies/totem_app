// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'next_event_schema.g.dart';

@JsonSerializable()
class NextEventSchema {
  const NextEventSchema({
    required this.slug,
    required this.start,
    required this.link,
    required this.title,
    required this.seatsLeft,
  });
  
  factory NextEventSchema.fromJson(Map<String, Object?> json) => _$NextEventSchemaFromJson(json);
  
  final String slug;
  final String start;
  final String link;
  final String? title;
  @JsonKey(name: 'seats_left')
  final int seatsLeft;

  Map<String, Object?> toJson() => _$NextEventSchemaToJson(this);
}

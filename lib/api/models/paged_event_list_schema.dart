// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'event_list_schema.dart';

part 'paged_event_list_schema.g.dart';

@JsonSerializable()
class PagedEventListSchema {
  const PagedEventListSchema({
    required this.items,
    required this.count,
  });
  
  factory PagedEventListSchema.fromJson(Map<String, Object?> json) => _$PagedEventListSchemaFromJson(json);
  
  final List<EventListSchema> items;
  final int count;

  Map<String, Object?> toJson() => _$PagedEventListSchemaToJson(this);
}

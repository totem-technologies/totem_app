// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'webflow_events_filter_schema.g.dart';

@JsonSerializable()
class WebflowEventsFilterSchema {
  const WebflowEventsFilterSchema({
    this.keeperUsername,
  });
  
  factory WebflowEventsFilterSchema.fromJson(Map<String, Object?> json) => _$WebflowEventsFilterSchemaFromJson(json);
  
  /// Filter by Keeper's username
  @JsonKey(name: 'keeper_username')
  final String? keeperUsername;

  Map<String, Object?> toJson() => _$WebflowEventsFilterSchemaToJson(this);
}

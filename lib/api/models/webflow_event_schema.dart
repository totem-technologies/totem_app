// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'webflow_event_schema.g.dart';

@JsonSerializable()
class WebflowEventSchema {
  const WebflowEventSchema({
    required this.start,
    required this.name,
    required this.keeperName,
    required this.keeperUsername,
    required this.joinLink,
    required this.imageLink,
    required this.keeperImageLink,
  });

  factory WebflowEventSchema.fromJson(Map<String, Object?> json) =>
      _$WebflowEventSchemaFromJson(json);

  final String start;
  final String name;
  @JsonKey(name: 'keeper_name')
  final String keeperName;
  @JsonKey(name: 'keeper_username')
  final String keeperUsername;
  @JsonKey(name: 'join_link')
  final String joinLink;
  @JsonKey(name: 'image_link')
  final String? imageLink;
  @JsonKey(name: 'keeper_image_link')
  final String? keeperImageLink;

  Map<String, Object?> toJson() => _$WebflowEventSchemaToJson(this);
}

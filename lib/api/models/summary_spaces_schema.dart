// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'event_detail_schema.dart';
import 'space_detail_schema.dart';

part 'summary_spaces_schema.g.dart';

@JsonSerializable()
class SummarySpacesSchema {
  const SummarySpacesSchema({
    required this.upcoming,
    required this.forYou,
    required this.explore,
  });

  factory SummarySpacesSchema.fromJson(Map<String, Object?> json) =>
      _$SummarySpacesSchemaFromJson(json);

  final List<EventDetailSchema> upcoming;
  @JsonKey(name: 'for_you')
  final List<SpaceDetailSchema> forYou;
  final List<SpaceDetailSchema> explore;

  Map<String, Object?> toJson() => _$SummarySpacesSchemaToJson(this);
}

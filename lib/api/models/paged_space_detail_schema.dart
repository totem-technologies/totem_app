// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'space_detail_schema.dart';

part 'paged_space_detail_schema.g.dart';

@JsonSerializable()
class PagedSpaceDetailSchema {
  const PagedSpaceDetailSchema({
    required this.items,
    required this.count,
  });

  factory PagedSpaceDetailSchema.fromJson(Map<String, Object?> json) =>
      _$PagedSpaceDetailSchemaFromJson(json);

  final List<SpaceDetailSchema> items;
  final int count;

  Map<String, Object?> toJson() => _$PagedSpaceDetailSchemaToJson(this);
}

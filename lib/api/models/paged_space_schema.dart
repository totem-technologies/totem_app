// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'space_schema.dart';

part 'paged_space_schema.g.dart';

@JsonSerializable()
class PagedSpaceSchema {
  const PagedSpaceSchema({
    required this.items,
    required this.count,
  });

  factory PagedSpaceSchema.fromJson(Map<String, Object?> json) =>
      _$PagedSpaceSchemaFromJson(json);

  final List<SpaceSchema> items;
  final int count;

  Map<String, Object?> toJson() => _$PagedSpaceSchemaToJson(this);
}

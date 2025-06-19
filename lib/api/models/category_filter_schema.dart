// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'category_filter_schema.g.dart';

@JsonSerializable()
class CategoryFilterSchema {
  const CategoryFilterSchema({
    required this.name,
    required this.slug,
  });

  factory CategoryFilterSchema.fromJson(Map<String, Object?> json) =>
      _$CategoryFilterSchemaFromJson(json);

  final String name;
  final String slug;

  Map<String, Object?> toJson() => _$CategoryFilterSchemaToJson(this);
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'author_filter_schema.dart';
import 'category_filter_schema.dart';

part 'filter_options_schema.g.dart';

@JsonSerializable()
class FilterOptionsSchema {
  const FilterOptionsSchema({
    required this.categories,
    required this.authors,
  });

  factory FilterOptionsSchema.fromJson(Map<String, Object?> json) =>
      _$FilterOptionsSchemaFromJson(json);

  final List<CategoryFilterSchema> categories;
  final List<AuthorFilterSchema> authors;

  Map<String, Object?> toJson() => _$FilterOptionsSchemaToJson(this);
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'author_filter_schema.g.dart';

@JsonSerializable()
class AuthorFilterSchema {
  const AuthorFilterSchema({required this.name, required this.slug});

  factory AuthorFilterSchema.fromJson(Map<String, Object?> json) =>
      _$AuthorFilterSchemaFromJson(json);

  final String name;
  final String slug;

  Map<String, Object?> toJson() => _$AuthorFilterSchemaToJson(this);
}

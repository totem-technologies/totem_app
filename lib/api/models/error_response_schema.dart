// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'error_response_schema.g.dart';

@JsonSerializable()
class ErrorResponseSchema {
  const ErrorResponseSchema({
    required this.error,
  });

  factory ErrorResponseSchema.fromJson(Map<String, Object?> json) =>
      _$ErrorResponseSchemaFromJson(json);

  final String error;

  Map<String, Object?> toJson() => _$ErrorResponseSchemaToJson(this);
}

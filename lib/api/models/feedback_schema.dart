// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'feedback_schema.g.dart';

@JsonSerializable()
class FeedbackSchema {
  const FeedbackSchema({
    required this.message,
  });

  factory FeedbackSchema.fromJson(Map<String, Object?> json) =>
      _$FeedbackSchemaFromJson(json);

  final String message;

  Map<String, Object?> toJson() => _$FeedbackSchemaToJson(this);
}

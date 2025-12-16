// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'session_feedback_options.dart';

part 'session_feedback_schema.g.dart';

@JsonSerializable()
class SessionFeedbackSchema {
  const SessionFeedbackSchema({
    required this.feedback,
    this.message,
  });

  factory SessionFeedbackSchema.fromJson(Map<String, Object?> json) =>
      _$SessionFeedbackSchemaFromJson(json);

  final SessionFeedbackOptions feedback;
  final String? message;

  Map<String, Object?> toJson() => _$SessionFeedbackSchemaToJson(this);
}

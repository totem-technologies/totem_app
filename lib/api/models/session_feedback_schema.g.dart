// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_feedback_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionFeedbackSchema _$SessionFeedbackSchemaFromJson(
  Map<String, dynamic> json,
) => SessionFeedbackSchema(
  feedback: SessionFeedbackOptions.fromJson(json['feedback'] as String),
  message: json['message'] as String?,
);

Map<String, dynamic> _$SessionFeedbackSchemaToJson(
  SessionFeedbackSchema instance,
) => <String, dynamic>{
  'feedback': _$SessionFeedbackOptionsEnumMap[instance.feedback]!,
  'message': instance.message,
};

const _$SessionFeedbackOptionsEnumMap = {
  SessionFeedbackOptions.up: 'up',
  SessionFeedbackOptions.down: 'down',
  SessionFeedbackOptions.$unknown: r'$unknown',
};

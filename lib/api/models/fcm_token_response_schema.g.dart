// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fcm_token_response_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FcmTokenResponseSchema _$FcmTokenResponseSchemaFromJson(
  Map<String, dynamic> json,
) => FcmTokenResponseSchema(
  token: json['token'] as String,
  active: json['active'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$FcmTokenResponseSchemaToJson(
  FcmTokenResponseSchema instance,
) => <String, dynamic>{
  'token': instance.token,
  'active': instance.active,
  'created_at': instance.createdAt.toIso8601String(),
};

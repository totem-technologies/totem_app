// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'fcm_token_response_schema.g.dart';

@JsonSerializable()
class FcmTokenResponseSchema {
  const FcmTokenResponseSchema({
    required this.token,
    required this.active,
    required this.createdAt,
  });

  factory FcmTokenResponseSchema.fromJson(Map<String, Object?> json) =>
      _$FcmTokenResponseSchemaFromJson(json);

  final String token;
  final bool active;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Map<String, Object?> toJson() => _$FcmTokenResponseSchemaToJson(this);
}

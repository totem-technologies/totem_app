// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'fcm_token_register_schema.g.dart';

@JsonSerializable()
class FcmTokenRegisterSchema {
  const FcmTokenRegisterSchema({required this.token});

  factory FcmTokenRegisterSchema.fromJson(Map<String, Object?> json) =>
      _$FcmTokenRegisterSchemaFromJson(json);

  final String token;

  Map<String, Object?> toJson() => _$FcmTokenRegisterSchemaToJson(this);
}

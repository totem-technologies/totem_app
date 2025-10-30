// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'livekit_token_response_schema.g.dart';

@JsonSerializable()
class LivekitTokenResponseSchema {
  const LivekitTokenResponseSchema({
    required this.token,
  });

  factory LivekitTokenResponseSchema.fromJson(Map<String, Object?> json) =>
      _$LivekitTokenResponseSchemaFromJson(json);

  final String token;

  Map<String, Object?> toJson() => _$LivekitTokenResponseSchemaToJson(this);
}

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'refresh_token_schema.g.dart';

@JsonSerializable()
class RefreshTokenSchema {
  const RefreshTokenSchema({required this.refreshToken});

  factory RefreshTokenSchema.fromJson(Map<String, Object?> json) =>
      _$RefreshTokenSchemaFromJson(json);

  @JsonKey(name: 'refresh_token')
  final String refreshToken;

  Map<String, Object?> toJson() => _$RefreshTokenSchemaToJson(this);
}

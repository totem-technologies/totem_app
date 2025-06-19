// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'validate_pin_schema.g.dart';

@JsonSerializable()
class ValidatePinSchema {
  const ValidatePinSchema({
    required this.email,
    required this.pin,
  });

  factory ValidatePinSchema.fromJson(Map<String, Object?> json) =>
      _$ValidatePinSchemaFromJson(json);

  final String email;
  final String pin;

  Map<String, Object?> toJson() => _$ValidatePinSchemaToJson(this);
}

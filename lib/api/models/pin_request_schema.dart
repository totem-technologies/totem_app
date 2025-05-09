// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

part 'pin_request_schema.g.dart';

@JsonSerializable()
class PinRequestSchema {
  const PinRequestSchema({required this.email, this.newsletterConsent = false});

  factory PinRequestSchema.fromJson(Map<String, Object?> json) =>
      _$PinRequestSchemaFromJson(json);

  final String email;
  @JsonKey(name: 'newsletter_consent')
  final bool newsletterConsent;

  Map<String, Object?> toJson() => _$PinRequestSchemaToJson(this);
}

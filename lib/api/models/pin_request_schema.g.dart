// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pin_request_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PinRequestSchema _$PinRequestSchemaFromJson(Map<String, dynamic> json) =>
    PinRequestSchema(
      email: json['email'] as String,
      newsletterConsent: json['newsletter_consent'] as bool? ?? false,
    );

Map<String, dynamic> _$PinRequestSchemaToJson(PinRequestSchema instance) =>
    <String, dynamic>{
      'email': instance.email,
      'newsletter_consent': instance.newsletterConsent,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'livekit_order_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LivekitOrderSchema _$LivekitOrderSchemaFromJson(Map<String, dynamic> json) =>
    LivekitOrderSchema(
      order: (json['order'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$LivekitOrderSchemaToJson(LivekitOrderSchema instance) =>
    <String, dynamic>{'order': instance.order};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paged_event_list_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PagedEventListSchema _$PagedEventListSchemaFromJson(
  Map<String, dynamic> json,
) => PagedEventListSchema(
  items: (json['items'] as List<dynamic>)
      .map((e) => EventListSchema.fromJson(e as Map<String, dynamic>))
      .toList(),
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$PagedEventListSchemaToJson(
  PagedEventListSchema instance,
) => <String, dynamic>{'items': instance.items, 'count': instance.count};

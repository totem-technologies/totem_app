// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paged_space_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PagedSpaceSchema _$PagedSpaceSchemaFromJson(Map<String, dynamic> json) =>
    PagedSpaceSchema(
      items: (json['items'] as List<dynamic>)
          .map((e) => SpaceSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$PagedSpaceSchemaToJson(PagedSpaceSchema instance) =>
    <String, dynamic>{'items': instance.items, 'count': instance.count};

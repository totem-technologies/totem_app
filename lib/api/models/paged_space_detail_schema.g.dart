// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paged_space_detail_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PagedSpaceDetailSchema _$PagedSpaceDetailSchemaFromJson(
  Map<String, dynamic> json,
) => PagedSpaceDetailSchema(
  items: (json['items'] as List<dynamic>)
      .map((e) => SpaceDetailSchema.fromJson(e as Map<String, dynamic>))
      .toList(),
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$PagedSpaceDetailSchemaToJson(
  PagedSpaceDetailSchema instance,
) => <String, dynamic>{'items': instance.items, 'count': instance.count};

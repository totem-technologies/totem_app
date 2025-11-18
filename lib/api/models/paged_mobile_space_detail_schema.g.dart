// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paged_mobile_space_detail_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PagedMobileSpaceDetailSchema _$PagedMobileSpaceDetailSchemaFromJson(
  Map<String, dynamic> json,
) => PagedMobileSpaceDetailSchema(
  items: (json['items'] as List<dynamic>)
      .map((e) => MobileSpaceDetailSchema.fromJson(e as Map<String, dynamic>))
      .toList(),
  count: (json['count'] as num).toInt(),
);

Map<String, dynamic> _$PagedMobileSpaceDetailSchemaToJson(
  PagedMobileSpaceDetailSchema instance,
) => <String, dynamic>{'items': instance.items, 'count': instance.count};

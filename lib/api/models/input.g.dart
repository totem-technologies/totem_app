// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Input _$InputFromJson(Map<String, dynamic> json) => Input(
  limit: (json['limit'] as num?)?.toInt() ?? 100,
  offset: (json['offset'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$InputToJson(Input instance) => <String, dynamic>{
  'limit': instance.limit,
  'offset': instance.offset,
};

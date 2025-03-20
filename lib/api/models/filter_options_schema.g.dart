// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_options_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FilterOptionsSchema _$FilterOptionsSchemaFromJson(
  Map<String, dynamic> json,
) => FilterOptionsSchema(
  categories:
      (json['categories'] as List<dynamic>)
          .map((e) => CategoryFilterSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
  authors:
      (json['authors'] as List<dynamic>)
          .map((e) => AuthorFilterSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$FilterOptionsSchemaToJson(
  FilterOptionsSchema instance,
) => <String, dynamic>{
  'categories': instance.categories,
  'authors': instance.authors,
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary_spaces_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SummarySpacesSchema _$SummarySpacesSchemaFromJson(Map<String, dynamic> json) =>
    SummarySpacesSchema(
      upcoming: (json['upcoming'] as List<dynamic>)
          .map((e) => EventDetailSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
      forYou: (json['for_you'] as List<dynamic>)
          .map((e) => SpaceSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
      explore: (json['explore'] as List<dynamic>)
          .map((e) => SpaceSchema.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SummarySpacesSchemaToJson(
  SummarySpacesSchema instance,
) => <String, dynamic>{
  'upcoming': instance.upcoming,
  'for_you': instance.forYou,
  'explore': instance.explore,
};

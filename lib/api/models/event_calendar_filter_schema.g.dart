// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_calendar_filter_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventCalendarFilterSchema _$EventCalendarFilterSchemaFromJson(
  Map<String, dynamic> json,
) => EventCalendarFilterSchema(
  spaceSlug: json['space_slug'] as String? ?? '',
  month: (json['month'] as num?)?.toInt() ?? 5,
  year: (json['year'] as num?)?.toInt() ?? 2025,
);

Map<String, dynamic> _$EventCalendarFilterSchemaToJson(
  EventCalendarFilterSchema instance,
) => <String, dynamic>{
  'space_slug': instance.spaceSlug,
  'month': instance.month,
  'year': instance.year,
};

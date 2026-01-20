// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'next_session_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NextSessionSchema _$NextSessionSchemaFromJson(Map<String, dynamic> json) =>
    NextSessionSchema(
      slug: json['slug'] as String,
      start: DateTime.parse(json['start'] as String),
      link: json['link'] as String,
      title: json['title'] as String?,
      seatsLeft: (json['seats_left'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      meetingProvider: MeetingProviderEnum.fromJson(
        json['meeting_provider'] as String,
      ),
      calLink: json['cal_link'] as String,
      attending: json['attending'] as bool,
      cancelled: json['cancelled'] as bool,
      open: json['open'] as bool,
      joinable: json['joinable'] as bool,
    );

Map<String, dynamic> _$NextSessionSchemaToJson(
  NextSessionSchema instance,
) => <String, dynamic>{
  'slug': instance.slug,
  'start': instance.start.toIso8601String(),
  'link': instance.link,
  'title': instance.title,
  'seats_left': instance.seatsLeft,
  'duration': instance.duration,
  'meeting_provider': _$MeetingProviderEnumEnumMap[instance.meetingProvider]!,
  'cal_link': instance.calLink,
  'attending': instance.attending,
  'cancelled': instance.cancelled,
  'open': instance.open,
  'joinable': instance.joinable,
};

const _$MeetingProviderEnumEnumMap = {
  MeetingProviderEnum.googleMeet: 'google_meet',
  MeetingProviderEnum.livekit: 'livekit',
  MeetingProviderEnum.$unknown: r'$unknown',
};

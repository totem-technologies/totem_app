// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_detail_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventDetailSchema _$EventDetailSchemaFromJson(Map<String, dynamic> json) =>
    EventDetailSchema(
      slug: json['slug'] as String,
      title: json['title'] as String,
      space: EventSpaceSchema.fromJson(json['space'] as Map<String, dynamic>),
      spaceTitle: json['space_title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toInt(),
      seatsLeft: (json['seats_left'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      recurring: json['recurring'] as String,
      subscribers: (json['subscribers'] as num).toInt(),
      start: DateTime.parse(json['start'] as String),
      attending: json['attending'] as bool,
      open: json['open'] as bool,
      started: json['started'] as bool,
      cancelled: json['cancelled'] as bool,
      joinable: json['joinable'] as bool,
      ended: json['ended'] as bool,
      rsvpUrl: json['rsvp_url'] as String,
      joinUrl: json['join_url'] as String?,
      subscribeUrl: json['subscribe_url'] as String,
      calLink: json['calLink'] as String,
      subscribed: json['subscribed'] as bool?,
      userTimezone: json['user_timezone'] as String?,
      meetingProvider: MeetingProviderEnum.fromJson(
        json['meeting_provider'] as String,
      ),
    );

Map<String, dynamic> _$EventDetailSchemaToJson(
  EventDetailSchema instance,
) => <String, dynamic>{
  'slug': instance.slug,
  'title': instance.title,
  'space': instance.space,
  'space_title': instance.spaceTitle,
  'description': instance.description,
  'price': instance.price,
  'seats_left': instance.seatsLeft,
  'duration': instance.duration,
  'recurring': instance.recurring,
  'subscribers': instance.subscribers,
  'start': instance.start.toIso8601String(),
  'attending': instance.attending,
  'open': instance.open,
  'started': instance.started,
  'cancelled': instance.cancelled,
  'joinable': instance.joinable,
  'ended': instance.ended,
  'rsvp_url': instance.rsvpUrl,
  'join_url': instance.joinUrl,
  'subscribe_url': instance.subscribeUrl,
  'calLink': instance.calLink,
  'subscribed': instance.subscribed,
  'user_timezone': instance.userTimezone,
  'meeting_provider': _$MeetingProviderEnumEnumMap[instance.meetingProvider]!,
};

const _$MeetingProviderEnumEnumMap = {
  MeetingProviderEnum.googleMeet: 'google_meet',
  MeetingProviderEnum.livekit: 'livekit',
  MeetingProviderEnum.$unknown: r'$unknown',
};

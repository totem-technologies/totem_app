// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'event_space_schema.dart';
import 'meeting_provider_enum.dart';

part 'event_detail_schema.g.dart';

@JsonSerializable()
class EventDetailSchema {
  const EventDetailSchema({
    required this.slug,
    required this.title,
    required this.space,
    required this.spaceTitle,
    required this.description,
    required this.price,
    required this.seatsLeft,
    required this.duration,
    required this.recurring,
    required this.subscribers,
    required this.start,
    required this.attending,
    required this.open,
    required this.started,
    required this.cancelled,
    required this.joinable,
    required this.ended,
    required this.rsvpUrl,
    required this.joinUrl,
    required this.subscribeUrl,
    required this.calLink,
    required this.subscribed,
    required this.userTimezone,
    required this.meetingProvider,
  });

  factory EventDetailSchema.fromJson(Map<String, Object?> json) =>
      _$EventDetailSchemaFromJson(json);

  final String slug;
  final String title;
  final EventSpaceSchema space;
  @JsonKey(name: 'space_title')
  final String spaceTitle;
  final String description;
  final int price;
  @JsonKey(name: 'seats_left')
  final int seatsLeft;
  final int duration;
  final String recurring;
  final int subscribers;
  final DateTime start;
  final bool attending;
  final bool open;
  final bool started;
  final bool cancelled;
  final bool joinable;
  final bool ended;
  @JsonKey(name: 'rsvp_url')
  final String rsvpUrl;
  @JsonKey(name: 'join_url')
  final String? joinUrl;
  @JsonKey(name: 'subscribe_url')
  final String subscribeUrl;
  @JsonKey(name: 'cal_link')
  final String calLink;
  final bool? subscribed;
  @JsonKey(name: 'user_timezone')
  final String? userTimezone;
  @JsonKey(name: 'meeting_provider')
  final MeetingProviderEnum meetingProvider;

  Map<String, Object?> toJson() => _$EventDetailSchemaToJson(this);
}

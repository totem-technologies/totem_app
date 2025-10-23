// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import

import 'package:json_annotation/json_annotation.dart';

import 'meeting_provider_enum.dart';

part 'next_event_schema.g.dart';

@JsonSerializable()
class NextEventSchema {
  const NextEventSchema({
    required this.slug,
    required this.start,
    required this.link,
    required this.title,
    required this.seatsLeft,
    required this.duration,
    required this.meetingProvider,
    required this.calLink,
    required this.attending,
    required this.cancelled,
    required this.open,
    required this.joinable,
  });

  factory NextEventSchema.fromJson(Map<String, Object?> json) =>
      _$NextEventSchemaFromJson(json);

  final String slug;
  final DateTime start;
  final String link;
  final String? title;
  @JsonKey(name: 'seats_left')
  final int seatsLeft;
  final int duration;
  @JsonKey(name: 'meeting_provider')
  final MeetingProviderEnum meetingProvider;
  @JsonKey(name: 'cal_link')
  final String calLink;
  final bool attending;
  final bool cancelled;
  final bool open;
  final bool joinable;

  Map<String, Object?> toJson() => _$NextEventSchemaToJson(this);
}

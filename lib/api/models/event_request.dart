// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'event_request_event_sealed.dart';

part 'event_request.g.dart';

/// POST body. Includes the event and the client's last-seen version.
/// for optimistic concurrency control.
@JsonSerializable()
class EventRequest {
  const EventRequest({
    required this.event,
    required this.lastSeenVersion,
  });

  factory EventRequest.fromJson(Map<String, Object?> json) =>
      _$EventRequestFromJson(json);

  final EventRequestEventSealed event;
  @JsonKey(name: 'last_seen_version')
  final int lastSeenVersion;

  Map<String, Object?> toJson() => _$EventRequestToJson(this);
}

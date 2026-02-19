// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'end_reason.dart';

part 'end_room_event.g.dart';

@JsonSerializable()
class EndRoomEvent {
  const EndRoomEvent({
    required this.reason,
    this.type = 'end_room',
  });

  factory EndRoomEvent.fromJson(Map<String, Object?> json) =>
      _$EndRoomEventFromJson(json);

  final String type;
  final EndReason reason;

  Map<String, Object?> toJson() => _$EndRoomEventToJson(this);
}

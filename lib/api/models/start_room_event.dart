// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'start_room_event.g.dart';

@JsonSerializable()
class StartRoomEvent {
  const StartRoomEvent({
    this.type = 'start_room',
  });

  factory StartRoomEvent.fromJson(Map<String, Object?> json) =>
      _$StartRoomEventFromJson(json);

  final String type;

  Map<String, Object?> toJson() => _$StartRoomEventToJson(this);
}

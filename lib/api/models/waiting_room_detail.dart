// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'waiting_room_detail.g.dart';

@JsonSerializable()
class WaitingRoomDetail {
  const WaitingRoomDetail({
    this.type = 'waiting_room',
  });

  factory WaitingRoomDetail.fromJson(Map<String, Object?> json) =>
      _$WaitingRoomDetailFromJson(json);

  final String type;

  Map<String, Object?> toJson() => _$WaitingRoomDetailToJson(this);
}

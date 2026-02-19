// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'active_detail.dart';
import 'end_reason.dart';
import 'ended_detail.dart';
import 'waiting_room_detail.dart';

part 'room_state_status_detail_sealed.g.dart';

@JsonSerializable(createFactory: false)
sealed class RoomStateStatusDetailSealed {
  const RoomStateStatusDetailSealed();

  factory RoomStateStatusDetailSealed.fromJson(Map<String, dynamic> json) =>
      RoomStateStatusDetailSealedDeserializer.tryDeserialize(json);

  Map<String, dynamic> toJson();
}

extension RoomStateStatusDetailSealedDeserializer
    on RoomStateStatusDetailSealed {
  static RoomStateStatusDetailSealed tryDeserialize(
    Map<String, dynamic> json, {
    String key = 'type',
    Map<Type, Object?>? mapping,
  }) {
    final mappingFallback = const <Type, Object?>{
      RoomStateStatusDetailSealedActiveDetail: 'active',
      RoomStateStatusDetailSealedEndedDetail: 'ended',
      RoomStateStatusDetailSealedWaitingRoomDetail: 'waiting_room',
    };
    final value = json[key];
    final effective = mapping ?? mappingFallback;
    return switch (value) {
      _ when value == effective[RoomStateStatusDetailSealedActiveDetail] =>
        RoomStateStatusDetailSealedActiveDetail.fromJson(json),
      _ when value == effective[RoomStateStatusDetailSealedEndedDetail] =>
        RoomStateStatusDetailSealedEndedDetail.fromJson(json),
      _ when value == effective[RoomStateStatusDetailSealedWaitingRoomDetail] =>
        RoomStateStatusDetailSealedWaitingRoomDetail.fromJson(json),
      _ => throw FormatException(
        'Unknown discriminator value "${json[key]}" for RoomStateStatusDetailSealed',
      ),
    };
  }
}

@JsonSerializable()
class RoomStateStatusDetailSealedActiveDetail
    extends RoomStateStatusDetailSealed
    implements ActiveDetail {
  @override
  final String type;

  const RoomStateStatusDetailSealedActiveDetail({
    required this.type,
  });

  factory RoomStateStatusDetailSealedActiveDetail.fromJson(
    Map<String, dynamic> json,
  ) => _$RoomStateStatusDetailSealedActiveDetailFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$RoomStateStatusDetailSealedActiveDetailToJson(this);
}

@JsonSerializable()
class RoomStateStatusDetailSealedEndedDetail extends RoomStateStatusDetailSealed
    implements EndedDetail {
  @override
  final String type;
  @override
  final EndReason reason;

  const RoomStateStatusDetailSealedEndedDetail({
    required this.type,
    required this.reason,
  });

  factory RoomStateStatusDetailSealedEndedDetail.fromJson(
    Map<String, dynamic> json,
  ) => _$RoomStateStatusDetailSealedEndedDetailFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$RoomStateStatusDetailSealedEndedDetailToJson(this);
}

@JsonSerializable()
class RoomStateStatusDetailSealedWaitingRoomDetail
    extends RoomStateStatusDetailSealed
    implements WaitingRoomDetail {
  @override
  final String type;

  const RoomStateStatusDetailSealedWaitingRoomDetail({
    required this.type,
  });

  factory RoomStateStatusDetailSealedWaitingRoomDetail.fromJson(
    Map<String, dynamic> json,
  ) => _$RoomStateStatusDetailSealedWaitingRoomDetailFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$RoomStateStatusDetailSealedWaitingRoomDetailToJson(this);
}

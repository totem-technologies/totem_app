// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'room_state_status_detail_sealed.dart';
import 'room_status.dart';
import 'turn_state.dart';

part 'room_state.g.dart';

/// The canonical state snapshot. This is what gets:.
/// - returned from both endpoints.
/// - published to LiveKit room metadata.
/// - built from the Room model.
///
/// Clients should treat this as the single type they deserialize everywhere.
/// User references are slugs (short unique public IDs), not internal IDs.
@JsonSerializable()
class RoomState {
  const RoomState({
    required this.sessionSlug,
    required this.version,
    required this.status,
    required this.turnState,
    required this.statusDetail,
    required this.talkingOrder,
    required this.keeper,
    this.bannedParticipants = const [],
    this.currentSpeaker,
    this.nextSpeaker,
  });

  factory RoomState.fromJson(Map<String, Object?> json) =>
      _$RoomStateFromJson(json);

  @JsonKey(name: 'session_slug')
  final String sessionSlug;
  final int version;
  final RoomStatus status;
  @JsonKey(name: 'turn_state')
  final TurnState turnState;
  @JsonKey(name: 'status_detail')
  final RoomStateStatusDetailSealed statusDetail;
  @JsonKey(name: 'current_speaker')
  final String? currentSpeaker;
  @JsonKey(name: 'next_speaker')
  final String? nextSpeaker;
  @JsonKey(name: 'talking_order')
  final List<String> talkingOrder;
  final String keeper;
  @JsonKey(name: 'banned_participants')
  final List<String> bannedParticipants;

  Map<String, Object?> toJson() => _$RoomStateToJson(this);
}

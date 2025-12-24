// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'session_status.dart';
import 'totem_status.dart';

part 'session_state.g.dart';

@JsonSerializable()
class SessionState {
  const SessionState({
    required this.keeperSlug,
    required this.speakingOrder,
    this.speakingNow,
    this.status = SessionStatus.waiting,
    this.totemStatus = TotemStatus.none,
  });

  factory SessionState.fromJson(Map<String, Object?> json) =>
      _$SessionStateFromJson(json);

  @JsonKey(name: 'keeper_slug')
  final String keeperSlug;
  final SessionStatus status;
  @JsonKey(name: 'speaking_order')
  final List<String> speakingOrder;
  @JsonKey(name: 'speaking_now')
  final String? speakingNow;
  @JsonKey(name: 'totem_status')
  final TotemStatus totemStatus;

  Map<String, Object?> toJson() => _$SessionStateToJson(this);
}

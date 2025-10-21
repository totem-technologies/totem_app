import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:totem_app/core/errors/error_handler.dart';

part 'session_state.g.dart';

enum SessionStatus { waiting, started, ending, ended }

@immutable
@JsonSerializable()
class SessionState {
  const SessionState({
    required this.status,
    required this.speakingNow,
    required this.speakingOrder,
  });

  factory SessionState.fromMetadata(String? metadata) {
    if (metadata == null) return const SessionState.waiting();
    try {
      return SessionState.fromJson(
        jsonDecode(metadata) as Map<String, dynamic>,
      );
    } catch (e, st) {
      ErrorHandler.logError(e, stackTrace: st);
      return const SessionState.waiting();
    }
  }

  const SessionState.waiting()
    : status = SessionStatus.waiting,
      speakingNow = null,
      speakingOrder = const [];

  factory SessionState.fromJson(Map<String, dynamic> json) =>
      _$SessionStateFromJson(json);
  Map<String, dynamic> toJson() => _$SessionStateToJson(this);

  /// Current status of the session.
  final SessionStatus status;

  /// User identity of the participant currently speaking, if any.
  @JsonKey(name: 'speaking_now')
  final String? speakingNow;

  /// Ordered list of user identities representing the speaking order.
  @JsonKey(name: 'speaking_order')
  final List<String>? speakingOrder;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SessionState &&
        other.status == status &&
        other.speakingNow == speakingNow &&
        listEquals(other.speakingOrder, speakingOrder);
  }

  @override
  int get hashCode {
    return status.hashCode ^ speakingNow.hashCode ^ speakingOrder.hashCode;
  }

  @override
  String toString() =>
      'SessionState(status: $status, speakingNow: $speakingNow, '
      'speakingOrder: $speakingOrder)';
}

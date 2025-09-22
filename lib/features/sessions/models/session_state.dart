import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_state.g.dart';

enum SessionStatus { waiting, started, ending, ended }

@immutable
@JsonSerializable()
class SessionState {
  const SessionState({
    required this.status,
    required this.speakingNow,
    required this.nextUp,
    required this.speakingOrder,
  });

  const SessionState.waiting()
    : status = SessionStatus.waiting,
      speakingNow = null,
      nextUp = null,
      speakingOrder = const [];

  factory SessionState.fromJson(Map<String, dynamic> json) =>
      _$SessionStateFromJson(json);
  Map<String, dynamic> toJson() => _$SessionStateToJson(this);

  /// Current status of the session.
  final SessionStatus status;

  /// User identity of the participant currently speaking, if any.
  final String? speakingNow;

  /// User identity of the next participant scheduled to speak, if any.
  final String? nextUp;

  /// Ordered list of user identities representing the speaking order.
  final List<String> speakingOrder;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SessionState &&
        other.status == status &&
        other.speakingNow == speakingNow &&
        other.nextUp == nextUp &&
        listEquals(other.speakingOrder, speakingOrder);
  }

  @override
  int get hashCode {
    return status.hashCode ^
        speakingNow.hashCode ^
        nextUp.hashCode ^
        speakingOrder.hashCode;
  }
}

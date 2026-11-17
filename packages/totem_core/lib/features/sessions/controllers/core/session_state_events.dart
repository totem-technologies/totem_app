import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';

sealed class SessionEvent {
  const SessionEvent();
}

class ConnectionChanged extends SessionEvent {
  const ConnectionChanged(
    this.connectionState,
    this.phase, {
    this.wasJoining = false,
  });

  final RoomConnectionState connectionState;
  final SessionPhase phase;
  final bool wasJoining;
}

/// LiveKit started or finished recovering a dropped connection.
class ReconnectingChanged extends SessionEvent {
  const ReconnectingChanged({required this.isReconnecting});

  final bool isReconnecting;
}

class RoomStateChanged extends SessionEvent {
  const RoomStateChanged(this.roomState, {required this.observedAt});

  final DateTime observedAt;

  final RoomState roomState;
}

class ParticipantsChanged extends SessionEvent {
  const ParticipantsChanged(this.participants);

  final List<ParticipantInfo> participants;
}

class ParticipantRemoved extends SessionEvent {
  const ParticipantRemoved(this.reason);

  final RemoveReason reason;
}

class SessionErrorChanged extends SessionEvent {
  const SessionErrorChanged(this.error);

  final RoomError? error;
}

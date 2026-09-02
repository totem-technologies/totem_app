import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';

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

class RoomStateChanged extends SessionEvent {
  const RoomStateChanged(this.roomState);

  final RoomState roomState;
}

class ParticipantsChanged extends SessionEvent {
  const ParticipantsChanged(this.participants);

  final List<Participant> participants;
}

class ParticipantRemoved extends SessionEvent {
  const ParticipantRemoved(this.reason);

  final RemoveReason reason;
}

class SessionErrorChanged extends SessionEvent {
  const SessionErrorChanged(this.error);

  final RoomError? error;
}

class SessionChatMessageAdded extends SessionEvent {
  const SessionChatMessageAdded(this.message);

  final SessionChatMessage message;
}

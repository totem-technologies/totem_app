import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';

sealed class SessionEvent {
  const new();
}

class ConnectionChanged extends SessionEvent {
  const new(this.connectionState, this.phase, {this.wasJoining = false});

  final RoomConnectionState connectionState;
  final SessionPhase phase;
  final bool wasJoining;
}

class RoomStateChanged extends SessionEvent {
  const new(this.roomState);

  final RoomState roomState;
}

class ParticipantsChanged extends SessionEvent {
  const new(this.participants);

  final List<ParticipantInfo> participants;
}

class ParticipantRemoved extends SessionEvent {
  const new(this.reason);

  final RemoveReason reason;
}

class SessionErrorChanged extends SessionEvent {
  const new(this.error);

  final RoomError? error;
}

class SessionChatMessageAdded extends SessionEvent {
  const new(this.message);

  final SessionChatMessage message;
}

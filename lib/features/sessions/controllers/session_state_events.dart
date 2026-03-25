import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/session_messaging_controller.dart';
import 'package:totem_app/features/sessions/controllers/session_state.dart';

sealed class SessionEvent {
  const SessionEvent();
}

class ConnectionChanged extends SessionEvent {
  const ConnectionChanged(this.connectionState, this.phase);

  final RoomConnectionState connectionState;
  final SessionPhase phase;
}

class RoomStateChanged extends SessionEvent {
  const RoomStateChanged(this.roomState);

  final RoomState roomState;
}

class ParticipantsChanged extends SessionEvent {
  const ParticipantsChanged(this.participants);

  final List<Participant> participants;
}

class KeeperDisconnectedChanged extends SessionEvent {
  const KeeperDisconnectedChanged(this.hasKeeperDisconnected);

  final bool hasKeeperDisconnected;
}

class ParticipantRemoved extends SessionEvent {
  const ParticipantRemoved();
}

class SpeakerphoneChanged extends SessionEvent {
  const SpeakerphoneChanged(this.isSpeakerphoneEnabled);

  final bool isSpeakerphoneEnabled;
}

class DisconnectReasonChanged extends SessionEvent {
  const DisconnectReasonChanged(this.disconnectReason);

  final DisconnectReason? disconnectReason;
}

class SessionErrorChanged extends SessionEvent {
  const SessionErrorChanged(this.error);

  final RoomError? error;
}

class LiveKitErrorChanged extends SessionEvent {
  const LiveKitErrorChanged(this.livekitError);

  final LiveKitException? livekitError;
}

class SessionChatMessageAdded extends SessionEvent {
  const SessionChatMessageAdded(this.message);

  final SessionChatMessage message;
}

import 'package:collection/collection.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions, logger;
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';

enum RoomConnectionState { connecting, connected, disconnected, error }

enum SessionPhase {
  idle,
  connecting,
  connected,
  disconnected,
  error,
  ended,
}

sealed class RoomError {
  const RoomError();
}

class RoomLiveKitError extends RoomError {
  const RoomLiveKitError(this.exception);
  final LiveKitException exception;

  @override
  String toString() => 'RoomLiveKitError: ${exception.message}';
}

class RoomDisconnectionError extends RoomError {
  const RoomDisconnectionError(this.reason);
  final DisconnectReason reason;

  @override
  String toString() => 'RoomDisconnectionError: ${reason.name}';
}

@immutable
class ConnectionState {
  const ConnectionState({
    required this.phase,
    required this.state,
    this.error,
    this.wasJoining = false,
  });

  final SessionPhase phase;
  final RoomConnectionState state;
  final RoomError? error;
  final bool wasJoining;

  ConnectionState copyWith({
    SessionPhase? phase,
    RoomConnectionState? state,
    RoomError? error,
    bool clearError = false,
    bool? wasJoining,
  }) {
    return ConnectionState(
      phase: phase ?? this.phase,
      state: state ?? this.state,
      error: clearError ? null : error ?? this.error,
      wasJoining: wasJoining ?? this.wasJoining,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionState &&
        other.phase == phase &&
        other.state == state &&
        other.error?.toString() == error?.toString() &&
        other.wasJoining == wasJoining;
  }

  @override
  int get hashCode =>
      phase.hashCode ^
      state.hashCode ^
      error.toString().hashCode ^
      wasJoining.hashCode;
}

@immutable
class ParticipantsState {
  const ParticipantsState({
    this.participants = const [],
    this.removed = false,
  });

  final List<Participant> participants;
  final bool removed;

  ParticipantsState copyWith({
    List<Participant>? participants,
    bool? removed,
  }) {
    return ParticipantsState(
      participants: participants ?? this.participants,
      removed: removed ?? this.removed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantsState &&
        const DeepCollectionEquality().equals(
          other.participants.map((p) => p.sid),
          participants.map((p) => p.sid),
        ) &&
        other.removed == removed;
  }

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(participants.map((p) => p.sid)) ^
      removed.hashCode;
}

@immutable
class ChatState {
  const ChatState({
    this.messages = const [],
  });

  final List<SessionChatMessage> messages;

  ChatState copyWith({
    List<SessionChatMessage>? messages,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatState &&
        const DeepCollectionEquality().equals(
          other.messages.map((m) => m.id),
          messages.map((m) => m.id),
        );
  }

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(messages.map((m) => m.id));
}

@immutable
class SessionTurnState {
  const SessionTurnState({
    required this.roomState,
  });

  final RoomState roomState;

  SessionTurnState copyWith({
    RoomState? roomState,
  }) {
    return SessionTurnState(
      roomState: roomState ?? this.roomState,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionTurnState && other.roomState == roomState;
  }

  @override
  int get hashCode => roomState.hashCode;
}

@immutable
class SessionOptions {
  const SessionOptions({
    required this.eventSlug,
    required this.token,
    required this.cameraEnabled,
    required this.microphoneEnabled,
    required this.speakerEnabled,
    required this.cameraOptions,
  });

  final String eventSlug;
  final String token;
  final bool cameraEnabled;
  final bool microphoneEnabled;
  final bool speakerEnabled;

  final CameraCaptureOptions cameraOptions;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionOptions &&
        other.eventSlug == eventSlug &&
        other.token == token;
  }

  @override
  int get hashCode => eventSlug.hashCode ^ token.hashCode;
}

@immutable
class SessionRoomState {
  const SessionRoomState({
    required this.connection,
    required this.participants,
    required this.chat,
    required this.turn,
  });

  final ConnectionState connection;
  final ParticipantsState participants;
  final ChatState chat;
  final SessionTurnState turn;

  SessionPhase get phase => connection.phase;
  RoomConnectionState get connectionState => connection.state;
  RoomState get roomState => turn.roomState;
  List<Participant> get participantsList => participants.participants;
  bool get removed => participants.removed;
  List<SessionChatMessage> get messages => chat.messages;

  DisconnectReason? get disconnectReason {
    final error = connection.error;
    if (error is RoomDisconnectionError) return error.reason;
    return null;
  }

  LiveKitException? get livekitError {
    final error = connection.error;
    if (error is RoomLiveKitError) return error.exception;
    return null;
  }

  bool amSpeaking(Room room) {
    return turn.roomState.currentSpeaker != null &&
        turn.roomState.currentSpeaker == room.localParticipant?.identity;
  }

  bool amNext(Room room) {
    return turn.roomState.nextSpeaker != null &&
        turn.roomState.nextSpeaker == room.localParticipant?.identity;
  }

  String get speakingNow {
    if (turn.roomState.currentSpeaker == null ||
        turn.roomState.currentSpeaker!.isEmpty) {
      return turn.roomState.keeper;
    }
    return turn.roomState.currentSpeaker ?? turn.roomState.keeper;
  }

  bool get hasKeeper =>
      participants.participants.any((p) => isKeeper(p.identity));

  bool isKeeper(String? userSlug) {
    return turn.roomState.keeper == userSlug;
  }

  Participant? featuredParticipant() {
    if (participants.participants.isEmpty) return null;
    if (turn.roomState.status == RoomStatus.waitingRoom && !hasKeeper) {
      return null;
    }
    return participants.participants.firstWhereOrNull(
          (participant) => participant.identity == speakingNow,
        ) ??
        participants.participants.firstWhereOrNull(
          (participant) => participant.identity == turn.roomState.keeper,
        );
  }

  Participant? speakingNextParticipant() {
    if (turn.roomState.nextSpeaker == null) return null;
    return participants.participants.firstWhereOrNull((participant) {
      return participant.identity == turn.roomState.nextSpeaker;
    });
  }

  @override
  String toString() {
    return 'SessionRoomState('
        'phase: ${connection.phase}, '
        'connectionState: ${connection.state}, '
        'roomState: ${turn.roomState}, '
        'error: ${connection.error}, '
        'participants: ${participants.participants.length}, '
        'removed: ${participants.removed}, '
        'messages: ${chat.messages.length}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionRoomState &&
        other.connection == connection &&
        other.participants == participants &&
        other.chat == chat &&
        other.turn == turn;
  }

  @override
  int get hashCode =>
      connection.hashCode ^
      participants.hashCode ^
      chat.hashCode ^
      turn.hashCode;
}

/// Returns true if the given [reason] represents a transient disconnect that
/// commonly happens during the join process (e.g. signaling hiccups or
/// transient join failures). These disconnects are recoverable and the UI
/// typically should continue showing a loading/joining state rather than
/// immediately showing a disconnected screen.
bool isTransientJoinDisconnectReason(DisconnectReason? reason) {
  return reason == DisconnectReason.joinFailure ||
      reason == DisconnectReason.clientInitiated ||
      reason == DisconnectReason.signalingConnectionFailure;
}

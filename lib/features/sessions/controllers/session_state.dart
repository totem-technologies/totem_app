import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:livekit_client/livekit_client.dart'
  hide ChatMessage, ConnectionState, SessionOptions, logger;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/session_chat_message.dart';

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

class RoomTimeoutError extends RoomError {
  const RoomTimeoutError(this.phase);
  final SessionPhase phase;

  @override
  String toString() => 'RoomTimeoutError in phase: ${phase.name}';
}

@immutable
class ConnectionState {
  const ConnectionState({
    required this.phase,
    required this.state,
    this.error,
  });

  final SessionPhase phase;
  final RoomConnectionState state;
  final RoomError? error;

  ConnectionState copyWith({
    SessionPhase? phase,
    RoomConnectionState? state,
    RoomError? error,
    bool clearError = false,
  }) {
    return ConnectionState(
      phase: phase ?? this.phase,
      state: state ?? this.state,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionState &&
        other.phase == phase &&
        other.state == state &&
        other.error?.toString() == error?.toString();
  }

  @override
  int get hashCode =>
      phase.hashCode ^ state.hashCode ^ error.toString().hashCode;
}

@immutable
class ParticipantsState {
  const ParticipantsState({
    this.participants = const [],
    this.hasKeeperDisconnected = false,
    this.removed = false,
  });

  final List<Participant> participants;
  final bool hasKeeperDisconnected;
  final bool removed;

  ParticipantsState copyWith({
    List<Participant>? participants,
    bool? hasKeeperDisconnected,
    bool? removed,
  }) {
    return ParticipantsState(
      participants: participants ?? this.participants,
      hasKeeperDisconnected:
          hasKeeperDisconnected ?? this.hasKeeperDisconnected,
      removed: removed ?? this.removed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantsState &&
        const DeepCollectionEquality().equals(
          other.participants.map((p) => p.identity),
          participants.map((p) => p.identity),
        ) &&
        other.hasKeeperDisconnected == hasKeeperDisconnected &&
        other.removed == removed;
  }

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(participants.map((p) => p.identity)) ^
      hasKeeperDisconnected.hashCode ^
      removed.hashCode;
}

@immutable
class ChatState {
  const ChatState({
    this.messages = const [],
  });

  final List<ChatMessage> messages;

  ChatState copyWith({
    List<ChatMessage>? messages,
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
    this.isSpeakerphoneEnabled = false,
  });

  final RoomState roomState;
  final bool isSpeakerphoneEnabled;

  SessionTurnState copyWith({
    RoomState? roomState,
    bool? isSpeakerphoneEnabled,
  }) {
    return SessionTurnState(
      roomState: roomState ?? this.roomState,
      isSpeakerphoneEnabled:
          isSpeakerphoneEnabled ?? this.isSpeakerphoneEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionTurnState &&
        other.roomState == roomState &&
        other.isSpeakerphoneEnabled == isSpeakerphoneEnabled;
  }

  @override
  int get hashCode => roomState.hashCode ^ isSpeakerphoneEnabled.hashCode;
}

@immutable
class SessionOptions {
  const SessionOptions({
    required this.eventSlug,
    required this.token,
    required this.cameraEnabled,
    required this.microphoneEnabled,
    required this.cameraOptions,
    required this.audioOutputOptions,
  });

  final String eventSlug;
  final String token;
  final bool cameraEnabled;
  final bool microphoneEnabled;

  final CameraCaptureOptions cameraOptions;
  final AudioOutputOptions audioOutputOptions;

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
  bool get hasKeeperDisconnected => participants.hasKeeperDisconnected;
  List<Participant> get participantsList => participants.participants;
  bool get removed => participants.removed;
  bool get isSpeakerphoneEnabled => turn.isSpeakerphoneEnabled;
  List<ChatMessage> get messages => chat.messages;

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

  bool isMyTurn(Room room) {
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
        'isSpeakerphoneEnabled: ${turn.isSpeakerphoneEnabled}, '
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

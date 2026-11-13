import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions, logger;
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/permissions/classify.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';

enum RoomConnectionState { connecting, connected, disconnected, error }

enum SessionPhase { idle, connecting, connected, disconnected, error, ended }

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
    this.isReconnecting = false,
  });

  final SessionPhase phase;
  final RoomConnectionState state;
  final RoomError? error;
  final bool wasJoining;

  /// Whether LiveKit is recovering a dropped connection. The connection still
  /// reads as connected meanwhile, so the UI can tell the user without leaving
  /// the room.
  final bool isReconnecting;

  ConnectionState copyWith({
    SessionPhase? phase,
    RoomConnectionState? state,
    RoomError? error,
    bool clearError = false,
    bool? wasJoining,
    bool? isReconnecting,
  }) {
    return ConnectionState(
      phase: phase ?? this.phase,
      state: state ?? this.state,
      error: clearError ? null : error ?? this.error,
      wasJoining: wasJoining ?? this.wasJoining,
      isReconnecting: isReconnecting ?? this.isReconnecting,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionState &&
        other.phase == phase &&
        other.state == state &&
        other.error?.toString() == error?.toString() &&
        other.wasJoining == wasJoining &&
        other.isReconnecting == isReconnecting;
  }

  @override
  int get hashCode =>
      phase.hashCode ^
      state.hashCode ^
      error.toString().hashCode ^
      wasJoining.hashCode ^
      isReconnecting.hashCode;
}

@immutable
class ParticipantsState {
  const ParticipantsState({
    this.participants = const [],
    this.removed = false,
    this.removeReason,
  });

  final List<ParticipantInfo> participants;
  final bool removed;
  final RemoveReason? removeReason;

  ParticipantsState copyWith({
    List<ParticipantInfo>? participants,
    bool? removed,
    RemoveReason? removeReason,
  }) {
    return ParticipantsState(
      participants: participants ?? this.participants,
      removed: removed ?? this.removed,
      removeReason: removeReason ?? this.removeReason,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantsState &&
        const ListEquality<ParticipantInfo>().equals(
          other.participants,
          participants,
        ) &&
        other.removed == removed &&
        other.removeReason == removeReason;
  }

  @override
  int get hashCode =>
      const ListEquality<ParticipantInfo>().hash(participants) ^
      removed.hashCode ^
      removeReason.hashCode;
}

@immutable
class ChatState {
  const ChatState({this.messages = const []});

  final List<SessionChatMessage> messages;

  ChatState copyWith({List<SessionChatMessage>? messages}) {
    return ChatState(messages: messages ?? this.messages);
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
  const SessionTurnState({required this.roomState});

  final RoomState roomState;

  SessionTurnState copyWith({RoomState? roomState}) {
    return SessionTurnState(roomState: roomState ?? this.roomState);
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
    required this.sessionSlug,
    required this.token,
    required this.cameraEnabled,
    required this.microphoneEnabled,
    required this.speakerEnabled,
    required this.cameraOptions,
  });

  final String sessionSlug;
  final String token;
  final bool cameraEnabled;
  final bool microphoneEnabled;
  final bool speakerEnabled;

  final CameraCaptureOptions cameraOptions;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionOptions &&
        other.sessionSlug == sessionSlug &&
        other.token == token;
  }

  @override
  int get hashCode => sessionSlug.hashCode ^ token.hashCode;
}

/// Pre-join media whose ownership is transferred to the session controller.
///
/// The session publishes these already-created preview tracks after connecting.
/// This avoids opening a second camera and microphone while the pre-join preview
/// is still active, which is particularly important for Safari. The controller
/// retains tracks until publication succeeds. Failed transfers are detached
/// from the preview and disposed before join returns; published tracks are
/// disposed with the room.
@immutable
class SessionJoinMedia {
  const SessionJoinMedia({
    this.cameraTrack,
    this.microphoneTrack,
    this.onBeforeDispose,
  });

  final LocalVideoTrack? cameraTrack;
  final LocalAudioTrack? microphoneTrack;

  /// Detaches preview renderers before a failed transfer is stopped.
  final VoidCallback? onBeforeDispose;

  bool get isEmpty => cameraTrack == null && microphoneTrack == null;
}

@immutable
class SessionRoomState {
  const SessionRoomState({
    required this.connection,
    required this.participants,
    required this.chat,
    required this.turn,
    this.turnStartedAt,
  });

  final ConnectionState connection;
  final ParticipantsState participants;
  final ChatState chat;
  final SessionTurnState turn;

  /// Wall-clock time when the current turn began.
  /// Set by the reducer when [speakingNow] changes to a non-empty value;
  /// carried through unchanged for all other events.
  final DateTime? turnStartedAt;

  SessionPhase get phase => connection.phase;
  RoomConnectionState get connectionState => connection.state;
  RoomState get roomState => turn.roomState;
  List<ParticipantInfo> get participantsList => participants.participants;
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

  bool amSpeaking(String? localIdentity) {
    return turn.roomState.currentSpeaker.value != null &&
        turn.roomState.currentSpeaker.value == localIdentity;
  }

  bool amNext(String? localIdentity) {
    return turn.roomState.nextSpeaker.value != null &&
        turn.roomState.nextSpeaker.value == localIdentity;
  }

  /// The effective speaker identity for [roomState], using keeper as fallback.
  static String speakerOf(RoomState roomState) {
    final currentSpeaker = roomState.currentSpeaker.value;
    if (currentSpeaker == null || currentSpeaker.isEmpty) {
      return roomState.keeper;
    }
    return currentSpeaker;
  }

  String get speakingNow => speakerOf(turn.roomState);

  bool get hasKeeper =>
      participants.participants.any((p) => isKeeper(p.identity));

  bool isKeeper(String? userSlug) {
    return turn.roomState.keeper == userSlug;
  }

  ParticipantInfo? featuredParticipant() {
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

  ParticipantInfo? speakingNextParticipant() {
    final nextSpeaker = turn.roomState.nextSpeaker.value;
    if (nextSpeaker == null) return null;
    return participants.participants.firstWhereOrNull((participant) {
      return participant.identity == nextSpeaker;
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
        other.turn == turn &&
        other.turnStartedAt == turnStartedAt;
  }

  @override
  int get hashCode =>
      connection.hashCode ^
      participants.hashCode ^
      chat.hashCode ^
      turn.hashCode ^
      turnStartedAt.hashCode;
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

/// Returns true when LiveKit reports a client-side internet disconnection.
bool isInternetDisconnectReason(DisconnectReason? reason) {
  return reason == DisconnectReason.signalingConnectionFailure ||
      reason == DisconnectReason.reconnectAttemptsExceeded;
}

/// Returns whether a confirmed offline state may take precedence over the
/// LiveKit disconnect reason.
///
/// Explicit server-side and user-initiated reasons must keep their dedicated
/// disconnected-screen messaging. Ambiguous client-side failures may still be
/// presented as internet failures when connectivity independently reports that
/// the device is offline.
bool canOfflineStateOverrideDisconnectReason(DisconnectReason? reason) {
  return switch (reason) {
    null ||
    DisconnectReason.unknown ||
    DisconnectReason.joinFailure ||
    DisconnectReason.disconnected ||
    DisconnectReason.signalingConnectionFailure ||
    DisconnectReason.reconnectAttemptsExceeded ||
    DisconnectReason.signalClose ||
    DisconnectReason.mediaFailure => true,
    _ => false,
  };
}

/// Returns true when [reason] is a real outcome for this participant: they
/// left, were removed, moved to another device, or the room itself is gone.
///
/// Every other non-null reason is a technical failure that leaves the session
/// running, so the user should be offered a way back in instead of being told
/// the session ended.
bool isSessionOutcomeDisconnectReason(DisconnectReason? reason) {
  return switch (reason) {
    DisconnectReason.clientInitiated ||
    DisconnectReason.duplicateIdentity ||
    DisconnectReason.participantRemoved ||
    DisconnectReason.roomDeleted ||
    DisconnectReason.roomClosed => true,
    _ => false,
  };
}

/// Returns true when [reason] is a technical failure (network, media, server)
/// rather than a session outcome. See [isSessionOutcomeDisconnectReason].
bool isTechnicalDisconnectReason(DisconnectReason? reason) {
  return reason != null && !isSessionOutcomeDisconnectReason(reason);
}

/// What kind of problem a session error is, from the user's point of view.
enum SessionErrorCategory {
  /// The device has no internet connection.
  offline,

  /// The video server couldn't be reached or didn't answer in time.
  serverUnreachable,

  /// An established connection to the session dropped and didn't recover.
  connectionLost,

  /// The camera or microphone couldn't be started.
  mediaDevice,

  /// The server refused this participant's access to the room.
  accessDenied,

  /// Anything not recognised.
  unknown;

  /// The title shown to the user for this kind of problem.
  String get title => switch (this) {
    offline => "You're Offline",
    serverUnreachable => "Couldn't Reach the Session",
    connectionLost => 'Connection Lost',
    mediaDevice => 'Camera or Microphone Problem',
    accessDenied => "Couldn't Join This Session",
    unknown => 'Something went wrong',
  };

  /// The message shown under [title], telling the user what to do next.
  String get message => switch (this) {
    offline =>
      'Video sessions require an active internet connection.\n'
          'Check your Wi-Fi or mobile data, then tap below to rejoin.',
    serverUnreachable =>
      "We couldn't reach the video server. "
          'Check your connection, then try joining again.',
    connectionLost =>
      'Your connection to the session dropped. '
          'The session may still be going, so try joining again.',
    mediaDevice =>
      "We couldn't start your camera or microphone. Check that Totem "
          'can use them and no other app has them open, then try again.',
    accessDenied =>
      "We couldn't confirm your access to this session. "
          'Go back and join again from the session details.',
    unknown =>
      "We couldn't connect you to this session. "
          'Please check your internet connection or try again.',
  };
}

/// Classifies a session [error] into a [SessionErrorCategory] for user-facing copy.
///
/// Accepts [RoomError]s, raw LiveKit exceptions, [MediaPublishException], and
/// [SessionJoinFailure]. A confirmed offline device ([isOffline]) wins over
/// ambiguous failures, but never over a session outcome.
SessionErrorCategory classifySessionError(
  Object? error, {
  bool isOffline = false,
}) {
  final cause = switch (error) {
    SessionJoinFailure(:final cause) => cause,
    RoomLiveKitError(:final exception) => exception,
    _ => error,
  };

  if (cause is RoomDisconnectionError) {
    // LiveKit gives up with the same reasons whether the device or only the
    // video server dropped, so only connectivity can say the user is offline.
    if (isOffline && canOfflineStateOverrideDisconnectReason(cause.reason)) {
      return SessionErrorCategory.offline;
    }
    return isTechnicalDisconnectReason(cause.reason)
        ? SessionErrorCategory.connectionLost
        : SessionErrorCategory.unknown;
  }

  final kind = switch (cause) {
    ConnectException(reason: ConnectionErrorReason.NotAllowed) =>
      SessionErrorCategory.accessDenied,
    ConnectException() ||
    MediaConnectException() ||
    // On web, LiveKit's fallback validate request fails with "Failed to
    // fetch" when the video server can't be reached.
    ClientException() => SessionErrorCategory.serverUnreachable,
    TrackCreateException() ||
    AudioSessionException() => SessionErrorCategory.mediaDevice,
    NegotiationError() ||
    UnexpectedStateException() ||
    TrackPublishException() ||
    MediaPublishException() => SessionErrorCategory.connectionLost,
    final Object other when captureErrorName(other) != null =>
      SessionErrorCategory.mediaDevice,
    _ => SessionErrorCategory.unknown,
  };

  if (isOffline &&
      kind != SessionErrorCategory.mediaDevice &&
      kind != SessionErrorCategory.accessDenied) {
    return SessionErrorCategory.offline;
  }
  return kind;
}

/// A join attempt that failed without throwing, carrying the [cause] that
/// `SessionController.join` saw (when there was one) so the UI can explain it.
@immutable
class SessionJoinFailure implements Exception {
  const SessionJoinFailure([this.cause]);

  final Object? cause;

  SessionErrorCategory get kind => classifySessionError(cause);

  @override
  String toString() => 'SessionJoinFailure(${cause.runtimeType})';
}

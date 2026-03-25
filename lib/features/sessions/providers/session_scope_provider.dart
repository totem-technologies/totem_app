import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/session_controller.dart';
import 'package:totem_app/features/sessions/controllers/session_messaging_controller.dart';

part 'session_scope_provider.g.dart';

class SessionParticipantKeys {
  final Map<String, GlobalKey> _participantKeys = {};

  GlobalKey getKey(String identity) {
    return _participantKeys.putIfAbsent(identity, GlobalKey.new);
  }
}

final sessionParticipantKeysProvider = Provider<SessionParticipantKeys>((ref) {
  return SessionParticipantKeys();
});

/// Provider that will be overridden at room scope.
/// Returns the current session options for the active room.
@Riverpod(keepAlive: true)
SessionOptions? sessionScope(Ref ref) => null;

/// Convenience provider to get the current session notifier.
@Riverpod(dependencies: [sessionScope])
SessionController? currentSession(Ref ref) {
  final options = ref.watch(sessionScopeProvider);
  if (options == null) return null;
  return ref.watch(sessionControllerProvider(options).notifier);
}

/// Convenience provider to get the current session state.
@Riverpod(dependencies: [sessionScope])
SessionRoomState? currentSessionState(Ref ref) {
  final options = ref.watch(sessionScopeProvider);
  if (options == null) return null;
  return ref.watch(sessionProvider(options));
}

// ===== Granular Selectors =====
// These allow widgets to watch only specific fields, minimizing rebuilds.

/// The connection state of the current session.
@Riverpod(dependencies: [currentSessionState])
RoomConnectionState connectionState(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select((s) => s?.connection.state),
      ) ??
      RoomConnectionState.connecting;
}

/// The high-level lifecycle phase for the current session.
@Riverpod(dependencies: [currentSessionState])
SessionPhase sessionPhase(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select((s) => s?.connection.phase),
      ) ??
      SessionPhase.connecting;
}

/// The current session error, if any.
@Riverpod(dependencies: [currentSessionState])
RoomError? sessionError(Ref ref) {
  return ref.watch(
    currentSessionStateProvider.select((s) => s?.connection.error),
  );
}

/// The current session status (waiting, started, ended).
@Riverpod(dependencies: [currentSessionState])
RoomStatus roomStatus(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select((s) => s?.roomState.status),
      ) ??
      RoomStatus.waitingRoom;
}

/// The current totem status (none, accepted, passing).
@Riverpod(dependencies: [currentSessionState])
TurnState turnState(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select((s) => s?.roomState.turnState),
      ) ??
      TurnState.idle;
}

/// The list of participants in the session.
@Riverpod(dependencies: [currentSessionState])
List<Participant> sessionParticipants(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select((s) => s?.participants.participants),
      ) ??
      [];
}

/// Current session error as a LiveKitError, if applicable.
@Riverpod(dependencies: [sessionError])
LiveKitException? sessionLivekitError(Ref ref) {
  final error = ref.watch(sessionErrorProvider);
  if (error is RoomLiveKitError) {
    return error.exception;
  }
  return null;
}

/// Current session error as a DisconnectionError, if applicable.
@Riverpod(dependencies: [sessionError])
DisconnectReason? disconnectionReason(Ref ref) {
  final error = ref.watch(sessionErrorProvider);
  if (error is RoomDisconnectionError) {
    return error.reason;
  }
  return null;
}

/// Whether the keeper is currently disconnected.
@Riverpod(dependencies: [currentSessionState])
bool hasKeeperDisconnected(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select(
          (s) => s?.participants.hasKeeperDisconnected,
        ),
      ) ??
      false;
}

/// All chat messages for the current session.
@Riverpod(dependencies: [currentSessionState])
List<SessionChatMessage> sessionMessages(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select((s) => s?.chat.messages),
      ) ??
      const [];
}

/// Last chat message if available.
@Riverpod(dependencies: [sessionMessages])
SessionChatMessage? lastSessionMessage(Ref ref) {
  final messages = ref.watch(sessionMessagesProvider);
  return messages.isEmpty ? null : messages.last;
}

/// Optional round message sent by the keeper for the active round.
@Riverpod(dependencies: [currentSessionState])
String? roundMessage(Ref ref) {
  return ref.watch(
    currentSessionStateProvider.select((s) => s?.roomState.roundMessage),
  );
}

/// Whether the keeper participant is currently present in the room.
@Riverpod(dependencies: [currentSessionState])
bool hasKeeper(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select((s) => s?.hasKeeper),
      ) ??
      false;
}

/// Participant currently featured in the room layout.
@Riverpod(dependencies: [currentSessionState])
Participant? featuredParticipant(Ref ref) {
  return ref.watch(
    currentSessionStateProvider.select((s) => s?.featuredParticipant()),
  );
}

/// Participant expected to speak next.
@Riverpod(dependencies: [currentSessionState])
Participant? speakingNextParticipant(Ref ref) {
  return ref.watch(
    currentSessionStateProvider.select((s) => s?.speakingNextParticipant()),
  );
}

/// Active session event payload.
@Riverpod(dependencies: [currentSession])
SessionDetailSchema? currentSessionEvent(Ref ref) {
  return ref.watch(
    currentSessionProvider.select((s) => s?.event),
  );
}

/// Whether the signed-in user is keeper for the current session.
@Riverpod(dependencies: [currentSession])
bool isCurrentUserKeeper(Ref ref) {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return false;
  return session.isCurrentUserKeeper();
}

/// Whether it's the current user's turn to speak.
@Riverpod(dependencies: [currentSession, currentSessionState])
bool isMyTurn(Ref ref) {
  final currentSession = ref.watch(currentSessionProvider);
  final state = ref.watch(currentSessionStateProvider);
  if (currentSession?.room == null || state == null) return false;
  return state.isMyTurn(currentSession!.room!);
}

/// Whether the current user is next to speak.
@Riverpod(dependencies: [currentSession, currentSessionState])
bool amNextSpeaker(Ref ref) {
  final currentSession = ref.watch(currentSessionProvider);
  final state = ref.watch(currentSessionStateProvider);
  if (currentSession?.room == null || state == null) return false;
  return state.amNext(currentSession!.room!);
}

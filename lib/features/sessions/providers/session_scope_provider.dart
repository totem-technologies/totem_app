import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';

part 'session_scope_provider.g.dart';

/// Provider that will be overridden at room scope.
/// Returns the current session options for the active room.
@Riverpod(keepAlive: true)
SessionOptions? sessionScope(Ref ref) => null;

/// Convenience provider to get the current session notifier.
@Riverpod(dependencies: [sessionScope])
Session? currentSession(Ref ref) {
  final options = ref.watch(sessionScopeProvider);
  if (options == null) return null;
  return ref.read(sessionProvider(options).notifier);
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
        currentSessionStateProvider.select((s) => s?.connectionState),
      ) ??
      RoomConnectionState.connecting;
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
        currentSessionStateProvider.select((s) => s?.participants),
      ) ??
      [];
}

/// Whether it's the current user's turn to speak.
@Riverpod(dependencies: [currentSession, currentSessionState])
bool isMyTurn(Ref ref) {
  final currentSession = ref.watch(currentSessionProvider);
  final state = ref.watch(currentSessionStateProvider);
  if (currentSession?.context == null || state == null) return false;
  return state.isMyTurn(currentSession!.context!);
}

/// Whether the current user is next to speak.
@Riverpod(dependencies: [currentSession, currentSessionState])
bool amNextSpeaker(Ref ref) {
  final currentSession = ref.watch(currentSessionProvider);
  final state = ref.watch(currentSessionStateProvider);
  if (currentSession?.context == null || state == null) return false;
  return state.amNext(currentSession!.context!);
}

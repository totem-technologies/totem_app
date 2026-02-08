import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/totem_status.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';

part 'session_scope_provider.g.dart';

/// Provider that will be overridden at room scope.
/// Returns the current session options for the active room.
@riverpod
SessionOptions? sessionScope(Ref ref) => null;

/// Convenience provider to get the current session notifier.
@riverpod
Session? currentSession(Ref ref) {
  final options = ref.watch(sessionScopeProvider);
  if (options == null) return null;
  return ref.read(sessionProvider(options).notifier);
}

/// Convenience provider to get the current session state.
@riverpod
SessionRoomState? currentSessionState(Ref ref) {
  final options = ref.watch(sessionScopeProvider);
  if (options == null) return null;
  return ref.watch(sessionProvider(options));
}

// ===== Granular Selectors =====
// These allow widgets to watch only specific fields, minimizing rebuilds.

/// The connection state of the current session.
@riverpod
RoomConnectionState connectionState(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select((s) => s?.connectionState),
      ) ??
      RoomConnectionState.connecting;
}

/// The current session status (waiting, started, ended).
@riverpod
SessionStatus sessionStatus(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select((s) => s?.sessionState.status),
      ) ??
      SessionStatus.waiting;
}

/// The current totem status (none, accepted, passing).
@riverpod
TotemStatus totemStatus(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select((s) => s?.sessionState.totemStatus),
      ) ??
      TotemStatus.none;
}

/// The list of participants in the session.
@riverpod
List<Participant> sessionParticipants(Ref ref) {
  return ref.watch(
        currentSessionStateProvider.select((s) => s?.participants),
      ) ??
      [];
}

/// Whether it's the current user's turn to speak.
@riverpod
bool isMyTurn(Ref ref) {
  final session = ref.watch(currentSessionProvider);
  final state = ref.watch(currentSessionStateProvider);
  if (session?.context == null || state == null) return false;
  return state.isMyTurn(session!.context!);
}

/// Whether the current user is next to speak.
@riverpod
bool amNextSpeaker(Ref ref) {
  final session = ref.watch(currentSessionProvider);
  final state = ref.watch(currentSessionStateProvider);
  if (session?.context == null || state == null) return false;
  return state.amNext(session!.context!);
}

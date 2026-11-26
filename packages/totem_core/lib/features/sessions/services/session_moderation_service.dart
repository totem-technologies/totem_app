import 'dart:async';
import 'dart:convert';

import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/services/session_commands.dart';
import 'package:totem_core/features/sessions/services/session_packet_router.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

class SessionModerationService {
  SessionModerationService({
    required this.backend,
    required this.state,
    required this.isKeeper,
    required this.transport,
    required this.applyState,
    required this.markRemoved,
    required this.leave,
    required this.onError,
    required bool Function() Function() captureValidity,
  }) : _commands = SessionCommandGate(captureValidity);
  final SessionModerationBackend backend;
  final SessionRoomState Function() state;
  final bool Function() isKeeper;
  final SessionTransport? Function() transport;
  final void Function(RoomState) applyState;
  final void Function(RemoveReason) markRemoved;
  final Future<void> Function() leave;
  final void Function(Object, StackTrace) onError;
  final SessionCommandGate _commands;
  final Expando<bool> _removedConnections = Expando<bool>();
  bool _disposed = false;
  SessionCommandFailure? get lastFailure => _commands.lastFailure;

  void _requireKeeper() {
    if (!isKeeper()) {
      throw SessionCommandException(
        SessionCommandFailureKind.unauthorized,
        'Only the Keeper can moderate this session',
      );
    }
  }

  void _commit(RoomState response, bool Function() current) {
    if (!current()) {
      throw SessionCommandException(
        SessionCommandFailureKind.superseded,
        'This connection ended before the command completed',
      );
    }
    final accepted = state().roomState;
    if (response.version < accepted.version) return;
    if (response.version == accepted.version && response != accepted) {
      throw SessionCommandException(
        SessionCommandFailureKind.conflict,
        'A newer room update has already been received',
      );
    }
    applyState(response);
  }

  Future<void> removeParticipant(String identity) => _commands.run((
    current,
  ) async {
    _requireKeeper();
    try {
      await backend.remove(identity).timeout(const Duration(seconds: 20));
    } catch (error) {
      if (error is ApiError &&
          error.statusCode >= 400 &&
          error.statusCode < 500 &&
          error.statusCode != 408) {
        rethrow;
      }
      throw SessionCommandException(
        SessionCommandFailureKind.unknownOutcome,
        'Removal outcome is unknown. Do not remove again until participant status has been verified.',
        cause: error,
      );
    }
  });
  Future<void> banParticipant(String identity) =>
      _commands.run((current) async {
        _requireKeeper();
        _commit(
          await backend
              .ban(state().roomState.version, identity)
              .timeout(const Duration(seconds: 20)),
          current,
        );
      });
  Future<void> unbanParticipant(String identity) =>
      _commands.run((current) async {
        _requireKeeper();
        _commit(
          await backend
              .unban(state().roomState.version, identity)
              .timeout(const Duration(seconds: 20)),
          current,
        );
      });
  Future<void> muteParticipant(String identity) => _commands.run((_) async {
    _requireKeeper();
    await backend.mute(identity).timeout(const Duration(seconds: 20));
  }, key: ('mute', identity));
  Future<void> disableParticipantCamera(String identity) => _commands.run((
    _,
  ) async {
    _requireKeeper();
    await backend.disableCamera(identity).timeout(const Duration(seconds: 20));
  }, key: ('camera', identity));
  Future<void> muteEveryone() => _commands.run((_) async {
    _requireKeeper();
    await backend.muteEveryone().timeout(const Duration(seconds: 20));
  }, key: 'muteEveryone');

  void receive(SessionTransportPacket packet) {
    if (_disposed ||
        packet.topic != SessionCommunicationTopics.participantRemoved.topic) {
      return;
    }
    final connection = transport();
    if (connection == null || (_removedConnections[connection] ?? false)) {
      return;
    }
    final sender = packet.sender?.identity;
    // Preserve the existing server-originated (no sender) packet semantics.
    if (sender != null && sender != state().roomState.keeper) return;
    try {
      final payload = RemoveParticipantPayload.fromJson(
        jsonDecode(utf8.decode(packet.bytes)) as Map<String, dynamic>,
      );
      if (payload.identity != connection.localIdentity) return;
      _removedConnections[connection] = true;
      markRemoved(payload.reason);
      unawaited(leave().catchError(onError));
    } catch (error, stack) {
      onError(error, stack);
    }
  }

  void dispose() {
    _disposed = true;
    _commands.dispose();
  }
}

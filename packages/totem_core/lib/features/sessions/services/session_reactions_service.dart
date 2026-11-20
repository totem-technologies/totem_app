import 'dart:async';
import 'dart:convert';
import 'package:totem_core/features/sessions/services/session_packet_router.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

/// Typed protocol adapter; the existing reactions owner retains its throttle
/// and bounded presentation state.
class SessionReactionsService {
  SessionReactionsService({
    required this.transport,
    required this.hasKeeper,
    required this.emit,
    required this.onError,
    required this.broadcastRecipients,
  });
  final SessionTransport? Function() transport;
  final bool Function() hasKeeper;
  final Future<bool> Function(String identity, String emoji) emit;
  final void Function(Object, StackTrace) onError;

  /// Returns the current trusted roster, or null when authority is unavailable.
  final Iterable<String>? Function() broadcastRecipients;
  bool _disposed = false;
  int _generation = 0;
  void receive(SessionTransportPacket packet) {
    if (_disposed ||
        packet.topic != SessionCommunicationTopics.emoji.topic ||
        packet.sender == null) {
      return;
    }
    try {
      final emoji = utf8.decode(packet.bytes);
      unawaited(
        emit(
          packet.sender!.identity,
          emoji,
        ).then<void>((_) {}).catchError(onError),
      );
    } catch (error, stack) {
      onError(error, stack);
    }
  }

  Future<void> send(String emoji) async {
    final connection = transport();
    if (_disposed ||
        !hasKeeper() ||
        connection?.localIdentity == null ||
        connection!.connectionState !=
            SessionTransportConnectionState.connected) {
      return;
    }
    final generation = _generation;
    try {
      if (!await emit(connection.localIdentity!, emoji)) return;
      if (_disposed ||
          generation != _generation ||
          !identical(transport(), connection) ||
          connection.connectionState !=
              SessionTransportConnectionState.connected) {
        return;
      }
      final recipients = (broadcastRecipients() ?? const <String>[])
          .where(
            (identity) =>
                identity.isNotEmpty && identity != connection.localIdentity,
          )
          .toSet()
          .toList();
      if (recipients.isEmpty) return;
      await connection
          .publish(
            SessionTransportPacket(
              bytes: utf8.encode(emoji),
              topic: SessionCommunicationTopics.emoji.topic,
              recipients: recipients,
            ),
          )
          .timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      onError(error, stack);
    }
  }

  void cancelPending() {
    _generation++;
  }

  void dispose() {
    _disposed = true;
    cancelPending();
  }
}

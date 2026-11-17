import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';

enum SessionTransportConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

enum SessionTransportFailureKind {
  connection,
  mediaConnection,
  publication,
  subscription,
  unexpected,
}

enum SessionTransportConnectionFailure { notAllowed, internal, timeout }

class SessionTransportFailure implements Exception {
  const SessionTransportFailure(
    this.kind,
    this.message, {
    required this.cause,
    required this.stackTrace,
    this.connectionFailure,
  });
  final SessionTransportFailureKind kind;
  final SessionTransportConnectionFailure? connectionFailure;
  final String message;
  final Object cause;
  final StackTrace stackTrace;
  @override
  String toString() => 'SessionTransportFailure($kind): $message';
}

/// Packet bytes and topic retain the existing wire protocols unchanged.
class SessionTransportPacket {
  SessionTransportPacket({
    required Iterable<int> bytes,
    required this.topic,
    this.sender,
    this.reliable = false,
    Iterable<String> recipients = const [],
  }) : bytes = List.unmodifiable(bytes),
       recipients = List.unmodifiable(recipients);
  final List<int> bytes;
  final String topic;
  final ParticipantInfo? sender;
  final bool reliable;
  final List<String> recipients;
}

sealed class SessionTransportEvent {
  const SessionTransportEvent();
}

enum SessionTransportDisconnectReason {
  unknown,
  clientInitiated,
  duplicateIdentity,
  serverShutdown,
  participantRemoved,
  roomDeleted,
  stateMismatch,
  joinFailure,
  disconnected,
  signalingConnectionFailure,
  reconnectAttemptsExceeded,
  migration,
  signalClose,
  roomClosed,
  userUnavailable,
  userRejected,
  sipTrunkFailure,
  connectionTimeout,
  mediaFailure,
  agentError,
}

class TransportConnectionChanged extends SessionTransportEvent {
  const TransportConnectionChanged(
    this.state, {
    this.reason,
    this.reconnected = false,
  });

  /// Reconnection completion refreshes permissions without re-running join.
  final bool reconnected;
  final SessionTransportConnectionState state;

  /// Stable diagnostic identifier, not a transport SDK enum.
  final SessionTransportDisconnectReason? reason;
}

class TransportMetadataChanged extends SessionTransportEvent {
  const TransportMetadataChanged(this.metadata);
  final String? metadata;
}

class TransportParticipantChanged extends SessionTransportEvent {
  const TransportParticipantChanged(this.participant, {required this.present});
  final ParticipantInfo participant;
  final bool present;
}

class TransportParticipantUpdated extends SessionTransportEvent {
  const TransportParticipantUpdated(this.participant, {this.metadata});
  final ParticipantInfo participant;
  final String? metadata;
}

class TransportPacketReceived extends SessionTransportEvent {
  const TransportPacketReceived(this.packet);
  final SessionTransportPacket packet;
}

class TransportMediaChanged extends SessionTransportEvent {
  const TransportMediaChanged();
}

abstract interface class SessionTransport {
  SessionTransportConnectionState get connectionState;
  String? get localIdentity;
  String? get metadata;
  List<ParticipantInfo> get participants;
  Stream<SessionTransportEvent> get events;
  LocalMedia get localMedia;
  RoomMedia get roomMedia;
  Future<void> prepare(String url, String token);
  Future<void> connect(String url, String token, {bool autoSubscribe = true});
  Future<void> publish(SessionTransportPacket packet);
  void setSubscriptionPermissions({
    required bool allowEveryone,
    required Set<String> recipients,
  });
  Future<void> subscribeToExistingMedia();
  Future<void> disconnect();

  /// Idempotent; cancels event delivery before releasing the underlying room.
  Future<void> dispose();
}

abstract interface class SessionTransportFactory {
  /// Stable media facades across reconnects within the owning session.
  LocalMedia get localMedia;
  RoomMedia get roomMedia;
  SessionTransport create();
}

/// The offering owner must detach its listeners before constructing the lease.
/// While offered, the lease is the sole owner. Claim consumes it synchronously;
/// cleanup by the former owner then cannot dispose the claimed connection.
class ConnectedSessionLease {
  ConnectedSessionLease(SessionTransport transport)
    : this.deferred(
        identity: transport,
        connected: () =>
            transport.connectionState ==
            SessionTransportConnectionState.connected,
        claim: () => transport,
        release: transport.dispose,
      );
  ConnectedSessionLease.deferred({
    required this.identity,
    required bool Function() connected,
    required this._claim,
    required this._release,
  }) : _connected = connected {
    if (!connected()) {
      throw StateError('Only connected transports can be offered');
    }
  }
  final Object identity;
  final bool Function() _connected;
  final SessionTransport Function() _claim;
  final Future<void> Function() _release;
  bool _consumed = false;
  Future<void>? _disposal;
  SessionTransport claim() {
    if (_consumed) throw StateError('Connection lease already consumed');
    if (!_connected()) {
      throw StateError('Offered connection is no longer connected');
    }
    final transport = _claim();
    _consumed = true;
    return transport;
  }

  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    if (_consumed) return;
    _consumed = true;
    await _release();
  }
}

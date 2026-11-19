import 'dart:async';
import 'dart:convert';
import 'package:totem_core/core/api/api_client/models/room_state.dart';
import 'package:totem_core/features/sessions/admission/admission_join_receipt.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

/// Active-session admission adapter fed by the runtime's existing event router.
/// Does not subscribe to, disconnect, or dispose the underlying connection.
class SessionAdmissionChannel implements AdmissionChannel {
  SessionAdmissionChannel(
    this.connection, {
    DateTime Function()? now,
    void Function()? onConfirmationFailed,
  }) : _now = now ?? DateTime.now {
    _receipts = AdmissionJoinReceipt(
      localIdentity: () => localIdentity,
      send: send,
      now: _now,
      onConfirmationFailed: onConfirmationFailed,
    );
    _metadata(connection.metadata);
  }
  final SessionTransport connection;
  final DateTime Function() _now;
  final _events = StreamController<AdmissionEvent>.broadcast(sync: true);
  late final AdmissionJoinReceipt _receipts;
  bool _disposed = false;
  bool _ended = false;
  @override
  String get localIdentity => connection.localIdentity ?? '';
  @override
  bool get hasEnded => _ended;
  @override
  Iterable<String> get remoteIdentities =>
      connection.participants.where((p) => !p.isLocal).map((p) => p.identity);
  @override
  bool isPresent(String identity) => remoteIdentities.contains(identity);
  @override
  Stream<AdmissionEvent> get events => _events.stream;
  void _emit(AdmissionEvent event) {
    if (_disposed) return;
    _events.add(event);
    _receipts.handle(event);
  }

  void _metadata(String? metadata) {
    if (_ended || metadata == null || metadata.isEmpty) return;
    try {
      if (RoomState.fromJson(
            jsonDecode(metadata) as Map<String, dynamic>,
          ).status ==
          RoomStatus.ended) {
        _ended = true;
        _emit(const AdmissionRoomEnded());
      }
    } catch (_) {
      /* Non-room metadata cannot end admission. */
    }
  }

  void handle(SessionTransportEvent event) {
    if (_disposed) return;
    switch (event) {
      case TransportPacketReceived(:final packet):
        if (packet.topic != AdmissionProtocol.topic) return;
        final decoded = AdmissionProtocol.decode(
          packet.bytes,
          senderIdentity: packet.sender?.identity,
          now: _now(),
        );
        if (decoded != null) _emit(AdmissionPacketReceived(decoded));
      case TransportParticipantChanged(:final participant, :final present):
        _emit(AdmissionPresenceChanged(participant.identity, present));
      case TransportMetadataChanged(:final metadata):
        _metadata(metadata);
      case TransportConnectionChanged(:final state, :final reason):
        if (state == SessionTransportConnectionState.connected) {
          _metadata(connection.metadata);
          if (!_ended) _emit(const AdmissionConnectionRestored());
        } else if (state == SessionTransportConnectionState.reconnecting) {
          if (!_ended) _emit(const AdmissionConnectionInterrupted());
        } else if (state == SessionTransportConnectionState.disconnected) {
          _receipts.stop();
          if (!_ended) _emit(AdmissionRoomDisconnected(reason));
        }
      default:
        break;
    }
  }

  @override
  Future<void> send(AdmissionPacket packet) async {
    if (_disposed ||
        connection.connectionState !=
            SessionTransportConnectionState.connected ||
        packet.senderIdentity != localIdentity ||
        localIdentity.isEmpty ||
        packet.recipientIdentity.isEmpty) {
      throw StateError('Admission sender is not connected');
    }
    final bytes = AdmissionProtocol.encode(packet);
    if (bytes.length > AdmissionProtocol.maxPayloadBytes) {
      throw ArgumentError('Admission packet exceeds size limit');
    }
    if ((packet is AdmissionJoined || packet is AdmissionJoinFailed) &&
        (packet.recipientIdentity == localIdentity ||
            AdmissionProtocol.decode(
                  bytes,
                  senderIdentity: localIdentity,
                  now: _now(),
                ) ==
                null)) {
      throw ArgumentError('Invalid or expired admission receipt');
    }
    await connection.publish(
      SessionTransportPacket(
        bytes: bytes,
        topic: AdmissionProtocol.topic,
        reliable: true,
        recipients: [packet.recipientIdentity],
      ),
    );
  }

  Future<void> sendJoinOutcome(
    AdmissionRequest request, {
    bool joined = true,
  }) => _receipts.sendOutcome(request, joined: joined);
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait<void>([
      Future<void>.sync(_receipts.dispose),
      Future<void>.sync(() async {
        await _events.close();
      }),
    ]);
  }
}

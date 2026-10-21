import 'dart:async';
import 'dart:convert';

import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/core/api/api_client/models/room_state.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';

sealed class AdmissionEvent {
  const AdmissionEvent();
}

final class AdmissionPacketReceived extends AdmissionEvent {
  const AdmissionPacketReceived(this.packet);
  final AdmissionPacket packet;
}

final class AdmissionPresenceChanged extends AdmissionEvent {
  const AdmissionPresenceChanged(this.identity, this.present);
  final String identity;
  final bool present;
}

final class AdmissionConnectionRestored extends AdmissionEvent {
  const AdmissionConnectionRestored();
}

final class AdmissionRoomEnded extends AdmissionEvent {
  const AdmissionRoomEnded();
}

/// A terminal SDK disconnection, not RoomReconnectingEvent/RoomResumingEvent.
final class AdmissionRoomDisconnected extends AdmissionEvent {
  const AdmissionRoomDisconnected(this.reason);
  final DisconnectReason? reason;
}

/// An admission-only channel; it does not own the room or publish local media.
abstract class AdmissionChannel {
  String get localIdentity;
  bool get hasEnded;
  Iterable<String> get remoteIdentities;
  bool isPresent(String identity);
  Stream<AdmissionEvent> get events;
  Future<void> send(AdmissionPacket packet);
}

/// Create the room connection with [pendingConnectOptions] BEFORE connecting.
/// Data packets remain available when remote media auto-subscription is off.
/// Own this transport until admission ends and call [dispose] before room teardown.
class LiveKitAdmissionTransport implements AdmissionChannel {
  LiveKitAdmissionTransport(this.room) {
    _checkRoomEnded(room.metadata);
    _listener = room.createListener()
      ..on<DataReceivedEvent>((event) {
        if (event.topic != AdmissionProtocol.topic) return;
        final packet = AdmissionProtocol.decode(
          event.data,
          senderIdentity: event.participant?.identity,
          now: DateTime.now(),
        );
        if (packet != null) {
          _events.add(AdmissionPacketReceived(packet));
          if (packet is AdmissionHello &&
              packet.senderIdentity == _joinReceipt?.recipientIdentity &&
              packet.recipientIdentity == localIdentity) {
            _retryJoinReceipt();
          }
        }
      })
      ..on<ParticipantConnectedEvent>((event) {
        _events.add(AdmissionPresenceChanged(event.participant.identity, true));
        if (event.participant.identity == _joinReceipt?.recipientIdentity) {
          _retryJoinReceipt();
        }
      })
      ..on<ParticipantDisconnectedEvent>(
        (event) => _events.add(
          AdmissionPresenceChanged(event.participant.identity, false),
        ),
      )
      ..on<RoomMetadataChangedEvent>((event) => _checkRoomEnded(event.metadata))
      ..on<RoomConnectedEvent>((event) {
        _checkRoomEnded(event.metadata);
        if (!_ended) {
          _events.add(const AdmissionConnectionRestored());
          _retryJoinReceipt();
        }
      })
      ..on<RoomReconnectedEvent>((_) {
        _checkRoomEnded(room.metadata);
        if (!_ended) {
          _events.add(const AdmissionConnectionRestored());
          _retryJoinReceipt();
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        _joinReceipt = null;
        if (!_ended) _events.add(AdmissionRoomDisconnected(event.reason));
      });
  }

  static const pendingConnectOptions = ConnectOptions(autoSubscribe: false);

  final Room room;
  final _events = StreamController<AdmissionEvent>.broadcast(sync: true);
  late final EventsListener<RoomEvent> _listener;
  bool _disposed = false;
  AdmissionPacket? _joinReceipt;

  bool _ended = false;

  @override
  bool get hasEnded => _ended;

  void _checkRoomEnded(String? metadata) {
    if (_ended || metadata == null || metadata.isEmpty) return;
    late final RoomState state;
    try {
      state = RoomState.fromJson(jsonDecode(metadata) as Map<String, dynamic>);
    } catch (_) {
      // Ignore malformed room metadata; only a canonical RoomState can end admission.
      return;
    }
    if (state.status == RoomStatus.ended) {
      _ended = true;
      _joinReceipt = null;
      _events.add(const AdmissionRoomEnded());
    }
  }

  @override
  String get localIdentity => room.localParticipant?.identity ?? '';

  @override
  Iterable<String> get remoteIdentities =>
      room.remoteParticipants.values.map((participant) => participant.identity);

  @override
  bool isPresent(String identity) =>
      room.remoteParticipants.values.any((p) => p.identity == identity);

  @override
  Stream<AdmissionEvent> get events => _events.stream;

  @override
  Future<void> send(AdmissionPacket packet) async {
    if (_disposed) throw StateError('Admission transport disposed');
    final local = room.localParticipant;
    if (local == null ||
        packet.senderIdentity != local.identity ||
        packet.recipientIdentity.isEmpty) {
      throw StateError('Admission sender is not connected');
    }
    final data = AdmissionProtocol.encode(packet);
    if (data.length > AdmissionProtocol.maxPayloadBytes) {
      throw ArgumentError('Admission packet exceeds size limit');
    }
    if ((packet is AdmissionJoined || packet is AdmissionJoinFailed) &&
        (packet.recipientIdentity == local.identity ||
            AdmissionProtocol.decode(
                  data,
                  senderIdentity: local.identity,
                  now: DateTime.now(),
                ) ==
                null)) {
      throw ArgumentError('Invalid or expired admission receipt');
    }
    await local.publishData(
      data,
      reliable: true,
      topic: AdmissionProtocol.topic,
      destinationIdentities: [packet.recipientIdentity],
    );
  }

  /// Call on a NEW normal room connection, after SessionController.join has
  /// succeeded. Retain this transport until room teardown so keeper presence,
  /// hello, or reconnect can trigger a one-shot receipt retry before expiry.
  Future<void> sendJoinOutcome(
    AdmissionRequest request, {
    bool joined = true,
  }) async {
    if (_disposed || _ended) {
      throw StateError('Admission transport unavailable');
    }
    if (_joinReceipt != null) throw StateError('Join outcome already sent');
    final receipt = joined
        ? AdmissionProtocol.joined(request)
        : AdmissionProtocol.joinFailed(request);
    if (receipt.senderIdentity != localIdentity ||
        receipt.recipientIdentity == localIdentity ||
        AdmissionProtocol.decode(
              AdmissionProtocol.encode(receipt),
              senderIdentity: localIdentity,
              now: DateTime.now(),
            ) ==
            null) {
      throw ArgumentError('Invalid or expired admission receipt');
    }
    _joinReceipt = receipt;
    await send(receipt);
  }

  void _retryJoinReceipt() {
    final receipt = _joinReceipt;
    if (_disposed || _ended || receipt == null) return;
    if (!DateTime.now().isBefore(receipt.expiresAt)) {
      _joinReceipt = null;
      return;
    }
    unawaited(send(receipt).catchError((Object _) {}));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _joinReceipt = null;
    await _listener.dispose();
    await _events.close();
  }
}

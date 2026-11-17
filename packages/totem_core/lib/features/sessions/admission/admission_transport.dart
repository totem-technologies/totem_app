import 'dart:async';
import 'dart:convert';

import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/core/api/api_client/models/room_state.dart';
import 'package:totem_core/features/sessions/admission/admission_join_receipt.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

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
  final SessionTransportDisconnectReason? reason;
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
  LiveKitAdmissionTransport(this.room, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _receipts = AdmissionJoinReceipt(
      localIdentity: () => localIdentity,
      send: send,
      now: _now,
    );
    _checkRoomEnded(room.metadata);
    _listener = room.createListener()
      ..on<DataReceivedEvent>((event) {
        if (_disposed || event.topic != AdmissionProtocol.topic) return;
        final packet = AdmissionProtocol.decode(
          event.data,
          senderIdentity: event.participant?.identity,
          now: _now(),
        );
        if (packet != null) {
          _emit(AdmissionPacketReceived(packet));
        }
      })
      ..on<ParticipantConnectedEvent>((event) {
        _emit(AdmissionPresenceChanged(event.participant.identity, true));
      })
      ..on<ParticipantDisconnectedEvent>(
        (event) =>
            _emit(AdmissionPresenceChanged(event.participant.identity, false)),
      )
      ..on<RoomMetadataChangedEvent>((event) => _checkRoomEnded(event.metadata))
      ..on<RoomConnectedEvent>((event) {
        _checkRoomEnded(event.metadata);
        if (!_ended) {
          _emit(const AdmissionConnectionRestored());
        }
      })
      ..on<RoomReconnectedEvent>((_) {
        _checkRoomEnded(room.metadata);
        if (!_ended) {
          _emit(const AdmissionConnectionRestored());
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        _receipts.stop();
        if (!_ended) {
          _emit(
            AdmissionRoomDisconnected(
              event.reason == null
                  ? null
                  : SessionTransportDisconnectReason.values.byName(
                      event.reason!.name,
                    ),
            ),
          );
        }
      });
  }

  void _emit(AdmissionEvent event) {
    if (_disposed) return;
    _events.add(event);
    _receipts.handle(event);
  }

  static const pendingConnectOptions = ConnectOptions(autoSubscribe: false);

  final Room room;
  final DateTime Function() _now;
  final _events = StreamController<AdmissionEvent>.broadcast(sync: true);
  late final EventsListener<RoomEvent> _listener;
  bool _disposed = false;
  late final AdmissionJoinReceipt _receipts;

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
      _emit(const AdmissionRoomEnded());
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
                  now: _now(),
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
  /// succeeded. Retain this transport until room teardown so Keeper presence,
  /// hello, or reconnect can retry the receipt until confirmation or expiry.
  Future<void> sendJoinOutcome(
    AdmissionRequest request, {
    bool joined = true,
  }) => _receipts.sendOutcome(request, joined: joined);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _receipts.dispose();
    await _listener.dispose();
    await _events.close();
  }
}

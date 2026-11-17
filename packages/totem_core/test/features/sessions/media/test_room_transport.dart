import 'dart:async';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';
import 'fake_local_media.dart';
import 'fake_room_media.dart';

/// Compatibility for existing SDK-shaped fixtures only. Tests own this adapter;
/// it forwards packets without owning the fixture room or capture tracks.
class TestRoomTransport implements SessionTransport {
  TestRoomTransport(this.room, {this.extraParticipants}) {
    _listener = room.createListener()
      ..on<sdk.DataReceivedEvent>(
        (event) => _events.add(TransportPacketReceived(packetFromSdk(event))),
      )
      ..on<sdk.ParticipantConnectedEvent>(
        (event) => _events.add(
          TransportParticipantChanged(
            _participant(event.participant),
            present: true,
          ),
        ),
      )
      ..on<sdk.ParticipantDisconnectedEvent>(
        (event) => _events.add(
          TransportParticipantChanged(
            _participant(event.participant),
            present: false,
          ),
        ),
      )
      ..on<sdk.RoomMetadataChangedEvent>(
        (event) => _events.add(TransportMetadataChanged(event.metadata)),
      )
      ..on<sdk.RoomReconnectedEvent>(
        (_) => _events.add(
          const TransportConnectionChanged(
            SessionTransportConnectionState.connected,
            reconnected: true,
          ),
        ),
      )
      ..on<sdk.RoomDisconnectedEvent>(
        (event) => _events.add(
          TransportConnectionChanged(
            SessionTransportConnectionState.disconnected,
            reason: event.reason == null
                ? null
                : SessionTransportDisconnectReason.values.byName(
                    event.reason!.name,
                  ),
          ),
        ),
      );
  }
  final sdk.Room room;
  final Iterable<ParticipantInfo> Function()? extraParticipants;
  late final sdk.EventsListener<sdk.RoomEvent> _listener;
  final _events = StreamController<SessionTransportEvent>.broadcast(sync: true);
  Future<void>? _disposing;
  @override
  final LocalMedia localMedia = FakeLocalMedia();
  @override
  final RoomMedia roomMedia = FakeRoomMedia();
  @override
  String? get localIdentity => room.localParticipant?.identity;
  @override
  String? get metadata => room.metadata;
  @override
  SessionTransportConnectionState get connectionState {
    try {
      return SessionTransportConnectionState.values.byName(
        room.connectionState.name,
      );
    } catch (_) {
      return SessionTransportConnectionState.connected;
    }
  }

  @override
  List<ParticipantInfo> get participants => [
    if (room.localParticipant case final local?)
      _participant(local, local: true),
    for (final remote in room.remoteParticipants.values) _participant(remote),
    ...?extraParticipants?.call().where(
      (p) =>
          p.identity != localIdentity &&
          !room.remoteParticipants.values.any(
            (remote) => remote.identity == p.identity,
          ),
    ),
  ];
  @override
  Stream<SessionTransportEvent> get events => _events.stream;
  @override
  Future<void> prepare(String url, String token) async {}
  @override
  Future<void> connect(
    String url,
    String token, {
    bool autoSubscribe = true,
  }) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> publish(SessionTransportPacket packet) async {
    await room.localParticipant!.publishData(
      packet.bytes,
      topic: packet.topic,
      reliable: packet.reliable,
      destinationIdentities: packet.recipients.isEmpty
          ? null
          : packet.recipients,
    );
  }

  @override
  void setSubscriptionPermissions({
    required bool allowEveryone,
    required Set<String> recipients,
  }) {}
  @override
  Future<void> subscribeToExistingMedia() async {}
  @override
  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    await _listener.dispose();
    await _events.close();
  }
}

ParticipantInfo _participant(
  sdk.Participant participant, {
  bool local = false,
}) {
  String name;
  try {
    name = participant.name;
  } catch (_) {
    name = participant.identity;
  }
  return ParticipantInfo(
    sid: participant.identity,
    identity: participant.identity,
    name: name,
    isLocal: local,
  );
}

SessionTransportPacket packetFromSdk(sdk.DataReceivedEvent event) =>
    SessionTransportPacket(
      bytes: event.data,
      topic: event.topic ?? '',
      sender: event.participant == null
          ? null
          : _participant(event.participant!),
    );

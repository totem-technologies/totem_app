import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
// The pinned SDK exposes canPublishSources using this protobuf enum but does
// not export it from its public library.
// ignore: implementation_imports
import 'package:livekit_client/src/proto/livekit_models.pbenum.dart' as proto;
import 'package:totem_core/features/sessions/admission/server_admission_connection.dart';
import 'package:totem_core/features/sessions/services/session_packet_router.dart';

/// Observes admission signals without taking ownership of the connected Room.
class LiveKitServerAdmissionConnection implements ServerAdmissionConnection {
  LiveKitServerAdmissionConnection(this.room) {
    _listener = room.createListener()
      ..on<ParticipantPermissionsUpdatedEvent>((event) {
        if (event.participant == room.localParticipant) {
          _emit(ServerAdmissionConnectionEvent.permissionsChanged);
        }
      })
      ..on<RoomReconnectedEvent>(
        (_) => _emit(ServerAdmissionConnectionEvent.reconnected),
      )
      ..on<RoomReconnectingEvent>(
        (_) => _emit(ServerAdmissionConnectionEvent.disconnected),
      )
      ..on<RoomResumingEvent>(
        (_) => _emit(ServerAdmissionConnectionEvent.disconnected),
      )
      ..on<RoomDisconnectedEvent>(
        (_) => _emit(ServerAdmissionConnectionEvent.terminated),
      )
      ..on<ParticipantConnectedEvent>(
        (_) => _emit(ServerAdmissionConnectionEvent.presenceChanged),
      )
      ..on<ParticipantDisconnectedEvent>(
        (_) => _emit(ServerAdmissionConnectionEvent.presenceChanged),
      )
      ..on<RoomMetadataChangedEvent>(
        (_) => _emit(ServerAdmissionConnectionEvent.notification),
      )
      ..on<DataReceivedEvent>((event) {
        if (event.topic == SessionCommunicationTopics.admission.topic) {
          _emit(ServerAdmissionConnectionEvent.notification);
        }
      });
  }

  final Room room;
  late final EventsListener<RoomEvent> _listener;
  final _events = StreamController<ServerAdmissionConnectionEvent>.broadcast(
    sync: true,
  );
  bool _disposed = false;
  Future<void>? _disposal;

  void _emit(ServerAdmissionConnectionEvent event) {
    if (!_disposed) _events.add(event);
  }

  @override
  bool get isConnected => room.connectionState == ConnectionState.connected;

  @override
  bool get hasMediaPermissions {
    final permission = room.localParticipant?.permissions;
    return permission != null &&
        permission.canPublish &&
        permission.canSubscribe &&
        permission.canPublishData &&
        (permission.canPublishSources.isEmpty ||
            (permission.canPublishSources.contains(proto.TrackSource.CAMERA) &&
                permission.canPublishSources.contains(
                  proto.TrackSource.MICROPHONE,
                ))) &&
        !permission.canUpdateMetadata &&
        !permission.hidden;
  }

  @override
  String get localSid => room.localParticipant?.sid ?? '';

  @override
  bool isPresent(String identity) =>
      room.localParticipant?.identity == identity ||
      room.remoteParticipants.values.any(
        (participant) => participant.identity == identity,
      );

  @override
  Stream<ServerAdmissionConnectionEvent> get admissionEvents => _events.stream;

  @override
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _listener.dispose();
    await _events.close();
  }
}

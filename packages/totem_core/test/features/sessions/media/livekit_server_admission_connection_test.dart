import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:livekit_client/src/proto/livekit_models.pbenum.dart' as proto;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/admission/server_admission_connection.dart';
import 'package:totem_core/features/sessions/media/livekit_server_admission_connection.dart';

import '../livekit_mocks.dart';

class _Room extends Fake implements sdk.Room {
  _Room(this.localParticipant);

  @override
  sdk.LocalParticipant? localParticipant;
  @override
  final events = sdk.EventsEmitter<sdk.RoomEvent>();
  int disconnects = 0;
  int disposals = 0;

  @override
  sdk.EventsListener<sdk.RoomEvent> createListener({
    bool synchronized = false,
  }) => sdk.EventsListener(events, synchronized: synchronized);

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  Future<bool> dispose() async {
    disposals++;
    return true;
  }
}

void main() {
  late MockLocalParticipant local;
  late _Room room;
  late LiveKitServerAdmissionConnection connection;

  setUp(() {
    local = MockLocalParticipant('local');
    room = _Room(local);
    connection = LiveKitServerAdmissionConnection(room);
  });

  tearDown(() async {
    await connection.dispose();
    await room.events.dispose();
  });

  test('initial permissions require media grants and restricted identity', () {
    when(
      () => local.permissions,
    ).thenReturn(const sdk.ParticipantPermissions());
    check(connection.hasMediaPermissions).isFalse();
    const allowed = sdk.ParticipantPermissions(
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    );
    when(() => local.permissions).thenReturn(allowed);
    check(connection.hasMediaPermissions).isTrue();

    for (final permissions in [
      const sdk.ParticipantPermissions(
        canSubscribe: true,
        canPublishData: true,
      ),
      const sdk.ParticipantPermissions(canPublish: true, canPublishData: true),
      const sdk.ParticipantPermissions(canPublish: true, canSubscribe: true),
      const sdk.ParticipantPermissions(
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
        hidden: true,
      ),
      const sdk.ParticipantPermissions(
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
        canUpdateMetadata: true,
      ),
    ]) {
      when(() => local.permissions).thenReturn(permissions);
      check(connection.hasMediaPermissions).isFalse();
    }
    room.localParticipant = null;
    check(connection.hasMediaPermissions).isFalse();
  });

  test('publish source allowlist must include camera and microphone', () {
    for (final sources in [
      <proto.TrackSource>[],
      [proto.TrackSource.CAMERA, proto.TrackSource.MICROPHONE],
      [
        proto.TrackSource.SCREEN_SHARE,
        proto.TrackSource.MICROPHONE,
        proto.TrackSource.CAMERA,
      ],
    ]) {
      when(() => local.permissions).thenReturn(
        sdk.ParticipantPermissions(
          canPublish: true,
          canSubscribe: true,
          canPublishData: true,
          canPublishSources: sources,
        ),
      );
      check(connection.hasMediaPermissions).isTrue();
    }
    for (final sources in [
      [proto.TrackSource.CAMERA],
      [proto.TrackSource.MICROPHONE],
      [proto.TrackSource.SCREEN_SHARE, proto.TrackSource.SCREEN_SHARE_AUDIO],
      [proto.TrackSource.UNKNOWN],
    ]) {
      when(() => local.permissions).thenReturn(
        sdk.ParticipantPermissions(
          canPublish: true,
          canSubscribe: true,
          canPublishData: true,
          canPublishSources: sources,
        ),
      );
      check(connection.hasMediaPermissions).isFalse();
    }
  });

  test(
    'permission updates are emitted only for the local participant',
    () async {
      final events = <ServerAdmissionConnectionEvent>[];
      final subscription = connection.admissionEvents.listen(events.add);
      addTearDown(subscription.cancel);
      const permissions = sdk.ParticipantPermissions();
      final remote = MockRemoteParticipant('remote', 'Remote');
      room.events.emit(
        sdk.ParticipantPermissionsUpdatedEvent(
          participant: remote,
          permissions: permissions,
          oldPermissions: permissions,
        ),
      );
      room.events.emit(
        sdk.ParticipantPermissionsUpdatedEvent(
          participant: local,
          permissions: permissions,
          oldPermissions: permissions,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      check(
        events,
      ).deepEquals([ServerAdmissionConnectionEvent.permissionsChanged]);
    },
  );

  test(
    'maps admission notifications, presence, reconnect and terminal events',
    () async {
      final events = <ServerAdmissionConnectionEvent>[];
      final subscription = connection.admissionEvents.listen(events.add);
      addTearDown(subscription.cancel);
      final remote = MockRemoteParticipant('remote', 'Remote');
      room.events.emit(
        const sdk.DataReceivedEvent(
          participant: null,
          data: [],
          topic: 'totem.admission.v1',
        ),
      );
      room.events.emit(
        const sdk.DataReceivedEvent(participant: null, data: [], topic: null),
      );
      room.events.emit(
        const sdk.DataReceivedEvent(
          participant: null,
          data: [],
          topic: 'totem.admission.v2',
        ),
      );
      room.events.emit(const sdk.RoomMetadataChangedEvent(metadata: 'state'));
      room.events.emit(sdk.ParticipantConnectedEvent(participant: remote));
      room.events.emit(sdk.ParticipantDisconnectedEvent(participant: remote));
      room.events.emit(const sdk.RoomReconnectingEvent());
      room.events.emit(const sdk.RoomResumingEvent());
      room.events.emit(const sdk.RoomReconnectedEvent());
      room.events.emit(
        sdk.RoomDisconnectedEvent(reason: sdk.DisconnectReason.clientInitiated),
      );
      await Future<void>.delayed(Duration.zero);
      check(events).deepEquals([
        ServerAdmissionConnectionEvent.notification,
        ServerAdmissionConnectionEvent.notification,
        ServerAdmissionConnectionEvent.presenceChanged,
        ServerAdmissionConnectionEvent.presenceChanged,
        ServerAdmissionConnectionEvent.disconnected,
        ServerAdmissionConnectionEvent.disconnected,
        ServerAdmissionConnectionEvent.reconnected,
        ServerAdmissionConnectionEvent.terminated,
      ]);
    },
  );

  test('dispose stops notifications without owning the room', () async {
    final events = <ServerAdmissionConnectionEvent>[];
    var closed = false;
    final subscription = connection.admissionEvents.listen(
      events.add,
      onDone: () => closed = true,
    );
    addTearDown(subscription.cancel);
    await connection.dispose();
    await connection.dispose();
    room.events.emit(const sdk.RoomReconnectedEvent());
    await Future<void>.value();
    check(closed).isTrue();
    check(events).isEmpty();
    check(room.disconnects).equals(0);
    check(room.disposals).equals(0);
  });
}

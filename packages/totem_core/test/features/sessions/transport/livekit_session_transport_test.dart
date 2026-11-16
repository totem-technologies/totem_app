import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/media/livekit_session_transport.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';
import '../livekit_mocks.dart';

class _Room extends FakeRoom {
  _Room(super.participant);
  final transportEvents = sdk.EventsEmitter<sdk.RoomEvent>();
  int connections = 0;
  int disposals = 0;
  sdk.ConnectOptions? connectedOptions;
  sdk.LiveKitException? failure;
  @override
  sdk.ConnectionState connectionState = sdk.ConnectionState.disconnected;
  @override
  sdk.EventsListener<sdk.RoomEvent> createListener({
    bool synchronized = false,
  }) => sdk.EventsListener(transportEvents, synchronized: synchronized);
  @override
  Future<void> prepareConnection(String url, String? token) async {}
  @override
  Future<void> connect(
    String url,
    String token, {
    sdk.ConnectOptions? connectOptions,
    sdk.FastConnectOptions? fastConnectOptions,
    sdk.RoomOptions? roomOptions,
  }) async {
    connections++;
    connectedOptions = connectOptions;
    if (failure case final sdk.LiveKitException error) throw error;
    connectionState = sdk.ConnectionState.connected;
    transportEvents.emit(sdk.RoomConnectedEvent(room: this, metadata: null));
  }

  @override
  Future<void> disconnect() async {
    connectionState = sdk.ConnectionState.disconnected;
    transportEvents.emit(
      sdk.RoomDisconnectedEvent(reason: sdk.DisconnectReason.clientInitiated),
    );
  }

  @override
  Future<bool> dispose() async {
    disposals++;
    return true;
  }
}

void main() {
  test(
    'LiveKit adapter delivers translated packets and disconnects without leaking SDK events',
    () async {
      final participant = MockLocalParticipant('local');
      when(participant.unpublishAllTracks).thenAnswer((_) async {});
      when(
        () => participant.publishData(
          any(),
          reliable: any(named: 'reliable'),
          topic: any(named: 'topic'),
          destinationIdentities: any(named: 'destinationIdentities'),
        ),
      ).thenAnswer((_) async {});
      final room = _Room(participant);
      final transport = LiveKitSessionTransport(
        room: room,
        cameraOptions: const sdk.CameraCaptureOptions(),
      );
      final events = <SessionTransportEvent>[];
      final subscription = transport.events.listen(events.add);
      try {
        await transport.connect('url', 'token', autoSubscribe: false);
        check(room.connectedOptions!.autoSubscribe).isFalse();
        check(transport.localIdentity).equals('local');
        room.connectionState = sdk.ConnectionState.reconnecting;
        room.transportEvents.emit(const sdk.RoomReconnectingEvent());
        await Future<void>.value();
        check(
          events.whereType<TransportConnectionChanged>().last.state,
        ).equals(SessionTransportConnectionState.reconnecting);
        room.connectionState = sdk.ConnectionState.connected;
        room.transportEvents.emit(const sdk.RoomReconnectedEvent());
        final receivedMetadata = transport.events.firstWhere(
          (event) => event is TransportMetadataChanged,
        );
        final participantLeft = transport.events.firstWhere(
          (event) => event is TransportParticipantChanged && !event.present,
        );
        room.transportEvents.emit(
          const sdk.RoomMetadataChangedEvent(metadata: 'versioned state'),
        );
        final remote = MockRemoteParticipant('keeper', 'Keeper');
        room.transportEvents.emit(
          sdk.ParticipantConnectedEvent(participant: remote),
        );
        room.transportEvents.emit(
          sdk.ParticipantDisconnectedEvent(participant: remote),
        );
        await receivedMetadata;
        await participantLeft;
        check(
          events.whereType<TransportMetadataChanged>().single.metadata,
        ).equals('versioned state');
        check(
          events
              .whereType<TransportParticipantChanged>()
              .map((e) => e.present)
              .toList(),
        ).deepEquals([true, false]);
        transport.setSubscriptionPermissions(
          allowEveryone: false,
          recipients: {'keeper'},
        );

        await transport.publish(
          SessionTransportPacket(
            bytes: [1],
            topic: 'chat',
            reliable: true,
            recipients: ['keeper'],
          ),
        );
        verify(
          () => participant.publishData(
            [1],
            reliable: true,
            topic: 'chat',
            destinationIdentities: ['keeper'],
          ),
        ).called(1);
        final originalPacket = sdk.DataReceivedEvent(
          participant: remote,
          data: [2],
          topic: 'chat',
        );
        room.transportEvents.emit(originalPacket);
        await Future<void>.value();
        check(
          events.whereType<TransportPacketReceived>().single.packet.bytes,
        ).deepEquals([2]);
        // Sender identity survives presence removal without retaining SDK events.
        final received = events
            .whereType<TransportPacketReceived>()
            .single
            .packet;
        check(received.sender?.identity).equals('keeper');
        await transport.disconnect();
        await Future<void>.value();
        check(
          events.whereType<TransportConnectionChanged>().last.reason,
        ).equals(SessionTransportDisconnectReason.clientInitiated);
        await transport.dispose();
        await transport.dispose();
        final count = events.length;
        room.transportEvents.emit(
          const sdk.DataReceivedEvent(
            participant: null,
            data: [3],
            topic: 'chat',
          ),
        );
        await Future<void>.value();
        check(events).length.equals(count);
        check(room.disposals).equals(1);
        verify(participant.unpublishAllTracks).called(1);
      } finally {
        await subscription.cancel();
        await transport.dispose();
        await room.transportEvents.dispose();
      }
    },
  );

  test(
    'SDK failures preserve cause and stack in an application-owned failure',
    () {
      final error = sdk.ConnectException(
        'denied',
        reason: sdk.ConnectionErrorReason.NotAllowed,
      );
      final stack = StackTrace.current;
      final failure = LiveKitSessionTransport.failure(error, stack);
      check(failure.kind).equals(SessionTransportFailureKind.connection);
      check(
        failure.connectionFailure,
      ).equals(SessionTransportConnectionFailure.notAllowed);
      check(identical(failure.cause, error)).isTrue();
      check(identical(failure.stackTrace, stack)).isTrue();
    },
  );
}

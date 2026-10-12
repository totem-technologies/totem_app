// ignore_for_file: invalid_use_of_internal_member

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/media/livekit_room_media.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';

import '../livekit_mocks.dart';

class _MockRoom extends Mock implements Room {}

class _MockRemoteParticipant extends Mock implements RemoteParticipant {}

void main() {
  group('LiveKitRoomMedia', () {
    late EventsEmitter<RoomEvent> roomEvents;
    late _MockRoom room;
    late _MockRemoteParticipant remote;
    late MockRemoteTrackPublication<RemoteVideoTrack> camera;
    late MockRemoteVideoTrack cameraTrack;
    late LiveKitRoomMedia media;

    setUp(() {
      roomEvents = EventsEmitter<RoomEvent>();
      room = _MockRoom();
      remote = _MockRemoteParticipant();
      camera = MockRemoteTrackPublication<RemoteVideoTrack>();
      cameraTrack = MockRemoteVideoTrack();
      when(room.createListener).thenAnswer((_) => EventsListener(roomEvents));
      when(() => room.getParticipantByIdentity('remote')).thenReturn(remote);
      when(() => remote.hasAudio).thenReturn(false);
      when(() => remote.isMuted).thenReturn(false);
      when(() => remote.hasVideo).thenReturn(true);
      when(() => remote.videoTrackPublications).thenReturn([camera]);
      when(() => camera.muted).thenReturn(false);
      when(() => camera.track).thenReturn(cameraTrack);
      when(() => cameraTrack.muted).thenReturn(false);
      media = LiveKitRoomMedia()..attach(room);
    });

    tearDown(() {
      media.attach(null);
    });

    test('a remote camera is on before its track finishes starting', () async {
      // LiveKit reports a subscribed track before starting it locally, and
      // sends no event once it has started.
      when(() => cameraTrack.isActive).thenReturn(false);

      final state = await media.watch('remote').first;

      check(state.isCameraOn).isTrue();
    });

    test('a remote camera muted by its owner is off', () async {
      when(() => cameraTrack.isActive).thenReturn(true);
      when(() => camera.muted).thenReturn(true);
      when(() => cameraTrack.muted).thenReturn(true);

      final state = await media.watch('remote').first;

      check(state)
        ..has((s) => s.hasCamera, 'hasCamera').isTrue()
        ..has((s) => s.isCameraOn, 'isCameraOn').isFalse();
    });

    test('reports changes from room events, without repeats', () async {
      when(() => cameraTrack.isActive).thenReturn(true);
      final states = <ParticipantMediaState>[];
      final subscription = media.watch('remote').listen(states.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      when(() => camera.muted).thenReturn(true);
      when(() => cameraTrack.muted).thenReturn(true);
      roomEvents
        ..emit(TrackMutedEvent(participant: remote, publication: camera))
        ..emit(TrackMutedEvent(participant: remote, publication: camera));
      await pumpEventQueue();

      check(states.map((s) => s.isCameraOn)).deepEquals([true, false]);
    });
  });
}

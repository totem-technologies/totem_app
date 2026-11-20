import 'dart:collection';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/media/livekit_room_media.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';

import '../livekit_mocks.dart';

class _MockRoom extends Mock implements Room {}

class _MockRemoteParticipant extends Mock implements RemoteParticipant {}

class _BarCanvas implements Canvas {
  final heights = <double>[];

  @override
  void drawRRect(RRect rrect, Paint paint) => heights.add(rrect.height);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
      when(
        () => remote.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(camera);
      when(() => camera.muted).thenReturn(false);
      when(() => camera.track).thenReturn(cameraTrack);
      when(() => cameraTrack.muted).thenReturn(false);
      media = LiveKitRoomMedia()..attach(room);
    });

    tearDown(() {
      media.attach(null);
    });

    test('speaker reports follow silence and room replacement', () async {
      final speakers = <Participant>[];
      when(() => room.connectionState).thenReturn(ConnectionState.connected);
      when(
        () => room.activeSpeakers,
      ).thenAnswer((_) => UnmodifiableListView(speakers));
      when(() => remote.identity).thenReturn('remote');
      when(() => remote.audioLevel).thenReturn(0.7);
      final levels = <double>[];
      final subscription = media.watchAudioLevel('remote').listen(levels.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      speakers.add(remote);
      roomEvents.emit(ActiveSpeakersChangedEvent(speakers: speakers));
      await pumpEventQueue();
      speakers.clear();
      roomEvents.emit(ActiveSpeakersChangedEvent(speakers: speakers));
      await pumpEventQueue();
      speakers.add(remote);
      roomEvents.emit(ActiveSpeakersChangedEvent(speakers: speakers));
      await pumpEventQueue();
      when(() => room.getParticipantByIdentity('remote')).thenReturn(null);
      roomEvents.emit(ParticipantDisconnectedEvent(participant: remote));
      await pumpEventQueue();
      when(() => room.getParticipantByIdentity('remote')).thenReturn(remote);
      roomEvents.emit(ActiveSpeakersChangedEvent(speakers: speakers));
      await pumpEventQueue();
      media.attach(null);
      await pumpEventQueue();
      roomEvents.emit(ActiveSpeakersChangedEvent(speakers: speakers));
      await pumpEventQueue();

      check(levels).deepEquals([0.0, 0.7, 0.0, 0.7, 0.0, 0.7, 0.0]);
    });

    testWidgets(
      'speaker events update the rendered waveform for the same participant',
      (tester) async {
        final speakers = <Participant>[remote];
        var amplitude = 0.0;
        when(() => room.connectionState).thenReturn(ConnectionState.connected);
        when(
          () => room.activeSpeakers,
        ).thenAnswer((_) => UnmodifiableListView(speakers));
        when(() => remote.identity).thenReturn('remote');
        when(() => remote.audioLevel).thenAnswer((_) => amplitude);
        when(() => remote.hasAudio).thenReturn(true);

        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: media.microphoneLevel(
                  const ParticipantInfo(
                    sid: 'sid',
                    identity: 'remote',
                    name: 'Remote',
                  ),
                  color: Colors.white,
                  iconSize: 20,
                ),
              ),
            ),
          ),
        );

        double intensity() {
          final finder = find.descendant(
            of: find.byType(LevelBars),
            matching: find.byType(CustomPaint),
          );
          final canvas = _BarCanvas();
          tester
              .widget<CustomPaint>(finder)
              .painter!
              .paint(canvas, tester.getSize(finder));
          return canvas.heights.reduce((a, b) => a + b);
        }

        var previous = intensity();
        for (final sample in [0.125, 0.25, 0.5, 1.0]) {
          amplitude = sample;
          roomEvents.emit(ActiveSpeakersChangedEvent(speakers: speakers));
          await tester.pump();
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 70));
          }
          final current = intensity();
          check(current > previous).isTrue();
          previous = current;
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

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

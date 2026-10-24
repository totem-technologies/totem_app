// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_client/src/core/engine.dart';
import 'package:livekit_client/src/core/signal_client.dart';
import 'package:livekit_client/src/proto/livekit_models.pb.dart' as proto;
import 'package:livekit_client/src/proto/livekit_rtc.pb.dart' as rtc_proto;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/media/livekit_local_media.dart';

class _Room extends Mock implements Room {}

class _Engine extends Mock implements Engine {}

class _Stream extends Mock implements rtc.MediaStream {}

class _DeviceTrack extends Mock implements rtc.MediaStreamTrack {}

class _AudioTrack extends LocalAudioTrack {
  _AudioTrack(rtc.MediaStream stream, rtc.MediaStreamTrack track)
    : super(TrackSource.microphone, stream, track, const AudioCaptureOptions());

  @override
  Future<void> startCapture() async {}
  @override
  Future<void> stopCapture() async {}
  @override
  void startMonitor() {}
}

void main() {
  setUpAll(() => registerFallbackValue(rtc_proto.AddTrackRequest()));

  // Uses the real LocalParticipant so LiveKit's publish queue and
  // unpublishing behave as in production.
  test(
    'release stops a microphone whose publication is still in flight',
    () async {
      final room = _Room();
      final engine = _Engine();
      final signal = SignalClient((
        uri, {
        options,
        headers,
        networkOptions,
      }) async {
        throw StateError('Network access is forbidden in this test');
      });
      final events = EventsEmitter<RoomEvent>();
      when(() => room.engine).thenReturn(engine);
      when(() => engine.signalClient).thenReturn(signal);
      when(() => room.events).thenReturn(events);
      when(room.createListener).thenAnswer((_) => EventsListener(events));
      when(
        () => room.roomOptions,
      ).thenReturn(LiveKitLocalMedia.applyCapturePolicy(const RoomOptions()));
      when(engine.negotiate).thenAnswer((_) async {});

      final publishing = Completer<void>();
      final publicationReply = Completer<proto.TrackInfo>();
      when(() => engine.addTrack(any())).thenAnswer((_) {
        publishing.complete();
        return publicationReply.future;
      });
      final participant = await LocalParticipant.createFromInfo(
        room: room,
        info: proto.ParticipantInfo(
          sid: 'local',
          identity: 'local',
          name: 'Local',
        ),
      );
      when(() => room.localParticipant).thenReturn(participant);
      final stream = _Stream();
      final deviceTrack = _DeviceTrack();
      when(() => deviceTrack.id).thenReturn('mic');
      when(deviceTrack.stop).thenAnswer((_) async {});
      when(stream.dispose).thenAnswer((_) async {});
      final track = _AudioTrack(stream, deviceTrack);
      final media = LiveKitLocalMedia(
        cameraCaptureOptions: const CameraCaptureOptions(),
      )..attach(room);
      addTearDown(() async {
        await participant.unpublishAllTracks();
        media.attach(null);
        await participant.dispose();
        await track.dispose();
        await events.dispose();
        await signal.dispose();
      });

      final publish = media.publishJoinMicrophone(track, muted: false);
      await publishing.future;
      check(track.isActive).isTrue();
      check(participant.trackPublications).isEmpty();

      final release = media.release();
      publicationReply.complete(
        proto.TrackInfo(
          sid: 'mic',
          type: proto.TrackType.AUDIO,
          source: proto.TrackSource.MICROPHONE,
        ),
      );
      await Future.wait([publish, release]);
      await pumpEventQueue();

      check(track.isActive).isFalse();
      check(participant.trackPublications).isEmpty();
    },
  );
}

// ignore_for_file: invalid_use_of_internal_member

import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/media/livekit_local_media.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';

import '../../../setup.dart';
import '../livekit_mocks.dart';

class _MockRoom extends Mock implements Room {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VoidCallback restoreWebRtcChannels;

  tearDownAll(() => restoreWebRtcChannels());

  setUpAll(() {
    setupAppConfig();
    restoreWebRtcChannels = stubFlutterWebRtcChannels();
    registerFallbackValue(const AudioCaptureOptions());
    registerFallbackValue(MockLocalVideoTrack());
    registerFallbackValue(const CameraCaptureOptions());
  });

  group('LiveKitLocalMedia', () {
    late EventsEmitter<RoomEvent> roomEvents;
    late MockLocalParticipant participant;
    late _MockRoom room;
    late LiveKitLocalMedia media;
    late int changes;

    setUp(() {
      roomEvents = EventsEmitter<RoomEvent>();
      participant = MockLocalParticipant();
      room = _MockRoom();
      when(() => room.localParticipant).thenReturn(participant);
      when(() => room.roomOptions).thenReturn(const RoomOptions());
      when(room.createListener).thenAnswer((_) => EventsListener(roomEvents));
      when(
        () => participant.setMicrophoneEnabled(
          any(),
          audioCaptureOptions: any(named: 'audioCaptureOptions'),
        ),
      ).thenAnswer((_) async => null);

      media = LiveKitLocalMedia(
        cameraCaptureOptions: SessionController.defaultCameraCaptureOptions,
      );
      changes = 0;
      media.changes.listen((_) => changes++);
      media.attach(room);
    });

    tearDown(() {
      media.attach(null);
    });

    for (final error in <LiveKitException>[
      TrackPublishException(),
      UnexpectedConnectionState('cannot publish track when not connected'),
      UnexpectedStateException('Participant disposed'),
      NegotiationError('negotiation failed'),
    ]) {
      test('X14: ${error.runtimeType} is the room, not capture', () async {
        when(
          () => participant.setMicrophoneEnabled(
            any(),
            audioCaptureOptions: any(named: 'audioCaptureOptions'),
          ),
        ).thenThrow(error);

        await check(
          media.setMicrophoneEnabled(true),
        ).throws<MediaPublishException>();
      });
    }

    for (final error in <Object>[
      TrackCreateException('NotAllowedError: Permission denied'),
      Exception('NotReadableError: Could not start audio source'),
    ]) {
      test('a capture error passes through: ${error.runtimeType}', () async {
        when(
          () => participant.setMicrophoneEnabled(
            any(),
            audioCaptureOptions: any(named: 'audioCaptureOptions'),
          ),
        ).thenThrow(error);

        Object? thrown;
        try {
          await media.setMicrophoneEnabled(true);
        } on Object catch (caught) {
          thrown = caught;
        }
        check(thrown).identicalTo(error);
      });
    }

    for (final enabled in [true, false]) {
      test('toggling the microphone to $enabled keeps capture open', () async {
        await media.setMicrophoneEnabled(enabled);

        final options =
            verify(
                  () => participant.setMicrophoneEnabled(
                    enabled,
                    audioCaptureOptions: captureAny(
                      named: 'audioCaptureOptions',
                    ),
                  ),
                ).captured.single
                as AudioCaptureOptions?;
        check(options)
            .isNotNull()
            .has((o) => o.stopAudioCaptureOnMute, 'stopAudioCaptureOnMute')
            .isFalse();
      });
    }

    test('rooms default to the same soft mute for server-side mutes', () {
      final options = LiveKitLocalMedia.applyCapturePolicy(
        const RoomOptions(adaptiveStream: true),
      );

      check(
        options.defaultAudioCaptureOptions.stopAudioCaptureOnMute,
      ).isFalse();
      check(options.adaptiveStream).isTrue();
    });

    test('unmuting restarts a microphone whose capture was stopped', () async {
      final publication = MockLocalAudioTrackPublication();
      final track = MockLocalAudioTrack(muted: true, isActive: false);
      when(() => publication.track).thenReturn(track);
      when(
        () => participant.getTrackPublicationBySource(TrackSource.microphone),
      ).thenReturn(publication);
      when(track.restartTrack).thenAnswer((_) async {});

      await media.setMicrophoneEnabled(true);

      verifyInOrder([
        track.restartTrack,
        () => participant.setMicrophoneEnabled(
          true,
          audioCaptureOptions: any(named: 'audioCaptureOptions'),
        ),
      ]);
    });

    test('unmuting a live microphone does not restart capture', () async {
      final publication = MockLocalAudioTrackPublication();
      final track = MockLocalAudioTrack(muted: true);
      when(() => publication.track).thenReturn(track);
      when(
        () => participant.getTrackPublicationBySource(TrackSource.microphone),
      ).thenReturn(publication);

      await media.setMicrophoneEnabled(true);

      verifyNever(track.restartTrack);
    });

    test('joining muted mutes the microphone before publishing it', () async {
      final track = MockLocalAudioTrack();
      when(
        () => participant.publishAudioTrack(track),
      ).thenAnswer((_) async => MockLocalAudioTrackPublication());

      await media.publishJoinMicrophone(track, muted: true);

      verifyInOrder([
        () => track.mute(stopOnMute: false),
        () => participant.publishAudioTrack(track),
      ]);
    });

    test('a join publish after release reports it did not publish', () async {
      when(participant.unpublishAllTracks).thenAnswer((_) async {});
      final track = MockLocalAudioTrack();

      await media.release();
      final published = await media.publishJoinMicrophone(track, muted: false);

      // The caller keeps ownership, so the unpublished track still gets
      // stopped rather than being left capturing.
      check(published).isFalse();
      verifyNever(() => participant.publishAudioTrack(track));
    });

    test('capture stays released for the room after release', () async {
      when(participant.unpublishAllTracks).thenAnswer((_) async {});

      final release = media.release();
      // A late automatic unmute during shutdown.
      final unmute = media.setMicrophoneEnabled(true);
      await Future.wait([release, unmute]);

      verifyNever(
        () => participant.setMicrophoneEnabled(
          any(),
          audioCaptureOptions: any(named: 'audioCaptureOptions'),
        ),
      );
    });

    test('reports local mutes but not remote ones', () async {
      final afterAttach = changes;

      roomEvents
        ..emit(
          TrackMutedEvent(
            participant: MockRemoteParticipant('remote', 'Remote'),
            publication: MockRemoteTrackPublication(),
          ),
        )
        ..emit(
          TrackMutedEvent(
            participant: participant,
            publication: MockLocalTrackPublication(),
          ),
        );
      await pumpEventQueue();

      check(changes).equals(afterAttach + 1);
    });

    test('stops reporting after the room is detached', () async {
      media.attach(null);
      final afterDetach = changes;

      roomEvents.emit(
        TrackMutedEvent(
          participant: participant,
          publication: MockLocalTrackPublication(),
        ),
      );
      await pumpEventQueue();

      check(changes).equals(afterDetach);
      check(media.isAvailable).isFalse();
    });

    group('switching camera facing while the camera is off', () {
      late MockLocalVideoTrack camera;
      late bool cameraMuted;

      setUp(() {
        cameraMuted = true;
        camera = MockLocalVideoTrack();
        when(() => camera.muted).thenAnswer((_) => cameraMuted);
        final publication = MockLocalTrackPublication(videoTrack: camera);
        when(
          () => participant.getTrackPublicationBySource(TrackSource.camera),
        ).thenReturn(publication);
        when(
          () => participant.setCameraEnabled(
            any(),
            cameraCaptureOptions: any(named: 'cameraCaptureOptions'),
          ),
        ).thenAnswer((_) async {
          cameraMuted = false;
          return null;
        });
        when(() => camera.restartTrack(any())).thenAnswer((_) async {});
        when(() => camera.simulcastCodecs).thenReturn({});
      });

      test('keeps the camera off and reports the new facing', () async {
        final before = changes;

        await media.switchCameraFacing();

        verifyNever(() => participant.publishVideoTrack(any()));
        verifyNever(
          () => participant.setCameraEnabled(
            any(),
            cameraCaptureOptions: any(named: 'cameraCaptureOptions'),
          ),
        );
        check(media.cameraFacing).equals(CameraFacing.back);
        check(changes).isGreaterThan(before);
      });

      test('turns the camera on facing the chosen way', () async {
        await media.switchCameraFacing();

        await media.setCameraEnabled(true);

        final restarted =
            verify(() => camera.restartTrack(captureAny())).captured.single
                as CameraCaptureOptions;
        check(restarted.cameraPosition).equals(CameraPosition.back);
      });
    });

    group('a new camera', () {
      late MockLocalVideoTrack captured;
      late LiveKitLocalMedia cameraMedia;

      setUp(() {
        captured = MockLocalVideoTrack();
        when(captured.stop).thenAnswer((_) async => true);
        when(captured.dispose).thenAnswer((_) async => true);
        when(
          () => participant.getTrackPublicationBySource(TrackSource.camera),
        ).thenReturn(null);
        cameraMedia = LiveKitLocalMedia(
          cameraCaptureOptions: SessionController.defaultCameraCaptureOptions,
          createCameraTrack: (_) async => captured,
        )..attach(room);
      });

      tearDown(() => cameraMedia.attach(null));

      test('is captured, then published', () async {
        when(() => participant.publishVideoTrack(captured)).thenAnswer(
          (_) async => MockLocalTrackPublication(videoTrack: captured),
        );

        await cameraMedia.setCameraEnabled(true);

        verify(() => participant.publishVideoTrack(captured)).called(1);
        verifyNever(captured.stop);
        verifyNever(captured.dispose);
      });

      test(
        "X14: is stopped and disposed when the room can't take it",
        () async {
          when(
            () => participant.publishVideoTrack(captured),
          ).thenThrow(TrackPublishException());

          await check(
            cameraMedia.setCameraEnabled(true),
          ).throws<MediaPublishException>();
          verify(captured.stop).called(1);
          verify(captured.dispose).called(1);
        },
      );

      test('is disposed even when stopping it fails', () async {
        when(
          () => participant.publishVideoTrack(captured),
        ).thenThrow(TrackPublishException());
        when(captured.stop).thenThrow(StateError('stop failed'));

        await check(
          cameraMedia.setCameraEnabled(true),
        ).throws<MediaPublishException>();
        verify(captured.dispose).called(1);
      });

      test('a capture failure is not a publish failure', () async {
        final refusal = TrackCreateException('NotAllowedError');
        final failing = LiveKitLocalMedia(
          cameraCaptureOptions: SessionController.defaultCameraCaptureOptions,
          createCameraTrack: (_) async => throw refusal,
        )..attach(room);
        addTearDown(() => failing.attach(null));

        Object? thrown;
        try {
          await failing.setCameraEnabled(true);
        } on Object catch (caught) {
          thrown = caught;
        }
        check(thrown).identicalTo(refusal);
        verifyNever(() => participant.publishVideoTrack(any()));
      });
    });

    group('capture lost', () {
      late List<CaptureLost> lost;
      late _CaptureTrack microphone;
      late _CaptureTrack camera;
      late MockLocalAudioTrackPublication microphonePublication;
      late MockLocalAudioTrackPublication cameraPublication;

      setUp(() {
        lost = [];
        media.captureLost.listen(lost.add);
        microphone = _CaptureTrack(TrackSource.microphone);
        camera = _CaptureTrack(TrackSource.camera);
        microphonePublication = _publicationOf(microphone);
        cameraPublication = _publicationOf(camera);
        when(
          () => participant.getTrackPublicationBySource(TrackSource.microphone),
        ).thenReturn(microphonePublication);
        when(
          () => participant.getTrackPublicationBySource(TrackSource.camera),
        ).thenReturn(cameraPublication);
        when(
          () => participant.setCameraEnabled(
            any(),
            cameraCaptureOptions: any(named: 'cameraCaptureOptions'),
          ),
        ).thenAnswer((_) async => null);
        when(() => participant.unpublishAllTracks()).thenAnswer((_) async {});
      });

      test('X13: a live microphone that stops on its own is lost', () async {
        await media.setMicrophoneEnabled(true);

        microphone.endCapture();
        await pumpEventQueue();

        check(
          lost.map((l) => (l.kind, l.wasOn)),
        ).deepEquals([(MediaKind.microphone, true)]);
        // Stopped and muted, so the controls show it off and turning it on
        // restarts capture.
        verify(() => microphonePublication.mute(stopOnMute: true)).called(1);
      });

      test('X13: a muted microphone that stops is lost, but was off', () async {
        await media.setMicrophoneEnabled(false);
        microphone
          ..isMuted = true
          ..endCapture();
        await pumpEventQueue();

        check(
          lost.map((l) => (l.kind, l.wasOn)),
        ).deepEquals([(MediaKind.microphone, false)]);
      });

      test('X13: a camera that stops while on is lost', () async {
        await media.setCameraEnabled(true);

        camera.endCapture();
        await pumpEventQueue();

        check(
          lost.map((l) => (l.kind, l.wasOn)),
        ).deepEquals([(MediaKind.camera, true)]);
      });

      test('turning the camera off is not a loss', () async {
        await media.setCameraEnabled(true);
        await media.setCameraEnabled(false);

        camera.endCapture();
        await pumpEventQueue();

        check(lost).isEmpty();
      });

      test('a camera that failed to turn on is not lost later', () async {
        await media.setMicrophoneEnabled(true);
        when(
          () => participant.setCameraEnabled(
            true,
            cameraCaptureOptions: any(named: 'cameraCaptureOptions'),
          ),
        ).thenThrow(Exception('NotAllowedError'));
        await check(media.setCameraEnabled(true)).throws<Exception>();

        camera.endCapture();
        await pumpEventQueue();

        check(lost).isEmpty();
      });

      test('a lost camera is reported once, even after LiveKit unpublished '
          'it', () async {
        await media.setCameraEnabled(true);
        // LiveKit's own end handler removes the publication first.
        when(
          () => participant.getTrackPublicationBySource(TrackSource.camera),
        ).thenReturn(null);
        camera.endCapture();
        await pumpEventQueue();

        final republished = _CaptureTrack(TrackSource.camera);
        final publication = _publicationOf(republished);
        when(
          () => participant.getTrackPublicationBySource(TrackSource.camera),
        ).thenReturn(publication);
        await media.setMicrophoneEnabled(true);
        republished.endCapture();
        await pumpEventQueue();

        check(lost.map((l) => l.kind)).deepEquals([MediaKind.camera]);
      });

      test(
        'X13: any media operation hooks the capture it leaves behind',
        () async {
          await media.setCameraEnabled(true);
          // A camera switch replaces the capture inside a media operation.
          camera.mediaStreamTrack = MockMediaStreamTrack();
          await media.setMicrophoneEnabled(true);

          camera.endCapture();
          await pumpEventQueue();

          check(lost.map((l) => l.kind)).deepEquals([MediaKind.camera]);
        },
      );

      test('release is not a loss', () async {
        await media.setMicrophoneEnabled(true);
        await media.release();

        microphone.endCapture();
        await pumpEventQueue();

        check(lost).isEmpty();
      });

      test("keeps LiveKit's own end handler", () async {
        var liveKitHandled = false;
        microphone.mediaStreamTrack.onEnded = () => liveKitHandled = true;
        await media.setMicrophoneEnabled(true);

        microphone.endCapture();
        await pumpEventQueue();

        check(liveKitHandled).isTrue();
        check(lost).length.equals(1);
      });

      test('X13: a capture restarted by unmuting is still watched', () async {
        microphone.isCapturing = false;
        when(() => microphone.restartTrack()).thenAnswer((_) async {
          microphone
            ..mediaStreamTrack = MockMediaStreamTrack()
            ..isCapturing = true;
        });

        await media.setMicrophoneEnabled(true);
        microphone.endCapture();
        await pumpEventQueue();

        check(lost).length.equals(1);
      });
    });
  });
}

MockLocalAudioTrackPublication _publicationOf(_CaptureTrack track) {
  final publication = MockLocalAudioTrackPublication();
  when(() => publication.track).thenReturn(track);
  when(
    () => publication.mute(stopOnMute: any(named: 'stopOnMute')),
  ).thenAnswer((_) async {});
  return publication;
}

/// A local track whose capture can end, like the SDK reports when a
/// permission is revoked or a device is unplugged.
class _CaptureTrack extends MockLocalAudioTrack {
  _CaptureTrack(this._source) {
    when(() => muted).thenAnswer((_) => isMuted);
    when(() => isActive).thenAnswer((_) => isCapturing);
  }

  final TrackSource _source;
  bool isMuted = false;
  bool isCapturing = true;

  @override
  TrackSource get source => _source;

  @override
  webrtc.MediaStreamTrack mediaStreamTrack = MockMediaStreamTrack();

  void endCapture() => mediaStreamTrack.onEnded?.call();
}

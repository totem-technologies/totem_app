// ignore_for_file: invalid_use_of_internal_member

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/media/livekit_local_media.dart';

import '../livekit_mocks.dart';

class _MockRoom extends Mock implements Room {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AudioCaptureOptions());
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
  });
}

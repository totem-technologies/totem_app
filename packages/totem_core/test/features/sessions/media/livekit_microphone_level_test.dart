import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, logger;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/media/livekit_audio_visualizer.dart';
import 'package:totem_core/features/sessions/media/livekit_microphone_level.dart';
import 'package:totem_core/shared/totem_icons.dart';

import '../livekit_mocks.dart';

void main() {
  late MockRemoteParticipant remoteParticipant;

  setUp(() {
    remoteParticipant = MockRemoteParticipant('user-1', 'User 1');
    when(
      () =>
          remoteParticipant.getTrackPublicationBySource(TrackSource.microphone),
    ).thenReturn(null);
  });

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('livekit_client'), (
          call,
        ) async {
          switch (call.method) {
            case 'startVisualizer':
              return true;
            case 'stopVisualizer':
            case 'broadcastRequestActivation':
            case 'broadcastRequestStop':
              return null;
            default:
              return null;
          }
        });
  });

  Future<void> pumpWidget(WidgetTester tester, {required Widget child}) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  group('with a standalone audio track', () {
    testWidgets('shows the muted icon when the audio track is muted', (
      tester,
    ) async {
      final audioTrack = MockLocalAudioTrack(muted: true);
      final mediaStreamTrack = MockMediaStreamTrack();
      when(() => audioTrack.mediaStreamTrack).thenReturn(mediaStreamTrack);
      when(() => mediaStreamTrack.id).thenReturn('local-track-1');
      when(audioTrack.createListener).thenReturn(MockTrackEventsListener());

      await pumpWidget(
        tester,
        child: LiveKitMicrophoneLevel(
          audioTrack: audioTrack,
          foregroundColor: Colors.white,
          barCount: 3,
        ),
      );

      check(tester.widgetList(find.byType(TotemIcon))).length.equals(1);
    });

    testWidgets('shows the muted state when no audio track is provided', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        child: const LiveKitMicrophoneLevel(
          foregroundColor: Colors.white,
          barCount: 3,
        ),
      );

      check(tester.widgetList(find.byType(TotemIcon))).length.equals(1);
    });

    testWidgets(
      'switches between waveform and icon on mute and unmute events',
      (tester) async {
        final audioTrack = MockLocalAudioTrack(muted: false);
        final mediaStreamTrack = MockMediaStreamTrack();
        when(() => audioTrack.mediaStreamTrack).thenReturn(mediaStreamTrack);
        when(() => mediaStreamTrack.id).thenReturn('local-track-2');
        final trackListener = CapturingTrackEventsListener();
        when(audioTrack.createListener).thenReturn(trackListener);

        await pumpWidget(
          tester,
          child: LiveKitMicrophoneLevel(
            audioTrack: audioTrack,
            foregroundColor: Colors.white,
            barCount: 3,
          ),
        );

        check(
          tester.widgetList(find.byType(SoundWaveformWidget)),
        ).length.equals(1);
        check(tester.widgetList(find.byType(TotemIcon))).length.equals(0);

        await audioTrack.mute(stopOnMute: false);
        trackListener.emit(MockTrackEvent());
        await tester.pump();

        check(tester.widgetList(find.byType(TotemIcon))).length.equals(1);
        check(
          tester.widgetList(find.byType(SoundWaveformWidget)),
        ).length.equals(0);

        await audioTrack.unmute(stopOnMute: false);
        trackListener.emit(MockTrackEvent());
        await tester.pump();

        check(
          tester.widgetList(find.byType(SoundWaveformWidget)),
        ).length.equals(1);
        check(tester.widgetList(find.byType(TotemIcon))).length.equals(0);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });

  group('with a participant', () {
    testWidgets('shows the muted icon when no microphone track exists', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        child: LiveKitMicrophoneLevel(
          participant: remoteParticipant,
          foregroundColor: Colors.white,
          barCount: 3,
        ),
      );

      check(tester.widgetList(find.byType(TotemIcon))).length.equals(1);
    });

    testWidgets(
      'switches between waveform and icon on participant mute and unmute events',
      (tester) async {
        final participant = MockRemoteParticipant('user-2', 'User 2');
        final publication = MockRemoteTrackPublication<RemoteAudioTrack>();
        final audioTrack = MockRemoteAudioTrack(muted: false);
        final mediaStreamTrack = MockMediaStreamTrack();

        when(() => participant.kind).thenReturn(ParticipantKind.STANDARD);
        when(
          () => participant.getTrackPublicationBySource(TrackSource.microphone),
        ).thenReturn(publication);
        when(() => publication.track).thenReturn(audioTrack);
        when(() => publication.source).thenReturn(TrackSource.microphone);
        when(() => audioTrack.mediaStreamTrack).thenReturn(mediaStreamTrack);
        when(() => mediaStreamTrack.id).thenReturn('remote-track-1');

        final mutedEvent = MockTrackMutedEvent();
        final unmutedEvent = MockTrackUnmutedEvent();
        when(() => mutedEvent.publication).thenReturn(publication);
        when(() => unmutedEvent.publication).thenReturn(publication);

        await pumpWidget(
          tester,
          child: LiveKitMicrophoneLevel(
            participant: participant,
            foregroundColor: Colors.white,
            barCount: 3,
          ),
        );

        check(
          tester.widgetList(find.byType(SoundWaveformWidget)),
        ).length.equals(1);
        check(tester.widgetList(find.byType(TotemIcon))).length.equals(0);

        audioTrack.setMuted(true);
        participant.listener.emitMuted(mutedEvent);
        audioTrack.trackListener.emit(MockTrackEvent());
        await tester.pump();

        check(tester.widgetList(find.byType(TotemIcon))).length.equals(1);
        check(
          tester.widgetList(find.byType(SoundWaveformWidget)),
        ).length.equals(0);

        audioTrack.setMuted(false);
        participant.listener.emitUnmuted(unmutedEvent);
        audioTrack.trackListener.emit(MockTrackEvent());
        await tester.pump();

        check(
          tester.widgetList(find.byType(SoundWaveformWidget)),
        ).length.equals(1);
        check(tester.widgetList(find.byType(TotemIcon))).length.equals(0);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}

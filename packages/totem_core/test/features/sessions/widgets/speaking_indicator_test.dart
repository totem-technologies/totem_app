import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, logger;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/widgets/audio_visualizer.dart';
import 'package:totem_core/features/sessions/widgets/speaking_indicator.dart';
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
        .setMockMethodCallHandler(
          const MethodChannel('livekit_client'),
          (call) async {
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
          },
        );
  });

  Future<void> pumpWidget(
    WidgetTester tester, {
    required Widget child,
    List<Object?> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          home: Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }

  group('SpeakingIndicatorAudioTrack', () {
    testWidgets('shows the muted icon when the audio track is muted', (
      tester,
    ) async {
      final audioTrack = MockLocalAudioTrack(muted: true);
      final mediaStreamTrack = MockMediaStreamTrack();
      when(() => audioTrack.mediaStreamTrack).thenReturn(mediaStreamTrack);
      when(() => mediaStreamTrack.id).thenReturn('local-track-1');
      when(audioTrack.createListener).thenReturn(
        MockTrackEventsListener(),
      );

      await pumpWidget(
        tester,
        child: SpeakingIndicatorAudioTrack(
          audioTrack: audioTrack,
        ),
      );

      expect(find.byType(TotemIcon), findsOneWidget);
    });

    testWidgets('shows the muted icon when no audio track is provided', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        child: const SpeakingIndicatorAudioTrack(audioTrack: null),
      );

      expect(find.byType(TotemIcon), findsOneWidget);
    });

    testWidgets(
      'switches between waveform and icon on mute and unmute events',
      (
        tester,
      ) async {
        final audioTrack = MockLocalAudioTrack(muted: false);
        final mediaStreamTrack = MockMediaStreamTrack();
        when(() => audioTrack.mediaStreamTrack).thenReturn(mediaStreamTrack);
        when(() => mediaStreamTrack.id).thenReturn('local-track-2');
        final trackListener = CapturingTrackEventsListener();
        when(audioTrack.createListener).thenReturn(trackListener);

        await pumpWidget(
          tester,
          child: SpeakingIndicatorAudioTrack(audioTrack: audioTrack),
        );

        expect(find.byType(SoundWaveformWidget), findsOneWidget);
        expect(find.byType(TotemIcon), findsNothing);

        await audioTrack.mute(stopOnMute: false);
        trackListener.emit(MockTrackEvent());
        await tester.pump();

        expect(find.byType(TotemIcon), findsOneWidget);
        expect(find.byType(SoundWaveformWidget), findsNothing);

        await audioTrack.unmute(stopOnMute: false);
        trackListener.emit(MockTrackEvent());
        await tester.pump();

        expect(find.byType(SoundWaveformWidget), findsOneWidget);
        expect(find.byType(TotemIcon), findsNothing);
      },
    );
  });

  group('SpeakingIndicator', () {
    testWidgets('shows the muted icon when no microphone track exists', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        child: SpeakingIndicator(participant: remoteParticipant),
      );

      expect(find.byType(TotemIcon), findsOneWidget);
    });

    testWidgets(
      'switches between waveform and icon on participant mute and unmute events',
      (
        tester,
      ) async {
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
          child: SpeakingIndicator(participant: participant),
        );

        expect(find.byType(SoundWaveformWidget), findsOneWidget);
        expect(find.byType(TotemIcon), findsNothing);

        audioTrack.setMuted(true);
        participant.listener.emitMuted(mutedEvent);
        audioTrack.trackListener.emit(MockTrackEvent());
        await tester.pump();

        expect(find.byType(TotemIcon), findsOneWidget);
        expect(find.byType(SoundWaveformWidget), findsNothing);

        audioTrack.setMuted(false);
        participant.listener.emitUnmuted(unmutedEvent);
        audioTrack.trackListener.emit(MockTrackEvent());
        await tester.pump();

        expect(find.byType(SoundWaveformWidget), findsOneWidget);
        expect(find.byType(TotemIcon), findsNothing);
      },
    );
  });

  group('SpeakingIndicatorOrEmoji', () {
    testWidgets('renders the participant emoji instead of the indicator', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        overrides: [
          participantEmojisProvider(
            remoteParticipant.identity,
          ).overrideWith((ref) => ['🔥']),
        ],
        child: SpeakingIndicatorOrEmoji(participant: remoteParticipant),
      );

      await tester.pumpAndSettle();

      expect(find.text('🔥'), findsOneWidget);
      expect(find.byType(TotemIcon), findsNothing);
    });

    testWidgets('updates when the emoji provider changes', (tester) async {
      await pumpWidget(
        tester,
        child: SpeakingIndicatorOrEmoji(participant: remoteParticipant),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      final notifier = container.read(emojiReactionsProvider.notifier);

      expect(find.byType(TotemIcon), findsOneWidget);
      expect(find.text('🔥'), findsNothing);

      await notifier.emitIncomingReaction(remoteParticipant.identity, '🔥');
      await tester.pump();

      expect(find.text('🔥'), findsOneWidget);
      expect(find.byType(TotemIcon), findsNothing);

      notifier.clear();
      await tester.pumpAndSettle();

      expect(find.text('🔥'), findsNothing);
      expect(find.byType(TotemIcon), findsOneWidget);
    });
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, logger;
import 'package:material_ui/material_ui.dart';
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

  Future<void> pumpWidget(
    WidgetTester tester, {
    required Widget child,
    List<Object?> overrides = const [],
    Size? viewSize,
  }) async {
    if (viewSize != null) {
      tester.view.physicalSize = viewSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }

  TotemIcon overlayMuteIcon(WidgetTester tester) {
    return tester.widget<TotemIcon>(
      find.descendant(
        of: find.byType(SpeakingIndicatorOrEmoji),
        matching: find.byType(TotemIcon),
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
      when(audioTrack.createListener).thenReturn(MockTrackEventsListener());

      await pumpWidget(
        tester,
        child: SpeakingIndicatorAudioTrack(audioTrack: audioTrack),
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
      expect(tester.widget<TotemIcon>(find.byType(TotemIcon)).size, 20);
    });

    testWidgets(
      'keeps a 20dp muted icon on phone-sized windows without an explicit size',
      (tester) async {
        await pumpWidget(
          tester,
          viewSize: const Size(400, 800),
          child: const SpeakingIndicatorAudioTrack(audioTrack: null),
        );

        expect(tester.widget<TotemIcon>(find.byType(TotemIcon)).size, 20);
      },
    );

    testWidgets(
      'keeps a 20dp muted icon on desktop-class windows without an explicit size',
      (tester) async {
        await pumpWidget(
          tester,
          viewSize: const Size(1200, 900),
          child: const SpeakingIndicatorAudioTrack(audioTrack: null),
        );

        expect(tester.widget<TotemIcon>(find.byType(TotemIcon)).size, 20);
      },
    );

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

    testWidgets('uses compact overlay sizes on phone-sized windows', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        viewSize: const Size(400, 800),
        child: SpeakingIndicatorOrEmoji(participant: remoteParticipant),
      );

      expect(
        tester.getSize(find.byType(SpeakingIndicatorOrEmoji)),
        const Size(20, 20),
      );
      expect(overlayMuteIcon(tester).size, 16);
    });

    testWidgets('uses compact overlay sizes in phone landscape', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        viewSize: const Size(800, 400),
        child: SpeakingIndicatorOrEmoji(participant: remoteParticipant),
      );

      expect(
        tester.getSize(find.byType(SpeakingIndicatorOrEmoji)),
        const Size(20, 20),
      );
      expect(overlayMuteIcon(tester).size, 16);
    });

    testWidgets('uses comfortable overlay sizes on desktop-class windows', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        viewSize: const Size(1200, 900),
        child: SpeakingIndicatorOrEmoji(participant: remoteParticipant),
      );

      expect(
        tester.getSize(find.byType(SpeakingIndicatorOrEmoji)),
        const Size(40, 40),
      );
      expect(overlayMuteIcon(tester).size, 22);
    });

    testWidgets('renders a larger emoji glyph on desktop-class windows', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        viewSize: const Size(1200, 900),
        overrides: [
          participantEmojisProvider(
            remoteParticipant.identity,
          ).overrideWith((ref) => ['🔥']),
        ],
        child: SpeakingIndicatorOrEmoji(participant: remoteParticipant),
      );

      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(SpeakingIndicatorOrEmoji)),
        const Size(40, 40),
      );
      expect(tester.widget<Text>(find.text('🔥')).style?.fontSize, 20);
    });

    testWidgets('keeps the compact emoji glyph on phone-sized windows', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        viewSize: const Size(400, 800),
        overrides: [
          participantEmojisProvider(
            remoteParticipant.identity,
          ).overrideWith((ref) => ['🔥']),
        ],
        child: SpeakingIndicatorOrEmoji(participant: remoteParticipant),
      );

      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(SpeakingIndicatorOrEmoji)),
        const Size(20, 20),
      );
      expect(tester.widget<Text>(find.text('🔥')).style?.fontSize, 10);
    });
  });
}

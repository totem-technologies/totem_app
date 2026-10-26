import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, logger;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/media/livekit_audio_visualizer.dart';
import 'package:totem_core/features/sessions/media/livekit_microphone_level.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';
import 'package:totem_core/shared/totem_icons.dart';

import '../livekit_mocks.dart';

MockLocalAudioTrack _audioTrack({
  bool muted = false,
  EventsListener<TrackEvent>? listener,
}) {
  final track = MockLocalAudioTrack(muted: muted);
  final mediaStreamTrack = MockMediaStreamTrack();
  when(() => track.mediaStreamTrack).thenReturn(mediaStreamTrack);
  when(() => mediaStreamTrack.id).thenReturn('local-track');
  when(track.createListener).thenReturn(listener ?? MockTrackEventsListener());
  return track;
}

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('livekit_client'), (
          call,
        ) async {
          return call.method == 'startVisualizer' ? true : null;
        });
  });

  Future<void> pumpLevel(WidgetTester tester, LiveKitMicrophoneLevel level) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(height: 20, child: level)),
      ),
    );
  }

  bool showsBars() => find.byType(LevelBars).evaluate().isNotEmpty;
  TotemIcon microphoneIcon(WidgetTester tester) =>
      tester.widget<TotemIcon>(find.byType(TotemIcon));

  Future<void> unmount(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  group('a preview track', () {
    testWidgets('shows the muted icon while the track is muted', (
      tester,
    ) async {
      await pumpLevel(
        tester,
        LiveKitMicrophoneLevel.preview(
          _audioTrack(muted: true),
          color: Colors.white,
          barCount: 5,
        ),
      );

      check(microphoneIcon(tester).icon).equals(TotemIcons.microphoneOff);
      check(showsBars()).isFalse();
    });

    testWidgets('switches between microphone states on mute and unmute', (
      tester,
    ) async {
      final listener = CapturingTrackEventsListener();
      final track = _audioTrack(listener: listener);

      await pumpLevel(
        tester,
        LiveKitMicrophoneLevel.preview(track, color: Colors.white, barCount: 5),
      );
      check(showsBars()).isTrue();
      check(find.byType(TotemIcon).evaluate()).isEmpty();

      await track.mute(stopOnMute: false);
      listener.emit(MockTrackEvent());
      await tester.pump();
      check(microphoneIcon(tester).icon).equals(TotemIcons.microphoneOff);
      check(showsBars()).isFalse();

      await track.unmute(stopOnMute: false);
      listener.emit(MockTrackEvent());
      await tester.pump();
      check(showsBars()).isTrue();
      check(find.byType(TotemIcon).evaluate()).isEmpty();

      await unmount(tester);
    });
  });

  group('a room microphone', () {
    late StreamController<void> changes;

    setUp(() => changes = StreamController<void>.broadcast(sync: true));
    tearDown(() => changes.close());

    testWidgets('shows the level once the microphone is published', (
      tester,
    ) async {
      AudioTrack? published;

      await pumpLevel(
        tester,
        LiveKitMicrophoneLevel(
          track: () => published,
          changes: changes.stream,
          color: Colors.white,
          barCount: 5,
        ),
      );
      check(microphoneIcon(tester).icon).equals(TotemIcons.microphoneOff);

      published = _audioTrack();
      changes.add(null);
      await tester.pump();

      check(showsBars()).isTrue();
      check(find.byType(TotemIcon).evaluate()).isEmpty();
      await unmount(tester);
    });

    testWidgets('schedules no frame when its waveform is unchanged', (
      tester,
    ) async {
      final track = _audioTrack();

      await pumpLevel(
        tester,
        LiveKitMicrophoneLevel(
          track: () => track,
          changes: changes.stream,
          color: Colors.white,
          barCount: 5,
        ),
      );
      await tester.pump();
      check(tester.binding.hasScheduledFrame).isFalse();

      changes.add(null);

      check(tester.binding.hasScheduledFrame).isFalse();
      await unmount(tester);
    });

    testWidgets('replaces the waveform track without retaining the old one', (
      tester,
    ) async {
      final first = _audioTrack();
      final replacement = _audioTrack();
      AudioTrack? published = first;

      await pumpLevel(
        tester,
        LiveKitMicrophoneLevel(
          track: () => published,
          changes: changes.stream,
          color: Colors.white,
          barCount: 5,
        ),
      );

      published = replacement;
      changes.add(null);
      await tester.pump();

      final waveform = tester.widget<SoundWaveformWidget>(
        find.byType(SoundWaveformWidget),
      );
      check(waveform.audioTrack).equals(replacement);
      check(find.byType(SoundWaveformWidget).evaluate()).length.equals(1);
      await unmount(tester);
    });
  });
}

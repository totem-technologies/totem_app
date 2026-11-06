import 'dart:async';

import 'package:checks/checks.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, logger;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/media/livekit_audio_visualizer.dart';
import 'package:totem_core/features/sessions/media/livekit_speaker_level.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';
import 'package:totem_core/shared/totem_icons.dart';

import '../livekit_mocks.dart';

class _MockParticipant extends Mock implements RemoteParticipant {}

class _MockRemoteAudioTrack extends Mock implements RemoteAudioTrack {}

void main() {
  late _MockParticipant participant;
  late StreamController<void> changes;
  late double level;

  setUp(() {
    level = 0;
    participant = _MockParticipant();
    changes = StreamController<void>.broadcast(sync: true);
    when(() => participant.hasAudio).thenReturn(true);
    when(() => participant.isMuted).thenReturn(false);
  });

  tearDown(() => changes.close());

  Future<void> pump(
    WidgetTester tester, {
    Participant? Function()? lookup,
    String identity = 'alice',
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 20,
          child: LiveKitSpeakerLevel(
            identity: identity,
            participant: lookup ?? () => participant,
            changes: changes.stream,
            audioLevel: () => level,
            audioLevelChanges: changes.stream,
            color: Colors.white,
            iconSize: 20,
          ),
        ),
      ),
    );
  }

  TotemIcon icon(WidgetTester tester) =>
      tester.widget<TotemIcon>(find.byType(TotemIcon));

  testWidgets('shows the microphone-off icon without a participant', (
    tester,
  ) async {
    await pump(tester, lookup: () => null);

    check(icon(tester).icon).equals(TotemIcons.microphoneOff);
  });

  testWidgets('shows five idle dots for an unmuted silent participant', (
    tester,
  ) async {
    await pump(tester);

    final bars = tester.widget<LevelBars>(find.byType(LevelBars));
    check(bars.levels.value).deepEquals(const [0, 0, 0, 0, 0]);
    check(find.byType(TotemIcon).evaluate()).isEmpty();
    check(find.byType(SoundWaveformWidget).evaluate()).isEmpty();
  });

  testWidgets('uses the server level instead of a remote track visualizer', (
    tester,
  ) async {
    final publication = MockRemoteTrackPublication<RemoteTrack>();
    final track = _MockRemoteAudioTrack();
    when(() => publication.muted).thenReturn(false);
    when(() => track.muted).thenReturn(false);
    when(() => publication.track).thenReturn(track);
    when(
      () => participant.getTrackPublicationBySource(TrackSource.microphone),
    ).thenReturn(publication);

    await pump(tester);

    level = 0.6;
    changes.add(null);
    await tester.pump();

    final levels = tester
        .widget<LevelBars>(find.byType(LevelBars))
        .levels
        .value;
    check(levels.length).equals(5);
    check(levels.every((value) => value > 0 && value <= 1)).isTrue();
    check(levels.toSet().length > 1).isTrue();
    check(find.byType(SoundWaveformWidget).evaluate()).isEmpty();
    check(find.byType(TotemIcon).evaluate()).isEmpty();
  });

  testWidgets('waveform follows events, silence, and participant identity', (
    tester,
  ) async {
    level = 0.8;
    await pump(tester);
    final notifier = tester.widget<LevelBars>(find.byType(LevelBars)).levels;
    final first = List<double>.of(notifier.value);
    changes.add(null);
    await tester.pump();
    final second = List<double>.of(notifier.value);
    check(second).deepEquals(first);
    level = 0.799;
    changes.add(null);
    await tester.pump();
    check(notifier.value).deepEquals(first);
    level = 0.1;
    changes.add(null);
    await tester.pump();
    check(notifier.value[2] < first[2]).isTrue();
    check(
      identical(
        notifier,
        tester.widget<LevelBars>(find.byType(LevelBars)).levels,
      ),
    ).isTrue();

    level = 0;
    changes.add(null);
    await tester.pump();
    check(notifier.value).deepEquals(const [0, 0, 0, 0, 0]);
    await tester.pumpWidget(const SizedBox.shrink());
    level = 0.8;
    await pump(tester);
    check(
      tester.widget<LevelBars>(find.byType(LevelBars)).levels.value,
    ).deepEquals(first);
    await tester.pumpWidget(const SizedBox.shrink());
    await pump(tester, identity: 'bob');
    final other = tester.widget<LevelBars>(find.byType(LevelBars)).levels.value;
    check(other.toString() == first.toString()).isFalse();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('noise and repeated silence leave the waveform idle', (
    tester,
  ) async {
    await pump(tester);
    final notifier = tester.widget<LevelBars>(find.byType(LevelBars)).levels;
    var notifications = 0;
    void listener() => notifications++;
    notifier.addListener(listener);
    for (final sample in [0.001, 0.002, 0.0, 0.0]) {
      level = sample;
      changes.add(null);
      await tester.pump();
    }
    check(notifier.value).deepEquals(const [0, 0, 0, 0, 0]);
    check(notifications).equals(0);
    check(tester.binding.hasScheduledFrame).isFalse();
    notifier.removeListener(listener);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unchanged levels and silence stop scheduling frames', (
    tester,
  ) async {
    await pump(tester);
    final notifier = tester.widget<LevelBars>(find.byType(LevelBars)).levels;
    var notifications = 0;
    void listener() => notifications++;
    notifier.addListener(listener);

    level = 0.6;
    changes.add(null);
    check(notifications).equals(1);
    check(notifier.value.any((value) => value > 0)).isTrue();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    check(tester.binding.hasScheduledFrame).isFalse();

    for (var i = 0; i < 20; i++) {
      changes.add(null);
      check(notifications).equals(1);
      check(tester.binding.hasScheduledFrame).isFalse();
      await tester.pump(const Duration(milliseconds: 200));
      check(tester.binding.hasScheduledFrame).isFalse();
    }

    level = 0;
    changes.add(null);
    check(notifications).equals(2);
    check(notifier.value).deepEquals(const [0, 0, 0, 0, 0]);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    check(tester.binding.hasScheduledFrame).isFalse();
    for (var i = 0; i < 10; i++) {
      changes.add(null);
      check(notifications).equals(2);
      await tester.pump(const Duration(milliseconds: 200));
      check(tester.binding.hasScheduledFrame).isFalse();
    }
    notifier.removeListener(listener);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switches to the microphone-off icon when muted', (tester) async {
    await pump(tester);

    when(() => participant.isMuted).thenReturn(true);
    changes.add(null);
    await tester.pump();

    check(icon(tester).icon).equals(TotemIcons.microphoneOff);
  });
}

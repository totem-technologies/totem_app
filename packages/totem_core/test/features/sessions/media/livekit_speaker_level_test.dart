import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
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

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('livekit_client'), (
          call,
        ) async {
          return call.method == 'startVisualizer' ? true : null;
        });
  });

  setUp(() {
    participant = _MockParticipant();
    changes = StreamController<void>.broadcast(sync: true);
    when(() => participant.hasAudio).thenReturn(true);
    when(() => participant.isMuted).thenReturn(false);
  });

  tearDown(() => changes.close());

  Future<void> pump(WidgetTester tester, {Participant? Function()? lookup}) {
    return tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 20,
          child: LiveKitSpeakerLevel(
            participant: lookup ?? () => participant,
            changes: changes.stream,
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
    check(bars.levels).deepEquals(const [0, 0, 0, 0, 0]);
    check(find.byType(TotemIcon).evaluate()).isEmpty();
    check(find.byType(SoundWaveformWidget).evaluate()).isEmpty();
  });

  testWidgets('uses the microphone track rather than server speaking state', (
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

    final waveform = tester.widget<SoundWaveformWidget>(
      find.byType(SoundWaveformWidget),
    );
    check(waveform.barCount).equals(5);
    check(find.byType(LevelBars).evaluate()).length.equals(1);
    check(find.byType(TotemIcon).evaluate()).isEmpty();
  });

  testWidgets('switches to the microphone-off icon when muted', (tester) async {
    await pump(tester);

    when(() => participant.isMuted).thenReturn(true);
    changes.add(null);
    await tester.pump();

    check(icon(tester).icon).equals(TotemIcons.microphoneOff);
  });
}

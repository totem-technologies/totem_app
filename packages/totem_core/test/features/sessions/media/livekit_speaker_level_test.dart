import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/features/sessions/media/livekit_speaker_level.dart';
import 'package:totem_core/features/sessions/media/speech_level.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';
import 'package:totem_core/shared/totem_icons.dart';

class _MockParticipant extends Mock implements RemoteParticipant;

void main() {
  late _MockParticipant participant;
  late StreamController<void> changes;

  setUp(() {
    participant = _MockParticipant();
    changes = StreamController<void>.broadcast(sync: true);
    when(() => participant.hasAudio).thenReturn(true);
    when(() => participant.isMuted).thenReturn(false);
    when(() => participant.isSpeaking).thenReturn(false);
    when(() => participant.audioLevel).thenReturn(0);
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
            meter: SpeechLevelMeter(),
            color: Colors.white,
            iconSize: 20,
          ),
        ),
      ),
    );
  }

  List<double> levels(WidgetTester tester) =>
      tester.widget<LevelBars>(find.byType(LevelBars)).levels;

  testWidgets('shows the microphone-off icon without a participant', (
    tester,
  ) async {
    await pump(tester, lookup: () => null);

    check(find.byType(TotemIcon).evaluate()).length.equals(1);
  });

  testWidgets('bars follow the reported level while speaking', (tester) async {
    await pump(tester);
    check(levels(tester)).every((it) => it.equals(0));

    when(() => participant.isSpeaking).thenReturn(true);
    when(() => participant.audioLevel).thenReturn(0.5);
    changes.add(null);
    await tester.pump();

    check(levels(tester)).every((it) => it.isGreaterThan(0));
  });

  testWidgets('shows a quiet speaker LiveKit counts as active', (tester) async {
    // About -34 dB, just above LiveKit's -35 dB speaking threshold.
    when(() => participant.isSpeaking).thenReturn(true);
    when(() => participant.audioLevel).thenReturn(0.02);

    await pump(tester);

    check(levels(tester)).every((it) => it.isGreaterThan(0));
  });

  testWidgets('ignores levels while not speaking', (tester) async {
    when(() => participant.audioLevel).thenReturn(0.5);

    await pump(tester);

    check(levels(tester)).every((it) => it.equals(0));
  });

  testWidgets('switches between bars and icon as the microphone mutes', (
    tester,
  ) async {
    await pump(tester);
    check(find.byType(LevelBars).evaluate()).length.equals(1);

    when(() => participant.isMuted).thenReturn(true);
    changes.add(null);
    await tester.pump();

    check(find.byType(TotemIcon).evaluate()).length.equals(1);
    check(find.byType(LevelBars).evaluate()).isEmpty();
  });

  testWidgets('schedules no frame when nothing changed', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    check(tester.binding.hasScheduledFrame).isFalse();

    changes.add(null);

    check(tester.binding.hasScheduledFrame).isFalse();
  });
}

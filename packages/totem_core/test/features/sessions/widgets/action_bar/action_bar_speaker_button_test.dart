import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_speaker_button.dart';

void main() {
  testWidgets('ActionBarSpeakerButton toggles speaker state on tap', (
    tester,
  ) async {
    bool? requested;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionBarSpeakerButton(
            isSpeakerOn: true,
            onSpeakerToggled: (enabled) {
              requested = enabled;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionBarButton));
    await tester.pump();

    expect(requested, isFalse);
  });

  testWidgets('ActionBarSpeakerButton is disabled when callback is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActionBarSpeakerButton(
            isSpeakerOn: true,
            onSpeakerToggled: null,
          ),
        ),
      ),
    );

    final gesture = tester.widget<GestureDetector>(
      find.descendant(
        of: find.byType(ActionBarButton),
        matching: find.byType(GestureDetector),
      ),
    );

    expect(gesture.onTap, isNull);
  });
}

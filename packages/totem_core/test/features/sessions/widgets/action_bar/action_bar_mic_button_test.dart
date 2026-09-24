import 'dart:async';

import 'package:checks/checks.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_mic_button.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';

void main() {
  testWidgets('ActionBarMicButton calls onToggle with enabled=true when off', (
    tester,
  ) async {
    bool? requested;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionBarMicButton(
            participant: null,
            onToggle: (shouldEnable) async {
              requested = shouldEnable;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionBarButton));
    await tester.pump();

    check(requested).equals(true);
  });

  testWidgets('asks before unmuting when another participant has the Totem', (
    tester,
  ) async {
    var callCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionBarMicButton(
            participant: null,
            requiresUnmuteConfirmation: true,
            onToggle: (_) async {
              callCount++;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionBarButton));
    await tester.pumpAndSettle();

    check(tester.widgetList(find.byType(ConfirmationDialog))).length.equals(1);
    check(callCount).equals(0);

    // stay muted
    await tester.tap(find.byType(ConfirmationDialogButton).last);
    await tester.pumpAndSettle();
    check(callCount).equals(0);

    await tester.tap(find.byType(ActionBarButton));
    await tester.pumpAndSettle();
    // unmute anyway
    await tester.tap(find.byType(ConfirmationDialogButton).first);
    await tester.pumpAndSettle();

    check(callCount).equals(1);
    check(
      tester.widgetList(find.bySemanticsLabel('Microphone on')),
    ).length.equals(1);
  });

  testWidgets('shows the initial session microphone state before publication', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionBarMicButton(
            participant: null,
            initiallyEnabled: true,
            onToggle: (_) async {},
          ),
        ),
      ),
    );

    check(
      tester.widgetList(find.bySemanticsLabel('Microphone on')),
    ).length.equals(1);
  });

  testWidgets('controlled isMicOn drives the displayed microphone state', (
    tester,
  ) async {
    Future<void> pumpMic(bool isMicOn) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionBarMicButton(
            participant: null,
            isMicOn: isMicOn,
            onToggle: (_) async {},
          ),
        ),
      ),
    );

    await pumpMic(true);
    check(
      tester.widgetList(find.bySemanticsLabel('Microphone on')),
    ).length.equals(1);

    await pumpMic(false);
    check(
      tester.widgetList(find.bySemanticsLabel('Microphone off')),
    ).length.equals(1);
  });

  testWidgets('ActionBarMicButton ignores re-entry while busy', (tester) async {
    var callCount = 0;
    final completer = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionBarMicButton(
            participant: null,
            onToggle: (_) {
              callCount++;
              return completer.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionBarButton));
    await tester.pump();
    await tester.tap(find.byType(ActionBarButton));
    await tester.pump();

    check(callCount).equals(1);

    completer.complete();
    await tester.pumpAndSettle();
  });
}

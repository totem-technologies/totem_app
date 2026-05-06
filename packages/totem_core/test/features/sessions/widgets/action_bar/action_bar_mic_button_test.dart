import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_app/features/sessions/widgets/action_bar/action_bar_mic_button.dart';

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

    expect(requested, isTrue);
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

    expect(callCount, 1);

    completer.complete();
    await tester.pumpAndSettle();
  });
}

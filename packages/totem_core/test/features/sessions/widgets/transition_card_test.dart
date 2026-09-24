import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';

void main() {
  void autoSizeTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(
      description,
      body,
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );
  }

  group('Transition Cards', () {
    Widget buildTestWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );
    }

    autoSizeTest('actionable transition cards forward completion', (
      tester,
    ) async {
      final cards = <Widget Function(AsyncValueGetter<bool>)>[
        (onActionPressed) =>
            JoinTransitionCard(onActionPressed: onActionPressed),
        (onActionPressed) => PassTransitionCard(
          onActionPressed: onActionPressed,
          actionText: 'Pass',
        ),
        (onActionPressed) =>
            ReceiveTransitionCard(onActionPressed: onActionPressed),
        (onActionPressed) =>
            StartTransitionCard(onActionPressed: onActionPressed),
      ];

      for (final buildCard in cards) {
        var actionTriggered = false;
        await tester.pumpWidget(
          buildTestWidget(
            buildCard(() async {
              actionTriggered = true;
              return true;
            }),
          ),
        );

        check(
          tester.widgetList(find.byType(ActionSliderButton)),
        ).length.equals(1);
        await tester
            .widget<ActionSliderButton>(find.byType(ActionSliderButton))
            .onActionCompleted();
        check(actionTriggered).isTrue();
      }
    });

    autoSizeTest('WaitingReceiveTransitionCard renders without action button', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(const WaitingReceiveTransitionCard()),
      );

      check(
        tester.widgetList(find.byType(ActionSliderButton)),
      ).length.equals(0);
      check(
        tester.widgetList(
          find.textContaining('Waiting for the receiver to accept'),
        ),
      ).length.equals(1);
    });

    autoSizeTest('PromptTransitionCard renders and triggers action', (
      tester,
    ) async {
      bool actionTriggered = false;
      String? message;

      await tester.pumpWidget(
        buildTestWidget(
          PromptTransitionCard(
            onActionPressed: (roundMessage) async {
              actionTriggered = true;
              message = roundMessage;
              return true;
            },
          ),
        ),
      );

      check(tester.widgetList(find.byType(TextField))).length.equals(1);
      check(
        tester.widgetList(find.byType(ActionSliderButton)),
      ).length.equals(1);

      await tester.enterText(find.byType(TextField), 'Test prompt');

      // Trigger the action
      final button = tester.widget<ActionSliderButton>(
        find.byType(ActionSliderButton),
      );
      await button.onActionCompleted();

      check(actionTriggered).equals(true);
      check(message).equals('Test prompt');
    });
  });
}

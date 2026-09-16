import 'package:checks/checks.dart';
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

    autoSizeTest('JoinTransitionCard renders and triggers action', (
      tester,
    ) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        buildTestWidget(
          JoinTransitionCard(
            onActionPressed: () async {
              actionTriggered = true;
              return true;
            },
          ),
        ),
      );

      check(tester.widgetList(find.text('Welcome'))).length.equals(1);
      check(
        tester.widgetList(
          find.text(
            'Your session will start soon. Please check your audio and video before joining.',
          ),
        ),
      ).length.equals(1);
      check(
        tester.widgetList(find.byType(ActionSliderButton)),
      ).length.equals(1);

      // Trigger the action
      final button = tester.widget<ActionSliderButton>(
        find.byType(ActionSliderButton),
      );
      await button.onActionCompleted();

      check(actionTriggered).equals(true);
    });

    autoSizeTest('PassTransitionCard renders and triggers action', (
      tester,
    ) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        buildTestWidget(
          PassTransitionCard(
            onActionPressed: () async {
              actionTriggered = true;
              return true;
            },
            actionText: 'Pass',
          ),
        ),
      );

      check(
        tester.widgetList(find.byType(ActionSliderButton)),
      ).length.equals(1);

      // Trigger the action
      final button = tester.widget<ActionSliderButton>(
        find.byType(ActionSliderButton),
      );
      await button.onActionCompleted();

      check(actionTriggered).equals(true);
    });

    autoSizeTest('ReceiveTransitionCard renders and triggers action', (
      tester,
    ) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        buildTestWidget(
          ReceiveTransitionCard(
            onActionPressed: () async {
              actionTriggered = true;
              return true;
            },
          ),
        ),
      );

      check(
        tester.widgetList(find.byType(ActionSliderButton)),
      ).length.equals(1);

      // Trigger the action
      final button = tester.widget<ActionSliderButton>(
        find.byType(ActionSliderButton),
      );
      await button.onActionCompleted();

      check(actionTriggered).equals(true);
    });

    autoSizeTest('StartTransitionCard renders and triggers action', (
      tester,
    ) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        buildTestWidget(
          StartTransitionCard(
            onActionPressed: () async {
              actionTriggered = true;
              return true;
            },
          ),
        ),
      );

      check(
        tester.widgetList(find.byType(ActionSliderButton)),
      ).length.equals(1);

      // Trigger the action
      final button = tester.widget<ActionSliderButton>(
        find.byType(ActionSliderButton),
      );
      await button.onActionCompleted();

      check(actionTriggered).equals(true);
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

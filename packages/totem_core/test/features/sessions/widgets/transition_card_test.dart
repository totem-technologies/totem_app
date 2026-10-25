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
    AsyncValueSetter<WidgetTester> body, {
    TestVariant<Object?> variant = const DefaultTestVariant(),
  }) {
    testWidgets(
      description,
      body,
      variant: variant,
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

    group('with a keyboard on desktop', () {
      final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

      Future<void> pumpAtSize(
        WidgetTester tester,
        Size size,
        Widget child,
      ) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(buildTestWidget(child));
      }

      autoSizeTest(
        'large viewport keeps the space shortcut inside the receive control',
        (tester) async {
          var received = false;
          await pumpAtSize(
            tester,
            const Size(1280, 900),
            ReceiveTransitionCard(
              onActionPressed: () async {
                received = true;
                return true;
              },
            ),
          );

          check(
            find.bySemanticsLabel('press space bar to receive').evaluate(),
          ).isNotEmpty();
          check(find.text('press space bar to receive').evaluate()).isEmpty();

          await tester.tap(find.text('Receive'));
          await tester.pump();
          check(received).isTrue();
        },
        variant: desktop,
      );

      autoSizeTest(
        'small viewport keeps the space shortcut caption under the card',
        (tester) async {
          await pumpAtSize(
            tester,
            const Size(500, 800),
            ReceiveTransitionCard(onActionPressed: () async => true),
          );

          check(
            find.text('press space bar to receive').evaluate(),
          ).isNotEmpty();
        },
        variant: desktop,
      );
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
            onActionPressed:
                ({customPrompt, sessionPromptId, clearPrompt = false}) async {
                  actionTriggered = true;
                  message = customPrompt;
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

    autoSizeTest(
      'PromptTransitionCard passes unchanged text without replacing the prompt',
      (tester) async {
        String? capturedCustomPrompt;
        int? capturedSessionPromptId;

        await tester.pumpWidget(
          buildTestWidget(
            PromptTransitionCard(
              initialPrompt: 'Prepared prompt',
              initialSessionPromptId: 42,
              onActionPressed:
                  ({customPrompt, sessionPromptId, clearPrompt = false}) async {
                    capturedCustomPrompt = customPrompt;
                    capturedSessionPromptId = sessionPromptId;
                    return true;
                  },
            ),
          ),
        );

        final button = tester.widget<ActionSliderButton>(
          find.byType(ActionSliderButton),
        );
        await button.onActionCompleted();

        check(capturedCustomPrompt).isNull();
        check(capturedSessionPromptId).isNull();
      },
    );

    autoSizeTest('PromptTransitionCard explicitly clears a removed prompt', (
      tester,
    ) async {
      var clearRequested = false;
      await tester.pumpWidget(
        buildTestWidget(
          PromptTransitionCard(
            initialPrompt: 'Prepared prompt',
            onActionPressed:
                ({customPrompt, sessionPromptId, clearPrompt = false}) async {
                  clearRequested = clearPrompt;
                  return true;
                },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '');
      await tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .onActionCompleted();

      check(clearRequested).isTrue();
    });
  });
}

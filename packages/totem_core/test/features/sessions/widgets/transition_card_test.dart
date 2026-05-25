import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';

void main() {
  group('Transition Cards', () {
    Widget buildTestWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    testWidgets('JoinTransitionCard renders and triggers action', (
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

      expect(find.text('Welcome'), findsOneWidget);
      expect(
        find.text(
          'Your session will start soon. Please check your audio and video before joining.',
        ),
        findsOneWidget,
      );
      expect(find.byType(ActionSliderButton), findsOneWidget);

      // Trigger the action
      final button = tester.widget<ActionSliderButton>(
        find.byType(ActionSliderButton),
      );
      await button.onActionCompleted();

      expect(actionTriggered, isTrue);
    });

    testWidgets('PassTransitionCard renders and triggers action', (
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

      expect(find.byType(ActionSliderButton), findsOneWidget);

      // Trigger the action
      final button = tester.widget<ActionSliderButton>(
        find.byType(ActionSliderButton),
      );
      await button.onActionCompleted();

      expect(actionTriggered, isTrue);
    });

    testWidgets('ReceiveTransitionCard renders and triggers action', (
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

      expect(find.byType(ActionSliderButton), findsOneWidget);

      // Trigger the action
      final button = tester.widget<ActionSliderButton>(
        find.byType(ActionSliderButton),
      );
      await button.onActionCompleted();

      expect(actionTriggered, isTrue);
    });

    testWidgets('StartTransitionCard renders and triggers action', (
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

      expect(find.byType(ActionSliderButton), findsOneWidget);

      // Trigger the action
      final button = tester.widget<ActionSliderButton>(
        find.byType(ActionSliderButton),
      );
      await button.onActionCompleted();

      expect(actionTriggered, isTrue);
    });

    testWidgets('WaitingReceiveTransitionCard renders without action button', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          const WaitingReceiveTransitionCard(),
        ),
      );

      expect(find.byType(ActionSliderButton), findsNothing);
      expect(
        find.textContaining('Waiting for the receiver to accept'),
        findsOneWidget,
      );
    });

    testWidgets('PromptTransitionCard renders and triggers action', (
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

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(ActionSliderButton), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Test prompt');

      // Trigger the action
      final button = tester.widget<ActionSliderButton>(
        find.byType(ActionSliderButton),
      );
      await button.onActionCompleted();

      expect(actionTriggered, isTrue);
      expect(message, 'Test prompt');
    });

    group('Mouse & Keyboard context', () {
      testWidgets('shows slide text when no mouse is connected', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await tester.pumpWidget(
          buildTestWidget(
            PassTransitionCard(
              onActionPressed: () async => true,
              actionText: 'Pass',
            ),
          ),
        );

        expect(
          find.text('When done, slide to pass the Totem to the next person.'),
          findsOneWidget,
        );
        expect(find.text('press space bar to pass'), findsNothing);

        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('shows click text when a mouse is connected', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        // Add a mouse pointer to simulate connection
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        await tester.pumpWidget(
          buildTestWidget(
            PassTransitionCard(
              onActionPressed: () async => true,
              actionText: 'Pass',
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('When done, click to pass the Totem to the next person.'),
          findsOneWidget,
        );
        expect(find.text('press space bar to pass'), findsNothing);

        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('shows space bar hint on desktop platforms', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        await tester.pumpWidget(
          buildTestWidget(
            PassTransitionCard(
              onActionPressed: () async => true,
              actionText: 'Pass',
            ),
          ),
        );

        expect(find.text('press space bar to pass'), findsOneWidget);

        debugDefaultTargetPlatformOverride = null;
      });
    });
  });
}

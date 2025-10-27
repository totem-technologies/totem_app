import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/sessions/widgets/transition_card.dart';

void main() {
  group('PassReceiveCard Tests', () {
    testWidgets('should render with pass type', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(PassReceiveCard), findsOneWidget);
      expect(
        find.text(
          'When done, press Pass to pass the Totem to the next person.',
        ),
        findsOneWidget,
      );
      expect(find.text('Pass'), findsOneWidget);
    });

    testWidgets('should render with receive type', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.receive,
              onActionPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(PassReceiveCard), findsOneWidget);
      expect(find.text('Check camera & mic then tap Receive'), findsOneWidget);
      expect(find.text('Receive'), findsOneWidget);
    });

    testWidgets('should handle pass button press', (WidgetTester tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pass'));
      expect(pressed, isTrue);
    });

    testWidgets('should handle receive button press', (
      WidgetTester tester,
    ) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.receive,
              onActionPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Receive'));
      expect(pressed, isTrue);
    });

    testWidgets('should have correct card styling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () {},
            ),
          ),
        ),
      );

      final card = tester.widget<Card>(
        find.descendant(
          of: find.byType(PassReceiveCard),
          matching: find.byType(Card),
        ),
      );

      expect(
        card.margin,
        equals(const EdgeInsetsDirectional.symmetric(horizontal: 30)),
      );
      expect(
        card.shape,
        equals(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      );
    });

    testWidgets('should handle disabled button gracefully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () {}, // Empty callback
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pass'));
      // Should not throw or crash
    });

    testWidgets('should render correctly with different themes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () {},
            ),
          ),
        ),
      );

      expect(
        find.text(
          'When done, press Pass to pass the Totem to the next person.',
        ),
        findsOneWidget,
      );
      expect(find.text('Pass'), findsOneWidget);
    });

    testWidgets('should maintain accessibility', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () {},
            ),
          ),
        ),
      );

      // Verify button is tappable
      expect(tester.getSemantics(find.text('Pass')), isNotNull);
    });

    testWidgets('should handle rapid button presses', (
      WidgetTester tester,
    ) async {
      var pressCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () => pressCount++,
            ),
          ),
        ),
      );

      // Rapid taps
      await tester.tap(find.text('Pass'));
      await tester.tap(find.text('Pass'));
      await tester.tap(find.text('Pass'));

      expect(pressCount, equals(3));
    });
  });

  group('TotemCardTransitionType Tests', () {
    test('should have correct enum values', () {
      expect(TotemCardTransitionType.values.length, equals(2));
      expect(
        TotemCardTransitionType.values,
        contains(TotemCardTransitionType.pass),
      );
      expect(
        TotemCardTransitionType.values,
        contains(TotemCardTransitionType.receive),
      );
    });

    test('should have correct string representation', () {
      expect(
        TotemCardTransitionType.pass.toString(),
        equals('TotemCardTransitionType.pass'),
      );
      expect(
        TotemCardTransitionType.receive.toString(),
        equals('TotemCardTransitionType.receive'),
      );
    });
  });
}

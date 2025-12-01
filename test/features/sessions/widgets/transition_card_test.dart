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
              onActionPressed: () async => true,
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
              onActionPressed: () async => true,
            ),
          ),
        ),
      );

      expect(find.byType(PassReceiveCard), findsOneWidget);
      expect(find.text('Check camera & mic then tap Receive'), findsOneWidget);
      expect(find.text('Receive'), findsOneWidget);
    });

    testWidgets('should render with start type', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.start,
              onActionPressed: () async => true,
            ),
          ),
        ),
      );

      expect(find.byType(PassReceiveCard), findsOneWidget);
      expect(
        find.text(
          'Bring participants out of the waiting room and begin '
          'the conversation.',
        ),
        findsOneWidget,
      );
      expect(find.text('Start Session'), findsOneWidget);
    });

    testWidgets('should handle pass slide action', (WidgetTester tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () async {
                pressed = true;
                return true;
              },
            ),
          ),
        ),
      );

      // Find the slide button container
      final gestureFinder = find.byType(GestureDetector);
      expect(gestureFinder, findsOneWidget);

      // Simulate sliding gesture - drag to complete
      final RenderBox box = tester.renderObject(gestureFinder);
      final size = box.size;

      // Start drag
      final startPosition = Offset(0, size.height / 2);
      final endPosition = Offset(size.width * 0.95, size.height / 2);
      
      await tester.drag(gestureFinder, endPosition - startPosition);
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });

    testWidgets('should handle receive slide action', (
      WidgetTester tester,
    ) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.receive,
              onActionPressed: () async {
                pressed = true;
                return true;
              },
            ),
          ),
        ),
      );

      // Find the slide button container
      final gestureFinder = find.byType(GestureDetector);
      expect(gestureFinder, findsOneWidget);

      // Simulate sliding gesture
      final RenderBox box = tester.renderObject(gestureFinder);
      final size = box.size;

      final startPosition = Offset(0, size.height / 2);
      final endPosition = Offset(size.width * 0.95, size.height / 2);
      
      await tester.drag(gestureFinder, endPosition - startPosition);
      await tester.pumpAndSettle();

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
              onActionPressed: () async => true,
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

    testWidgets('should handle async callback gracefully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () async => true,
            ),
          ),
        ),
      );

      final gestureFinder = find.byType(GestureDetector);
      final RenderBox box = tester.renderObject(gestureFinder);
      final size = box.size;

      // Try to slide - should not throw or crash
      final startPosition = Offset(0, size.height / 2);
      final endPosition = Offset(size.width * 0.95, size.height / 2);
      
      await tester.drag(gestureFinder, endPosition - startPosition);
      await tester.pumpAndSettle();
      
      // Should complete without errors
      expect(gestureFinder, findsOneWidget);
    });

    testWidgets('should handle callback returning false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () async => false,
            ),
          ),
        ),
      );

      final gestureFinder = find.byType(GestureDetector);
      final RenderBox box = tester.renderObject(gestureFinder);
      final size = box.size;

      // Slide to trigger callback
      final startPosition = Offset(0, size.height / 2);
      final endPosition = Offset(size.width * 0.95, size.height / 2);
      
      await tester.drag(gestureFinder, endPosition - startPosition);
      await tester.pumpAndSettle();

      // Widget should still exist after callback returns false
      expect(gestureFinder, findsOneWidget);
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
              onActionPressed: () async => true,
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

    testWidgets('should show loading indicator during async operation', (
      WidgetTester tester,
    ) async {
      var callbackStarted = false;
      var callbackComplete = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () async {
                callbackStarted = true;
                await Future<void>.delayed(const Duration(milliseconds: 100));
                callbackComplete = true;
                return true;
              },
            ),
          ),
        ),
      );

      final gestureFinder = find.byType(GestureDetector);
      final RenderBox box = tester.renderObject(gestureFinder);
      final size = box.size;

      // Slide to trigger callback
      final startPosition = Offset(0, size.height / 2);
      final endPosition = Offset(size.width * 0.95, size.height / 2);
      
      await tester.drag(gestureFinder, endPosition - startPosition);
      await tester.pump();

      // Check that loading indicator appears
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(callbackStarted, isTrue);

      // Wait for callback to complete
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(callbackComplete, isTrue);
    });

    testWidgets('should snap back if slide is incomplete', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassReceiveCard(
              type: TotemCardTransitionType.pass,
              onActionPressed: () async => true,
            ),
          ),
        ),
      );

      final gestureFinder = find.byType(GestureDetector);
      final RenderBox box = tester.renderObject(gestureFinder);
      final size = box.size;

      // Slide only partway (not enough to trigger action)
      final startPosition = Offset(0, size.height / 2);
      final endPosition = Offset(size.width * 0.3, size.height / 2);
      
      await tester.drag(gestureFinder, endPosition - startPosition);
      await tester.pump();
      
      // Release - should snap back
      await tester.pumpAndSettle();

      // Widget should still be in original state
      expect(gestureFinder, findsOneWidget);
    });
  });

  group('TotemCardTransitionType Tests', () {
    test('should have correct enum values', () {
      expect(TotemCardTransitionType.values.length, equals(3));
      expect(
        TotemCardTransitionType.values,
        contains(TotemCardTransitionType.pass),
      );
      expect(
        TotemCardTransitionType.values,
        contains(TotemCardTransitionType.receive),
      );
      expect(
        TotemCardTransitionType.values,
        contains(TotemCardTransitionType.start),
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
      expect(
        TotemCardTransitionType.start.toString(),
        equals('TotemCardTransitionType.start'),
      );
    });
  });
}

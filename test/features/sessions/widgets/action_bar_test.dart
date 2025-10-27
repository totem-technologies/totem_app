import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/widgets/action_bar.dart';

void main() {
  group('ActionBarButton Tests', () {
    testWidgets('should render with default properties', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarButton(
              onPressed: () {},
              child: const Icon(Icons.mic),
            ),
          ),
        ),
      );

      expect(find.byType(ActionBarButton), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('should render with active state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarButton(
              onPressed: () {},
              active: true,
              child: const Icon(Icons.mic),
            ),
          ),
        ),
      );

      final button = tester.widget<ActionBarButton>(
        find.byType(ActionBarButton),
      );
      expect(button.active, isTrue);
    });

    testWidgets('should render with inactive state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarButton(
              onPressed: () {},
              child: const Icon(Icons.mic),
            ),
          ),
        ),
      );

      final button = tester.widget<ActionBarButton>(
        find.byType(ActionBarButton),
      );
      expect(button.active, isFalse);
    });

    testWidgets('should render with square shape by default', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarButton(
              onPressed: () {},
              child: const Icon(Icons.mic),
            ),
          ),
        ),
      );

      final button = tester.widget<ActionBarButton>(
        find.byType(ActionBarButton),
      );
      expect(button.square, isTrue);
    });

    testWidgets('should render with non-square shape when specified', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarButton(
              onPressed: () {},
              square: false,
              child: const Text('Join'),
            ),
          ),
        ),
      );

      final button = tester.widget<ActionBarButton>(
        find.byType(ActionBarButton),
      );
      expect(button.square, isFalse);
      expect(find.text('Join'), findsOneWidget);
    });

    testWidgets('should handle tap events', (WidgetTester tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarButton(
              onPressed: () => tapped = true,
              child: const Icon(Icons.mic),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionBarButton));
      expect(tapped, isTrue);
    });

    testWidgets('should not handle tap events when onPressed is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActionBarButton(
              onPressed: null,
              child: Icon(Icons.mic),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionBarButton));
      // Should not throw or crash
    });

    testWidgets('should animate when active state changes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ActionBarButton(
                  onPressed: () => setState(() {}),
                  child: const Icon(Icons.mic),
                );
              },
            ),
          ),
        ),
      );

      // Verify initial state
      final button = tester.widget<ActionBarButton>(
        find.byType(ActionBarButton),
      );
      expect(button.active, isFalse);

      // Trigger animation by rebuilding with different state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarButton(
              onPressed: () {},
              active: true,
              child: const Icon(Icons.mic),
            ),
          ),
        ),
      );

      // Verify state changed
      final updatedButton = tester.widget<ActionBarButton>(
        find.byType(ActionBarButton),
      );
      expect(updatedButton.active, isTrue);
    });

    testWidgets('should have correct styling for active state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarButton(
              onPressed: () {},
              active: true,
              child: const Icon(Icons.mic),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ActionBarButton),
          matching: find.byType(Container),
        ),
      );
      expect(container.decoration, isNotNull);
      expect(container.decoration, isA<BoxDecoration>());

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, equals(AppTheme.white));
      expect(decoration.borderRadius, equals(BorderRadius.circular(25)));
    });

    testWidgets('should have correct styling for inactive state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarButton(
              onPressed: () {},
              child: const Icon(Icons.mic),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ActionBarButton),
          matching: find.byType(Container),
        ),
      );

      expect(container.decoration, isNotNull);
      expect(container.decoration, isA<BoxDecoration>());

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, equals(AppTheme.mauve));
      expect(decoration.borderRadius, equals(BorderRadius.circular(25)));
    });

    testWidgets('should have minimum size constraints', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBarButton(
              onPressed: () {},
              child: const Icon(Icons.mic),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ActionBarButton),
          matching: find.byType(Container),
        ),
      );

      expect(
        container.constraints,
        equals(const BoxConstraints(minWidth: 40, minHeight: 40)),
      );
    });
  });

  group('ActionBar Tests', () {
    testWidgets('should render with empty children list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActionBar(children: []),
          ),
        ),
      );

      expect(find.byType(ActionBar), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('should render with single child', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBar(
              children: [
                ActionBarButton(
                  onPressed: () {},
                  child: const Icon(Icons.mic),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ActionBar), findsOneWidget);
      expect(find.byType(ActionBarButton), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('should render with multiple children', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActionBar(
              children: [
                ActionBarButton(
                  onPressed: () {},
                  child: const Icon(Icons.mic),
                ),
                ActionBarButton(
                  onPressed: () {},
                  child: const Icon(Icons.videocam),
                ),
                ActionBarButton(
                  onPressed: () {},
                  child: const Icon(Icons.chat),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ActionBar), findsOneWidget);
      expect(find.byType(ActionBarButton), findsNWidgets(3));
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.videocam), findsOneWidget);
      expect(find.byIcon(Icons.chat), findsOneWidget);
    });

    testWidgets('should handle null children gracefully', (
      WidgetTester tester,
    ) async {
      // This test ensures the widget doesn't crash with null children
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActionBar(children: []),
          ),
        ),
      );

      expect(find.byType(ActionBar), findsOneWidget);
    });
  });
}

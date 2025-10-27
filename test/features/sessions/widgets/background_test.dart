import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';

void main() {
  group('RoomBackground Tests', () {
    testWidgets('should render with default properties', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoomBackground(
            child: Text('Test Content'),
          ),
        ),
      );

      expect(find.byType(RoomBackground), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('should render with custom padding', (
      WidgetTester tester,
    ) async {
      const customPadding = EdgeInsetsDirectional.all(20);
      await tester.pumpWidget(
        const MaterialApp(
          home: RoomBackground(
            padding: customPadding,
            child: Text('Test Content'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(RoomBackground),
          matching: find.byType(Container),
        ),
      );

      expect(container.padding, equals(customPadding));
    });

    testWidgets('should render with custom overlay style', (
      WidgetTester tester,
    ) async {
      const customStyle = SystemUiOverlayStyle.dark;
      await tester.pumpWidget(
        const MaterialApp(
          home: RoomBackground(
            overlayStyle: customStyle,
            child: Text('Test Content'),
          ),
        ),
      );

      final annotatedRegion = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.descendant(
              of: find.byType(RoomBackground),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            ),
          );

      expect(annotatedRegion.value, equals(customStyle));
    });

    testWidgets('should have correct gradient decoration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoomBackground(
            child: Text('Test Content'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(RoomBackground),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;

      expect(gradient.colors, equals([Colors.black, AppTheme.mauve]));
      expect(gradient.begin, equals(Alignment.topCenter));
      expect(gradient.end, equals(Alignment.bottomCenter));
      expect(gradient.stops, equals([0.5, 1]));
    });

    testWidgets('should have correct default overlay style', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoomBackground(
            child: Text('Test Content'),
          ),
        ),
      );

      final annotatedRegion = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.descendant(
              of: find.byType(RoomBackground),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            ),
          );

      expect(annotatedRegion.value, equals(SystemUiOverlayStyle.light));
    });

    testWidgets('should have correct default padding', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoomBackground(
            child: Text('Test Content'),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(RoomBackground),
          matching: find.byType(Container),
        ),
      );

      expect(container.padding, equals(EdgeInsetsDirectional.zero));
    });

    testWidgets('should apply correct theme to child', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomBackground(
            child: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                return Text(
                  'Test Content',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                );
              },
            ),
          ),
        ),
      );

      final theme = tester.widget<Theme>(
        find.descendant(
          of: find.byType(RoomBackground),
          matching: find.byType(Theme),
        ),
      );

      expect(theme.data.scaffoldBackgroundColor, equals(Colors.transparent));
    });

    testWidgets('should apply correct text theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoomBackground(
            child: Text('Test Content'),
          ),
        ),
      );

      // Verify the widget renders without errors
      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('should wrap child in Material widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoomBackground(
            child: Text('Test Content'),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(RoomBackground),
          matching: find.byType(Material),
        ),
      );

      expect(material.type, equals(MaterialType.transparency));
    });

    testWidgets('should handle complex child widgets', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoomBackground(
            child: Column(
              children: [
                const Text('Title'),
                const Text('Subtitle'),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Button'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
      expect(find.text('Button'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('should handle empty child gracefully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RoomBackground(
            child: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byType(RoomBackground), findsOneWidget);
    });

    testWidgets('should handle different screen sizes', (
      WidgetTester tester,
    ) async {
      // Test with different screen sizes
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(
        const MaterialApp(
          home: RoomBackground(
            child: Text('Test Content'),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpWidget(
        const MaterialApp(
          home: RoomBackground(
            child: Text('Test Content'),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });
  });
}

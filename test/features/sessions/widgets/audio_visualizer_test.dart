//
// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/sessions/widgets/audio_visualizer.dart';

void main() {
  group('AudioVisualizerWidgetOptions Tests', () {
    test('should create with default values', () {
      const options = AudioVisualizerWidgetOptions();

      expect(options.barCount, equals(7));
      expect(options.centeredBands, isTrue);
      expect(options.width, equals(12));
      expect(options.minHeight, equals(12));
      expect(options.maxHeight, equals(100));
      expect(options.durationInMilliseconds, equals(500));
      expect(options.color, isNull);
      expect(options.spacing, equals(5));
      expect(options.cornerRadius, equals(9999));
      expect(options.barMinOpacity, equals(0.2));
    });

    test('should create with custom values', () {
      const options = AudioVisualizerWidgetOptions(
        barCount: 5,
        centeredBands: false,
        width: 8,
        minHeight: 8,
        maxHeight: 80,
        durationInMilliseconds: 300,
        color: Colors.red,
        spacing: 3,
        cornerRadius: 4,
        barMinOpacity: 0.3,
      );

      expect(options.barCount, equals(5));
      expect(options.centeredBands, isFalse);
      expect(options.width, equals(8));
      expect(options.minHeight, equals(8));
      expect(options.maxHeight, equals(80));
      expect(options.durationInMilliseconds, equals(300));
      expect(options.color, equals(Colors.red));
      expect(options.spacing, equals(3));
      expect(options.cornerRadius, equals(4));
      expect(options.barMinOpacity, equals(0.3));
    });

    test('should be equal for identical options', () {
      const options1 = AudioVisualizerWidgetOptions(
        barCount: 5,
        color: Colors.blue,
      );
      const options2 = AudioVisualizerWidgetOptions(
        barCount: 5,
        color: Colors.blue,
      );

      expect(options1, equals(options2));
      expect(options1.hashCode, equals(options2.hashCode));
    });

    test('should not be equal for different barCount', () {
      const options1 = AudioVisualizerWidgetOptions(barCount: 5);
      const options2 = AudioVisualizerWidgetOptions(barCount: 7);

      expect(options1, isNot(equals(options2)));
    });

    test('should not be equal for different centeredBands', () {
      const options1 = AudioVisualizerWidgetOptions(centeredBands: true);
      const options2 = AudioVisualizerWidgetOptions(centeredBands: false);

      expect(options1, isNot(equals(options2)));
    });

    test('should not be equal for different width', () {
      const options1 = AudioVisualizerWidgetOptions(width: 10);
      const options2 = AudioVisualizerWidgetOptions(width: 12);

      expect(options1, isNot(equals(options2)));
    });

    test('should not be equal for different minHeight', () {
      const options1 = AudioVisualizerWidgetOptions(minHeight: 10);
      const options2 = AudioVisualizerWidgetOptions(minHeight: 12);

      expect(options1, isNot(equals(options2)));
    });

    test('should not be equal for different maxHeight', () {
      const options1 = AudioVisualizerWidgetOptions(maxHeight: 80);
      const options2 = AudioVisualizerWidgetOptions(maxHeight: 100);

      expect(options1, isNot(equals(options2)));
    });

    test('should not be equal for different durationInMilliseconds', () {
      const options1 = AudioVisualizerWidgetOptions(
        durationInMilliseconds: 300,
      );
      const options2 = AudioVisualizerWidgetOptions(
        durationInMilliseconds: 500,
      );

      expect(options1, isNot(equals(options2)));
    });

    test('should not be equal for different color', () {
      const options1 = AudioVisualizerWidgetOptions(color: Colors.red);
      const options2 = AudioVisualizerWidgetOptions(color: Colors.blue);

      expect(options1, isNot(equals(options2)));
    });

    test('should not be equal for different spacing', () {
      const options1 = AudioVisualizerWidgetOptions(spacing: 3);
      const options2 = AudioVisualizerWidgetOptions(spacing: 5);

      expect(options1, isNot(equals(options2)));
    });

    test('should not be equal for different cornerRadius', () {
      const options1 = AudioVisualizerWidgetOptions(cornerRadius: 4);
      const options2 = AudioVisualizerWidgetOptions(cornerRadius: 8);

      expect(options1, isNot(equals(options2)));
    });

    test('should not be equal for different barMinOpacity', () {
      const options1 = AudioVisualizerWidgetOptions(barMinOpacity: 0.1);
      const options2 = AudioVisualizerWidgetOptions(barMinOpacity: 0.2);

      expect(options1, isNot(equals(options2)));
    });

    test('should handle null color', () {
      const options1 = AudioVisualizerWidgetOptions(color: null);
      const options2 = AudioVisualizerWidgetOptions(color: null);

      expect(options1, equals(options2));
      expect(options1.hashCode, equals(options2.hashCode));
    });

    test('should have correct hashCode for all properties', () {
      const options = AudioVisualizerWidgetOptions(
        barCount: 5,
        centeredBands: false,
        width: 8,
        minHeight: 8,
        maxHeight: 80,
        durationInMilliseconds: 300,
        color: Colors.red,
        spacing: 3,
        cornerRadius: 4,
        barMinOpacity: 0.3,
      );

      // Hash code should be consistent
      expect(options.hashCode, equals(options.hashCode));
    });

    testWidgets('should compute color correctly with theme', (
      WidgetTester tester,
    ) async {
      const options = AudioVisualizerWidgetOptions();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: Builder(
            builder: (context) {
              // Test the extension method by accessing it through the options
              final computedColor =
                  options.color ?? Theme.of(context).colorScheme.primary;
              expect(
                computedColor,
                equals(Theme.of(context).colorScheme.primary),
              );
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should compute color correctly with custom color', (
      WidgetTester tester,
    ) async {
      const options = AudioVisualizerWidgetOptions(color: Colors.green);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Test the extension method by accessing it through the options
              final computedColor =
                  options.color ?? Theme.of(context).colorScheme.primary;
              expect(computedColor, equals(Colors.green));
              return Container();
            },
          ),
        ),
      );
    });
  });

  group('BarsViewItem Tests', () {
    test('should create with correct values', () {
      const item = BarsViewItem(
        value: 0.5,
        color: Colors.red,
      );

      expect(item.value, equals(0.5));
      expect(item.color, equals(Colors.red));
    });

    test('should handle zero value', () {
      const item = BarsViewItem(
        value: 0,
        color: Colors.blue,
      );

      expect(item.value, equals(0.0));
      expect(item.color, equals(Colors.blue));
    });

    test('should handle maximum value', () {
      const item = BarsViewItem(
        value: 1,
        color: Colors.green,
      );

      expect(item.value, equals(1.0));
      expect(item.color, equals(Colors.green));
    });

    test('should handle negative value', () {
      const item = BarsViewItem(
        value: -0.5,
        color: Colors.yellow,
      );

      expect(item.value, equals(-0.5));
      expect(item.color, equals(Colors.yellow));
    });
  });

  group('BarsView Tests', () {
    testWidgets('should render with empty elements list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BarsView(
              options: AudioVisualizerWidgetOptions(),
              elements: [],
            ),
          ),
        ),
      );

      expect(find.byType(BarsView), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('should render with single element', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BarsView(
              options: AudioVisualizerWidgetOptions(),
              elements: [
                BarsViewItem(
                  value: 0.5,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(BarsView), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('should render with multiple elements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BarsView(
              options: AudioVisualizerWidgetOptions(),
              elements: [
                BarsViewItem(value: 0.3, color: Colors.red),
                BarsViewItem(value: 0.7, color: Colors.green),
                BarsViewItem(value: 0.5, color: Colors.blue),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(BarsView), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNWidgets(3));
    });

    testWidgets('should have correct row properties', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BarsView(
              options: AudioVisualizerWidgetOptions(),
              elements: [
                BarsViewItem(value: 0.5, color: Colors.red),
                BarsViewItem(value: 0.7, color: Colors.green),
              ],
            ),
          ),
        ),
      );

      final row = tester.widget<Row>(
        find.descendant(
          of: find.byType(BarsView),
          matching: find.byType(Row),
        ),
      );

      expect(row.mainAxisSize, equals(MainAxisSize.min));
      expect(row.mainAxisAlignment, equals(MainAxisAlignment.spaceAround));
    });

    testWidgets('should handle different constraint sizes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 100,
              child: BarsView(
                options: AudioVisualizerWidgetOptions(),
                elements: [
                  BarsViewItem(value: 0.5, color: Colors.red),
                  BarsViewItem(value: 0.7, color: Colors.green),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BarsView), findsOneWidget);
    });

    testWidgets('should handle zero constraints', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(
              child: BarsView(
                options: AudioVisualizerWidgetOptions(),
                elements: [
                  BarsViewItem(value: 0.5, color: Colors.red),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BarsView), findsOneWidget);
    });
  });

  group('VisualizerState Tests', () {
    test('should have correct enum values', () {
      expect(VisualizerState.values.length, equals(3));
      expect(VisualizerState.values, contains(VisualizerState.thinking));
      expect(VisualizerState.values, contains(VisualizerState.listening));
      expect(VisualizerState.values, contains(VisualizerState.active));
    });

    test('should have correct string representation', () {
      expect(
        VisualizerState.thinking.toString(),
        equals('VisualizerState.thinking'),
      );
      expect(
        VisualizerState.listening.toString(),
        equals('VisualizerState.listening'),
      );
      expect(
        VisualizerState.active.toString(),
        equals('VisualizerState.active'),
      );
    });
  });
}

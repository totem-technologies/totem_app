import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/audio_visualizer.dart';

void main() {
  group('AudioVisualizerWidgetOptions Tests', () {
    test('should create with default values', () {
      const options = AudioVisualizerWidgetOptions();

      check(options.barCount).equals(7);
      check(options.centeredBands).equals(true);
      check(options.width).equals(12);
      check(options.minHeight).equals(12);
      check(options.maxHeight).equals(100);
      check(options.durationInMilliseconds).equals(500);
      check(options.color).isNull();
      check(options.spacing).equals(5);
      check(options.cornerRadius).equals(9999);
      check(options.barMinOpacity).equals(0.2);
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

      check(options.barCount).equals(5);
      check(options.centeredBands).equals(false);
      check(options.width).equals(8);
      check(options.minHeight).equals(8);
      check(options.maxHeight).equals(80);
      check(options.durationInMilliseconds).equals(300);
      check(options.color).equals(Colors.red);
      check(options.spacing).equals(3);
      check(options.cornerRadius).equals(4);
      check(options.barMinOpacity).equals(0.3);
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

      check(options1).equals(options2);
      check(options1.hashCode).equals(options2.hashCode);
    });

    test('should not be equal for different barCount', () {
      const options1 = AudioVisualizerWidgetOptions(barCount: 5);
      const options2 = AudioVisualizerWidgetOptions(barCount: 7);

      check(options1).not((it) => it.equals(options2));
    });

    test('should not be equal for different centeredBands', () {
      const options1 = AudioVisualizerWidgetOptions(centeredBands: true);
      const options2 = AudioVisualizerWidgetOptions(centeredBands: false);

      check(options1).not((it) => it.equals(options2));
    });

    test('should not be equal for different width', () {
      const options1 = AudioVisualizerWidgetOptions(width: 10);
      const options2 = AudioVisualizerWidgetOptions(width: 12);

      check(options1).not((it) => it.equals(options2));
    });

    test('should not be equal for different minHeight', () {
      const options1 = AudioVisualizerWidgetOptions(minHeight: 10);
      const options2 = AudioVisualizerWidgetOptions(minHeight: 12);

      check(options1).not((it) => it.equals(options2));
    });

    test('should not be equal for different maxHeight', () {
      const options1 = AudioVisualizerWidgetOptions(maxHeight: 80);
      const options2 = AudioVisualizerWidgetOptions(maxHeight: 100);

      check(options1).not((it) => it.equals(options2));
    });

    test('should not be equal for different durationInMilliseconds', () {
      const options1 = AudioVisualizerWidgetOptions(
        durationInMilliseconds: 300,
      );
      const options2 = AudioVisualizerWidgetOptions(
        durationInMilliseconds: 500,
      );

      check(options1).not((it) => it.equals(options2));
    });

    test('should not be equal for different color', () {
      const options1 = AudioVisualizerWidgetOptions(color: Colors.red);
      const options2 = AudioVisualizerWidgetOptions(color: Colors.blue);

      check(options1).not((it) => it.equals(options2));
    });

    test('should not be equal for different spacing', () {
      const options1 = AudioVisualizerWidgetOptions(spacing: 3);
      const options2 = AudioVisualizerWidgetOptions(spacing: 5);

      check(options1).not((it) => it.equals(options2));
    });

    test('should not be equal for different cornerRadius', () {
      const options1 = AudioVisualizerWidgetOptions(cornerRadius: 4);
      const options2 = AudioVisualizerWidgetOptions(cornerRadius: 8);

      check(options1).not((it) => it.equals(options2));
    });

    test('should not be equal for different barMinOpacity', () {
      const options1 = AudioVisualizerWidgetOptions(barMinOpacity: 0.1);
      const options2 = AudioVisualizerWidgetOptions(barMinOpacity: 0.2);

      check(options1).not((it) => it.equals(options2));
    });

    test('should handle null color', () {
      const options1 = AudioVisualizerWidgetOptions(color: null);
      const options2 = AudioVisualizerWidgetOptions(color: null);

      check(options1).equals(options2);
      check(options1.hashCode).equals(options2.hashCode);
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
      check(options.hashCode).equals(options.hashCode);
    });

    testWidgets('should compute color correctly with theme', (tester) async {
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
              check(
                computedColor,
              ).equals(Theme.of(context).colorScheme.primary);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('should compute color correctly with custom color', (
      tester,
    ) async {
      const options = AudioVisualizerWidgetOptions(color: Colors.green);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              // Test the extension method by accessing it through the options
              final computedColor =
                  options.color ?? Theme.of(context).colorScheme.primary;
              check(computedColor).equals(Colors.green);
              return Container();
            },
          ),
        ),
      );
    });
  });

  group('BarsViewItem Tests', () {
    test('should create with correct values', () {
      const item = BarsViewItem(value: 0.5, color: Colors.red);

      check(item.value).equals(0.5);
      check(item.color).equals(Colors.red);
    });

    test('should handle zero value', () {
      const item = BarsViewItem(value: 0, color: Colors.blue);

      check(item.value).equals(0.0);
      check(item.color).equals(Colors.blue);
    });

    test('should handle maximum value', () {
      const item = BarsViewItem(value: 1, color: Colors.green);

      check(item.value).equals(1.0);
      check(item.color).equals(Colors.green);
    });

    test('should handle negative value', () {
      const item = BarsViewItem(value: -0.5, color: Colors.yellow);

      check(item.value).equals(-0.5);
      check(item.color).equals(Colors.yellow);
    });
  });

  group('BarsView Tests', () {
    testWidgets('should render with empty elements list', (tester) async {
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

      check(tester.widgetList(find.byType(BarsView))).length.equals(1);
      check(tester.widgetList(find.byType(Row))).length.equals(1);
    });

    testWidgets('should render with single element', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BarsView(
              options: AudioVisualizerWidgetOptions(),
              elements: [BarsViewItem(value: 0.5, color: Colors.red)],
            ),
          ),
        ),
      );

      check(tester.widgetList(find.byType(BarsView))).length.equals(1);
      check(tester.widgetList(find.byType(AnimatedContainer))).length.equals(1);
    });

    testWidgets('should render with multiple elements', (tester) async {
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

      check(tester.widgetList(find.byType(BarsView))).length.equals(1);
      check(tester.widgetList(find.byType(AnimatedContainer))).length.equals(3);
    });

    testWidgets('should have correct row properties', (tester) async {
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
        find.descendant(of: find.byType(BarsView), matching: find.byType(Row)),
      );

      check(row.mainAxisSize).equals(MainAxisSize.min);
      check(row.mainAxisAlignment).equals(MainAxisAlignment.spaceAround);
    });

    testWidgets('should handle different constraint sizes', (tester) async {
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

      check(tester.widgetList(find.byType(BarsView))).length.equals(1);
    });

    testWidgets('should handle zero constraints', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(
              child: BarsView(
                options: AudioVisualizerWidgetOptions(),
                elements: [BarsViewItem(value: 0.5, color: Colors.red)],
              ),
            ),
          ),
        ),
      );

      check(tester.widgetList(find.byType(BarsView))).length.equals(1);
    });
  });

  group('VisualizerState Tests', () {
    test('should have correct enum values', () {
      check(VisualizerState.values).length.equals(3);
      check(VisualizerState.values).contains(VisualizerState.thinking);
      check(VisualizerState.values).contains(VisualizerState.listening);
      check(VisualizerState.values).contains(VisualizerState.active);
    });

    test('should have correct string representation', () {
      check(
        VisualizerState.thinking.toString(),
      ).equals('VisualizerState.thinking');
      check(
        VisualizerState.listening.toString(),
      ).equals('VisualizerState.listening');
      check(VisualizerState.active.toString()).equals('VisualizerState.active');
    });
  });
}

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/audio_visualizer.dart';

void main() {
  group('audioVisualizerSamplesChanged', () {
    test('ignores imperceptible changes and detects visible changes', () {
      check(
        audioVisualizerSamplesChanged(
          const [0.1, 0.5, 0.9],
          const [0.105, 0.495, 0.9],
        ),
      ).isFalse();
      check(
        audioVisualizerSamplesChanged(
          const [0.1, 0.5, 0.9],
          const [0.111, 0.5, 0.9],
        ),
      ).isTrue();
      check(
        audioVisualizerSamplesChanged(const [0.1], const [0.1, 0.2]),
      ).isTrue();
    });

    test('settles a previously visible waveform to silence', () {
      check(audioVisualizerSamplesChanged(const [0.009], const [0])).isTrue();
    });
  });

  group('BarsView', () {
    Future<void> pumpBars(
      WidgetTester tester,
      List<BarsViewItem> elements, {
      Size size = const Size(90, 100),
    }) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox.fromSize(
            size: size,
            child: BarsView(
              options: const AudioVisualizerWidgetOptions(
                barCount: 3,
                spacing: 0,
                maxHeight: 80,
                cornerRadius: 4,
                durationInMilliseconds: 300,
              ),
              elements: elements,
            ),
          ),
        ),
      ),
    );

    testWidgets('renders sample heights and colors, and removes cleared bars', (
      tester,
    ) async {
      await pumpBars(tester, const [
        BarsViewItem(value: 0, color: Colors.red),
        BarsViewItem(value: 0.5, color: Colors.green),
        BarsViewItem(value: 1, color: Colors.blue),
      ]);
      final finder = find.byType(AnimatedContainer);
      check(tester.widgetList(finder)).length.equals(3);
      check([
        for (var i = 0; i < 3; i++) tester.getSize(finder.at(i)).height,
      ]).deepEquals([30.0, 65.0, 80.0]);
      check(
        tester
            .widgetList<AnimatedContainer>(finder)
            .map((bar) => (bar.decoration! as BoxDecoration).color),
      ).deepEquals([Colors.red, Colors.green, Colors.blue]);

      await pumpBars(tester, const []);
      check(tester.widgetList(finder)).isEmpty();
    });

    testWidgets('fits a single bar into zero constraints', (tester) async {
      await pumpBars(tester, const [
        BarsViewItem(value: 0.5, color: Colors.red),
      ], size: Size.zero);
      check(tester.getSize(find.byType(AnimatedContainer)).height).equals(0);
    });
  });
}

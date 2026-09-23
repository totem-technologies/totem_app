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

  group('AudioVisualizerWidgetOptions Tests', () {
    test('should create with default values', () {
      const options = AudioVisualizerWidgetOptions();

      for (final color in [null, Colors.blue]) {
        final first = options(color);
        final second = options(color);
        check(identical(first, second)).isFalse();
        check(first).equals(second);
        check(first.hashCode).equals(second.hashCode);
      }
    });

    test('every option participates in equality', () {
      const defaults = AudioVisualizerWidgetOptions();
      const variants = {
        'barCount': AudioVisualizerWidgetOptions(barCount: 5),
        'centeredBands': AudioVisualizerWidgetOptions(centeredBands: false),
        'width': AudioVisualizerWidgetOptions(width: 8),
        'minHeight': AudioVisualizerWidgetOptions(minHeight: 8),
        'maxHeight': AudioVisualizerWidgetOptions(maxHeight: 80),
        'duration': AudioVisualizerWidgetOptions(durationInMilliseconds: 300),
        'color': AudioVisualizerWidgetOptions(color: Colors.red),
        'spacing': AudioVisualizerWidgetOptions(spacing: 3),
        'cornerRadius': AudioVisualizerWidgetOptions(cornerRadius: 4),
        'barMinOpacity': AudioVisualizerWidgetOptions(barMinOpacity: 0.3),
      };
      for (final entry in variants.entries) {
        check(entry.value, because: entry.key).not((it) => it.equals(defaults));
      }
    });
  });

  testWidgets(
    'waveform uses the theme color unless a custom color is supplied',
    (tester) async {
      for (final color in <Color?>[null, Colors.green]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Theme(
              data: ThemeData(
                colorScheme: const ColorScheme.light(primary: Colors.blue),
              ),
              child: Center(
                child: SizedBox(
                  width: 100,
                  height: 50,
                  child: SoundWaveformWidget(
                    options: AudioVisualizerWidgetOptions(
                      barCount: 3,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final bar = tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .first;
        check(
          (bar.decoration! as BoxDecoration).color,
        ).equals((color ?? Colors.blue).withValues(alpha: 0.1));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

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

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
      TextDirection direction = TextDirection.ltr,
      bool tickerEnabled = true,
    }) => tester.pumpWidget(
      Directionality(
        textDirection: direction,
        child: TickerMode(
          enabled: tickerEnabled,
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
      ),
    );

    testWidgets('renders the current bars and clears them when samples end', (
      tester,
    ) async {
      await pumpBars(tester, const [
        BarsViewItem(value: 0, color: Colors.red),
        BarsViewItem(value: 0.5, color: Colors.green),
        BarsViewItem(value: 1, color: Colors.blue),
      ]);
      check(paintedBars(tester)).length.equals(3);

      await pumpBars(tester, const []);
      check(paintedBars(tester)).isEmpty();
      check(tester.binding.hasScheduledFrame).isFalse();
    });

    testWidgets('fits a single bar into zero constraints', (tester) async {
      await pumpBars(tester, const [
        BarsViewItem(value: 0.5, color: Colors.red),
      ], size: Size.zero);
      check(paintedBars(tester)).isEmpty();
    });

    testWidgets(
      'interpolates colors and heights and retargets without a jump',
      (tester) async {
        const low = [BarsViewItem(value: 0, color: Colors.red)];
        const high = [BarsViewItem(value: 1, color: Colors.blue)];
        const size = Size(10, 50);
        await pumpBars(tester, low, size: size);
        await pumpBars(tester, high, size: size);
        await tester.pump(const Duration(milliseconds: 50));
        final halfway = paintedBars(tester).single;
        check(halfway.rect.height).equals(30);
        final expected = Color.lerp(Colors.red, Colors.blue, 0.5)!;
        // Canvas paint stores color channels as floats, so allow rounding.
        check((halfway.color.r - expected.r).abs()).isLessThan(0.000001);
        check((halfway.color.g - expected.g).abs()).isLessThan(0.000001);
        check((halfway.color.b - expected.b).abs()).isLessThan(0.000001);

        await pumpBars(tester, low, size: size);
        check(paintedBars(tester).single.rect).equals(halfway.rect);
        check(paintedBars(tester).single.color).equals(halfway.color);
        await tester.pump(const Duration(milliseconds: 110));
        check(paintedBars(tester).single.rect.height).equals(10);
        check(
          paintedBars(tester).single.color.toARGB32(),
        ).equals(Colors.red.toARGB32());
        check(tester.binding.hasScheduledFrame).isFalse();

        await pumpBars(tester, List.of(low), size: size);
        check(tester.binding.hasScheduledFrame).isFalse();
      },
    );

    testWidgets('reverses the bar order in right-to-left layouts', (
      tester,
    ) async {
      await pumpBars(tester, const [
        BarsViewItem(value: 0, color: Colors.red),
        BarsViewItem(value: 1, color: Colors.blue),
      ], direction: TextDirection.rtl);
      final bars = paintedBars(tester);
      check(bars.map((bar) => bar.rect.center.dx)).deepEquals([67.5, 22.5]);
      check(
        bars.map((bar) => bar.color.toARGB32()),
      ).deepEquals([Colors.red, Colors.blue].map((color) => color.toARGB32()));
    });

    testWidgets(
      'animation ticks paint new heights without rebuilding widgets',
      (tester) async {
        const size = Size(10, 50);
        await pumpBars(tester, const [
          BarsViewItem(value: 0, color: Colors.red),
        ], size: size);
        await pumpBars(tester, const [
          BarsViewItem(value: 1, color: Colors.red),
        ], size: size);
        final previous = debugOnRebuildDirtyWidget;
        var rebuilds = 0;
        try {
          debugOnRebuildDirtyWidget = (_, _) => rebuilds++;
          await tester.pump(const Duration(milliseconds: 50));
          check(paintedBars(tester).single.rect.height).equals(30);
          check(rebuilds).equals(0);
        } finally {
          debugOnRebuildDirtyWidget = previous;
        }
      },
    );

    testWidgets('adds and removes bars while resizing an active transition', (
      tester,
    ) async {
      await pumpBars(tester, const [BarsViewItem(value: 0, color: Colors.red)]);
      await pumpBars(tester, const [
        BarsViewItem(value: 1, color: Colors.blue),
        BarsViewItem(value: 0.5, color: Colors.green),
      ]);
      check(paintedBars(tester)).length.equals(2);
      await tester.pump(const Duration(milliseconds: 30));
      await pumpBars(tester, const [
        BarsViewItem(value: 1, color: Colors.blue),
      ], size: const Size(20, 20));
      await tester.pump(const Duration(milliseconds: 110));
      final bar = paintedBars(tester).single;
      check(bar.rect.height).equals(20);
      check(bar.rect.center).equals(const Offset(10, 10));
      check(bar.color.toARGB32()).equals(Colors.blue.toARGB32());
      check(tester.binding.hasScheduledFrame).isFalse();
    });

    testWidgets('suspends ticking offstage and disposes an active transition', (
      tester,
    ) async {
      const low = [BarsViewItem(value: 0, color: Colors.red)];
      const high = [BarsViewItem(value: 1, color: Colors.red)];
      const size = Size(10, 50);
      await pumpBars(tester, low, size: size);
      await pumpBars(tester, high, size: size);
      await tester.pump(const Duration(milliseconds: 20));
      await pumpBars(tester, high, size: size, tickerEnabled: false);
      final frozen = paintedBars(tester).single.rect;
      await tester.pump(const Duration(milliseconds: 20));
      check(paintedBars(tester).single.rect).equals(frozen);
      check(tester.binding.hasScheduledFrame).isFalse();
      await pumpBars(tester, high, size: size);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      check(tester.binding.hasScheduledFrame).isFalse();
    });
  });
}

typedef PaintedBar = ({RRect rect, Color color});

List<PaintedBar> paintedBars(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(BarsView),
    matching: find.byType(CustomPaint),
  );
  if (finder.evaluate().isEmpty) return [];
  final canvas = _BarCanvas();
  tester
      .widget<CustomPaint>(finder)
      .painter!
      .paint(canvas, tester.getSize(finder));
  return canvas.bars;
}

class _BarCanvas implements Canvas {
  final bars = <PaintedBar>[];

  @override
  void drawRRect(RRect rrect, Paint paint) =>
      bars.add((rect: rrect, color: paint.color));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

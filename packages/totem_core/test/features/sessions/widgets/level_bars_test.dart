import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/utils/frame_paced_ticker.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';

void main() {
  late ValueNotifier<List<double>> levels;

  setUp(() => levels = ValueNotifier(const []));
  tearDown(() => levels.dispose());

  Future<void> pumpBars(
    WidgetTester tester, {
    Color color = Colors.red,
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
            child: LevelBars(levels: levels, color: color),
          ),
        ),
      ),
    ),
  );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  /// Pumps at 120 Hz for [duration], recording the single bar's height after
  /// each pump.
  Future<List<double>> heightsOver(
    WidgetTester tester,
    Duration duration,
  ) async {
    const step = Duration(microseconds: 8333);
    final heights = <double>[];
    for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
      await tester.pump(step);
      heights.add(paintedBars(tester).single.rect.height);
    }
    return heights;
  }

  testWidgets('draws one bar per level and none without levels', (
    tester,
  ) async {
    levels.value = const [0, 0.5, 1];
    await pumpBars(tester);
    check(paintedBars(tester)).length.equals(3);

    levels.value = const [];
    await tester.pump();
    check(paintedBars(tester)).isEmpty();
    await unmount(tester);
  });

  testWidgets('draws nothing in zero space', (tester) async {
    levels.value = const [0.5];
    await pumpBars(tester, size: Size.zero);
    check(paintedBars(tester)).isEmpty();
  });

  testWidgets('tapers full-height edge bars toward the center', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 50,
            height: 100,
            child: LevelBars.fixed(const [1, 1, 1, 1, 1], color: Colors.red),
          ),
        ),
      ),
    );

    check(paintedBars(tester).map((bar) => bar.rect.height)).deepEquals([
      81.5,
      90.75,
      100.0,
      90.75,
      81.5,
    ]);
    check(tester.binding.hasScheduledFrame).isFalse();
  });

  testWidgets(
    'a new sample waits for the paced clock and eases at most 15 times a '
    'second before going idle',
    (tester) async {
      // One 10px cell: a silent bar is a 7.5px dot, a full one fills 50px.
      const size = Size(10, 50);
      levels.value = const [0];
      await pumpBars(tester, size: size);

      levels.value = const [1];
      check(tester.binding.hasScheduledFrame).isFalse();

      // One bar eases over 500 ms.
      final heights = await heightsOver(
        tester,
        const Duration(milliseconds: 700),
      );
      final moves = {...heights}.length;
      check(moves).isLessOrEqual(9);
      check(moves).isGreaterOrEqual(6);
      check(heights.first).equals(7.5);
      check(heights.last).equals(50);
      for (var i = 1; i < heights.length; i++) {
        check(heights[i]).isGreaterOrEqual(heights[i - 1]);
      }
      check(tester.binding.hasScheduledFrame).isFalse();
      await unmount(tester);
    },
  );

  testWidgets('retargets from the shown height without a jump', (
    tester,
  ) async {
    const size = Size(10, 50);
    levels.value = const [0];
    await pumpBars(tester, size: size);
    levels.value = const [1];
    await heightsOver(tester, const Duration(milliseconds: 250));
    final rising = paintedBars(tester).single.rect.height;
    check(rising).isGreaterThan(7.5);
    check(rising).isLessThan(50);

    levels.value = const [0];
    await tester.pump();
    check(paintedBars(tester).single.rect.height).equals(rising);
    final falling = await heightsOver(
      tester,
      const Duration(milliseconds: 700),
    );
    check(falling.first).isLessOrEqual(rising);
    check(falling.last).equals(7.5);
    check(tester.binding.hasScheduledFrame).isFalse();
    await unmount(tester);
  });

  testWidgets('eases a color change', (tester) async {
    const size = Size(10, 50);
    levels.value = const [0.5];
    await pumpBars(tester, size: size);
    await pumpBars(tester, size: size, color: Colors.blue);
    await heightsOver(tester, const Duration(milliseconds: 250));
    final color = paintedBars(tester).single.color.toARGB32();
    check(color).not((it) => it.equals(Colors.red.toARGB32()));
    check(color).not((it) => it.equals(Colors.blue.toARGB32()));

    await heightsOver(tester, const Duration(milliseconds: 400));
    check(
      paintedBars(tester).single.color.toARGB32(),
    ).equals(Colors.blue.toARGB32());
    await unmount(tester);
  });

  testWidgets('keeps easing when the system reduces motion', (tester) async {
    // Jumping bars read as flicker, so they animate regardless.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    const size = Size(10, 50);
    levels.value = const [0];
    await pumpBars(tester, size: size);
    levels.value = const [1];

    final heights = await heightsOver(
      tester,
      const Duration(milliseconds: 250),
    );

    check(heights.last).isGreaterThan(7.5);
    check(heights.last).isLessThan(50);
    await unmount(tester);
  });

  testWidgets('reverses the bar order in right-to-left layouts', (
    tester,
  ) async {
    levels.value = const [0, 1];
    await pumpBars(tester, direction: TextDirection.rtl);

    final bars = paintedBars(tester);
    // The silent first bar sits in the right-hand cell.
    check(bars.map((bar) => bar.rect.center.dx)).deepEquals([68.125, 21.875]);
    check(bars.map((bar) => bar.rect.height)).deepEquals([42.5, 94.25]);
  });

  testWidgets('samples and ticks repaint without rebuilding widgets', (
    tester,
  ) async {
    const size = Size(10, 50);
    levels.value = const [0];
    await pumpBars(tester, size: size);
    final previous = debugOnRebuildDirtyWidget;
    var rebuilds = 0;
    try {
      debugOnRebuildDirtyWidget = (_, _) => rebuilds++;
      levels.value = const [1];
      final heights = await heightsOver(
        tester,
        const Duration(milliseconds: 250),
      );
      check(heights.last).isGreaterThan(7.5);
      check(rebuilds).equals(0);
    } finally {
      debugOnRebuildDirtyWidget = previous;
    }
    await unmount(tester);
  });

  testWidgets('adds and removes bars while resizing mid-transition', (
    tester,
  ) async {
    levels.value = const [0];
    await pumpBars(tester);
    levels.value = const [1, 0.5];
    await tester.pump();
    check(paintedBars(tester)).length.equals(2);
    await tester.pump(FramePacedTicker.interval);

    levels.value = const [1];
    await pumpBars(tester, size: const Size(20, 20));
    await heightsOver(tester, const Duration(milliseconds: 600));

    final bar = paintedBars(tester).single;
    check(bar.rect.height).equals(20);
    check(bar.rect.center).equals(const Offset(10, 10));
    check(tester.binding.hasScheduledFrame).isFalse();
    await unmount(tester);
  });

  testWidgets('pauses offstage and disposes mid-transition', (tester) async {
    const size = Size(10, 50);
    levels.value = const [0];
    await pumpBars(tester, size: size);
    levels.value = const [1];
    await heightsOver(tester, const Duration(milliseconds: 150));
    await pumpBars(tester, size: size, tickerEnabled: false);
    final frozen = paintedBars(tester).single.rect;
    await tester.pump(const Duration(milliseconds: 200));
    check(paintedBars(tester).single.rect).equals(frozen);
    check(tester.binding.hasScheduledFrame).isFalse();

    await pumpBars(tester, size: size);
    await unmount(tester);
    check(tester.binding.hasScheduledFrame).isFalse();
  });
}

typedef PaintedBar = ({RRect rect, Color color});

List<PaintedBar> paintedBars(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(LevelBars),
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

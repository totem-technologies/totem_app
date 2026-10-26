import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/level_bars.dart';

void main() {
  Future<void> pumpBars(
    WidgetTester tester,
    List<double> levels, {
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

  testWidgets('draws one bar per level and none without levels', (
    tester,
  ) async {
    await pumpBars(tester, const [0, 0.5, 1]);
    check(paintedBars(tester)).length.equals(3);

    await pumpBars(tester, const []);
    check(paintedBars(tester)).isEmpty();
    check(tester.binding.hasScheduledFrame).isFalse();
  });

  testWidgets('draws nothing in zero space', (tester) async {
    await pumpBars(tester, const [0.5], size: Size.zero);
    check(paintedBars(tester)).isEmpty();
  });

  testWidgets('tapers full-height edge bars toward the center', (tester) async {
    await pumpBars(
      tester,
      const [1, 1, 1, 1, 1],
      size: const Size(50, 100),
    );

    check(paintedBars(tester).map((bar) => bar.rect.height)).deepEquals([
      81.5,
      90.75,
      100.0,
      90.75,
      81.5,
    ]);
  });

  testWidgets('eases heights and color and retargets without a jump', (
    tester,
  ) async {
    // One 10px cell: a silent bar is a 7.5px dot, a full one fills 50px.
    const size = Size(10, 50);
    await pumpBars(tester, const [0], size: size);
    await pumpBars(tester, const [1], color: Colors.blue, size: size);
    await tester.pump(const Duration(milliseconds: 250));
    final halfway = paintedBars(tester).single;
    check(halfway.rect.height).equals(28.75);
    final expected = Color.lerp(Colors.red, Colors.blue, 0.5)!;
    // Canvas paint stores color channels as floats, so allow rounding.
    check((halfway.color.r - expected.r).abs()).isLessThan(0.000001);
    check((halfway.color.b - expected.b).abs()).isLessThan(0.000001);

    await pumpBars(tester, const [0], size: size);
    check(paintedBars(tester).single.rect).equals(halfway.rect);
    await tester.pump(const Duration(milliseconds: 510));
    check(paintedBars(tester).single.rect.height).equals(7.5);
    check(
      paintedBars(tester).single.color.toARGB32(),
    ).equals(Colors.red.toARGB32());
    check(tester.binding.hasScheduledFrame).isFalse();

    await pumpBars(tester, const [0], size: size);
    check(tester.binding.hasScheduledFrame).isFalse();
  });

  testWidgets('keeps easing when the system reduces motion', (tester) async {
    // Jumping bars read as flicker, so they animate regardless.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    const size = Size(10, 50);
    await pumpBars(tester, const [0], size: size);
    await pumpBars(tester, const [1], size: size);

    await tester.pump(const Duration(milliseconds: 250));

    check(paintedBars(tester).single.rect.height).equals(28.75);
  });

  testWidgets('reverses the bar order in right-to-left layouts', (
    tester,
  ) async {
    await pumpBars(tester, const [0, 1], direction: TextDirection.rtl);

    final bars = paintedBars(tester);
    // The silent first bar sits in the right-hand cell.
    check(bars.map((bar) => bar.rect.center.dx)).deepEquals([68.125, 21.875]);
    check(bars.map((bar) => bar.rect.height)).deepEquals([42.5, 94.25]);
  });

  testWidgets('animation ticks repaint without rebuilding widgets', (
    tester,
  ) async {
    const size = Size(10, 50);
    await pumpBars(tester, const [0], size: size);
    await pumpBars(tester, const [1], size: size);
    final previous = debugOnRebuildDirtyWidget;
    var rebuilds = 0;
    try {
      debugOnRebuildDirtyWidget = (_, _) => rebuilds++;
      await tester.pump(const Duration(milliseconds: 250));
      check(paintedBars(tester).single.rect.height).equals(28.75);
      check(rebuilds).equals(0);
    } finally {
      debugOnRebuildDirtyWidget = previous;
    }
  });

  testWidgets('adds and removes bars while resizing mid-transition', (
    tester,
  ) async {
    await pumpBars(tester, const [0]);
    await pumpBars(tester, const [1, 0.5]);
    check(paintedBars(tester)).length.equals(2);
    await tester.pump(const Duration(milliseconds: 30));

    await pumpBars(tester, const [1], size: const Size(20, 20));
    await tester.pump(const Duration(milliseconds: 510));

    final bar = paintedBars(tester).single;
    check(bar.rect.height).equals(20);
    check(bar.rect.center).equals(const Offset(10, 10));
    check(tester.binding.hasScheduledFrame).isFalse();
  });

  testWidgets('pauses offstage and disposes mid-transition', (tester) async {
    const size = Size(10, 50);
    await pumpBars(tester, const [0], size: size);
    await pumpBars(tester, const [1], size: size);
    await tester.pump(const Duration(milliseconds: 20));
    await pumpBars(tester, const [1], size: size, tickerEnabled: false);
    final frozen = paintedBars(tester).single.rect;
    await tester.pump(const Duration(milliseconds: 20));
    check(paintedBars(tester).single.rect).equals(frozen);
    check(tester.binding.hasScheduledFrame).isFalse();

    await pumpBars(tester, const [1], size: size);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
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

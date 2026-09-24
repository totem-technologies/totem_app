import 'package:checks/checks.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/utils/frame_paced_ticker.dart';

void main() {
  testWidgets(
    'staggered tickers share at most 30 requested frames per second',
    (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final frames = <Duration>{};
      final tickers = <Ticker>[];
      for (var i = 0; i < 6; i++) {
        tickers.add(
          FramePacedTicker(
            (_) => frames.add(tester.binding.currentFrameTimeStamp),
          )..start(),
        );
        await tester.pump(const Duration(milliseconds: 3));
      }
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(microseconds: 8333));
      }
      check(frames.length).isGreaterOrEqual(28);
      check(frames.length).isLessOrEqual(31);
      for (final ticker in tickers) {
        ticker.dispose();
      }
      await tester.pump();
      check(tester.binding.hasScheduledFrame).isFalse();
      check(tester.binding.transientCallbackCount).equals(0);
    },
  );

  testWidgets('mute, resume and disposal cancel deferred work', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    var ticks = 0;
    final ticker = FramePacedTicker((_) => ticks++)
      ..start()
      ..muted = true;
    await tester.pump(const Duration(milliseconds: 100));
    check(ticks).equals(0);
    check(tester.binding.transientCallbackCount).equals(0);
    ticker.muted = false;
    await tester.pump(const Duration(milliseconds: 34));
    check(ticks).equals(1);
    ticker.dispose();
    await tester.pump(const Duration(milliseconds: 100));
    check(ticks).equals(1);
    check(tester.binding.hasScheduledFrame).isFalse();
  });
  testWidgets(
    'moving an implicit animation into a disabled subtree silences it',
    (tester) async {
      final key = GlobalKey();
      var ticks = 0;
      Future<void> pump(bool enabled) => tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              TickerMode(
                enabled: true,
                child: enabled
                    ? _MovingIndicator(key: key, onTick: () => ticks++)
                    : const SizedBox.shrink(),
              ),
              TickerMode(
                enabled: false,
                child: !enabled
                    ? _MovingIndicator(key: key, onTick: () => ticks++)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      await pump(true);
      await tester.pump(const Duration(milliseconds: 40));
      check(ticks).isGreaterThan(0);
      await pump(false);
      final mutedTicks = ticks;
      await tester.pump(const Duration(milliseconds: 100));
      check(ticks).equals(mutedTicks);
      check(tester.binding.hasScheduledFrame).isFalse();
      await pump(true);
      await tester.pump(const Duration(milliseconds: 40));
      check(ticks).isGreaterThan(mutedTicks);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

class _MovingIndicator extends ImplicitlyAnimatedWidget {
  const _MovingIndicator({required this.onTick, super.key})
    : super(duration: const Duration(seconds: 1));

  final VoidCallback onTick;

  @override
  ImplicitlyAnimatedWidgetState<_MovingIndicator> createState() =>
      _MovingIndicatorState();
}

class _MovingIndicatorState
    extends ImplicitlyAnimatedWidgetState<_MovingIndicator>
    with FramePacedTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    controller
      ..addListener(_onTick)
      ..repeat();
  }

  void _onTick() => widget.onTick();

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {}

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/widgets/grounding_marquee.dart';

void main() {
  // Tests run on a phone unless they say otherwise, so every tip rotates.
  final tips = GroundingMarquee.tipsFor(TargetPlatform.iOS);
  const fade = GroundingMarquee.fadeDuration;
  const hold = GroundingMarquee.tipDuration;
  const gap = GroundingMarquee.tipDelay;
  final cycle = fade * 2 + hold + gap;

  void testMarquee(
    String description,
    WidgetTesterCallback body, {
    TargetPlatform platform = TargetPlatform.iOS,
  }) {
    testWidgets(description, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Future<void> pumpMarquee(
    WidgetTester tester, {
    int initialIndex = 0,
    bool disableAnimations = false,
    bool accessibleNavigation = false,
    Size size = const Size(360, 740),
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          disableAnimations: disableAnimations,
          accessibleNavigation: accessibleNavigation,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [GroundingMarquee(initialIndex: initialIndex)],
          ),
        ),
      ),
    );
  }

  Finder tip(int index) => find.bySemanticsLabel('Tip: ${tips[index]}');

  String shownTip() => GroundingMarquee.tips
      .where(
        (text) => find.bySemanticsLabel('Tip: $text').evaluate().isNotEmpty,
      )
      .single;

  double tipOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(GroundingMarquee),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  testMarquee('shows the first tip at once, holds it, then fades in the next', (
    tester,
  ) async {
    await pumpMarquee(tester);
    check(tip(0).evaluate()).length.equals(1);
    check(tipOpacity(tester)).equals(1);

    await tester.pump(hold);
    await tester.pump(fade);
    check(tip(0).evaluate()).length.equals(1);
    check(tipOpacity(tester)).equals(0);

    await tester.pump(gap);
    check(tip(1).evaluate()).length.equals(1);
    check(tipOpacity(tester)).equals(0);

    await tester.pump(fade);
    check(tip(0).evaluate()).isEmpty();
    check(tip(1).evaluate()).length.equals(1);
    check(tipOpacity(tester)).equals(1);
  });

  testMarquee('wraps around from the last tip to the first', (tester) async {
    await pumpMarquee(tester, initialIndex: tips.length - 1);
    check(tip(tips.length - 1).evaluate()).length.equals(1);

    await tester.pump(cycle);

    check(tip(0).evaluate()).length.equals(1);
  });

  for (final (platform, isPhone) in const [
    (TargetPlatform.iOS, true),
    (TargetPlatform.macOS, false),
  ]) {
    testMarquee(
      '${isPhone ? 'includes' : 'leaves out'} the phone battery tip on '
      '${platform.name}',
      (tester) async {
        await pumpMarquee(tester, disableAnimations: true);
        final shown = <String>{};
        for (var i = 0; i < GroundingMarquee.tips.length; i++) {
          shown.add(shownTip());
          await tester.pump(cycle);
        }

        check(shown.any((text) => text.contains('battery'))).equals(isPhone);
        check(shown).deepEquals(
          GroundingMarquee.tips.toSet().difference(
            isPhone ? const <String>{} : GroundingMarquee.phoneOnlyTips,
          ),
        );
      },
      platform: platform,
    );
  }

  testMarquee('holds the current tip while hovered, then resumes rotating', (
    tester,
  ) async {
    await pumpMarquee(tester);
    const away = Offset(5, 735);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: away);
    await mouse.moveTo(tester.getCenter(tip(0)));
    await tester.pump();

    await tester.pump(cycle * 3);
    check(tip(0).evaluate()).length.equals(1);
    check(tipOpacity(tester)).equals(1);

    await mouse.moveTo(away);
    await tester.pump(hold);
    await tester.pump(fade);
    await tester.pump(gap);
    check(tip(1).evaluate()).length.equals(1);
  });

  testMarquee(
    'keeps one tip in place while a screen reader is in use, and rotates '
    'again once it stops',
    (tester) async {
      await pumpMarquee(tester, accessibleNavigation: true);

      await tester.pump(cycle * 3);
      check(tip(0).evaluate()).length.equals(1);
      check(tipOpacity(tester)).equals(1);

      await pumpMarquee(tester);
      await tester.pump(hold);
      await tester.pump(fade);
      await tester.pump(gap);
      check(tip(1).evaluate()).length.equals(1);
    },
  );

  for (final (phase, pumps) in <(String, List<Duration>)>[
    ('holding a tip', [hold ~/ 2]),
    ('between tips', [hold, fade + gap ~/ 2]),
  ]) {
    testMarquee('unmounting while $phase cancels its pending timer', (
      tester,
    ) async {
      await pumpMarquee(tester);
      for (final duration in pumps) {
        await tester.pump(duration);
      }

      // Ending the test right after unmounting lets the framework's
      // pending-timer check fail on a timer that outlives the marquee.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testMarquee('reduced motion swaps tips in place without fading', (
    tester,
  ) async {
    await pumpMarquee(tester, disableAnimations: true);
    check(tip(0).evaluate()).length.equals(1);
    check(tipOpacity(tester)).equals(1);

    await tester.pump(cycle - const Duration(milliseconds: 1));
    check(tip(0).evaluate()).length.equals(1);
    check(tipOpacity(tester)).equals(1);

    await tester.pump(const Duration(milliseconds: 1));
    check(tip(1).evaluate()).length.equals(1);
    check(tipOpacity(tester)).equals(1);
  });

  testMarquee(
    'keeps its size when rotating to a shorter tip on a small phone at 2x text',
    (tester) async {
      // Tip 4 wraps to more lines than tip 5 at this width and scale.
      await pumpMarquee(
        tester,
        initialIndex: 4,
        size: const Size(320, 568),
        textScale: 2,
      );
      check(tester.takeException()).isNull();
      final before = tester.getSize(find.byType(GroundingMarquee));

      await tester.pump(cycle);
      await tester.pump(fade);

      check(tip(5).evaluate()).length.equals(1);
      check(tester.getSize(find.byType(GroundingMarquee))).equals(before);
      check(tester.takeException()).isNull();
    },
  );
}

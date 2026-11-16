import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';

void main() {
  void cardTest(
    String description,
    AsyncValueSetter<WidgetTester> body, {
    TestVariant<Object?> variant = const DefaultTestVariant(),
  }) {
    testWidgets(
      description,
      (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
      variant: variant,
      // AutoSizeText's third-party TextPainter exclusion already existed here.
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );
  }

  Future<void> pumpCard(
    WidgetTester tester,
    Widget card, {
    Size size = const Size(360, 740),
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: card)),
      ),
    );
  }

  Future<void> swipeAction(WidgetTester tester) async {
    final action = find.byKey(ActionSlider.thumbKey);
    await tester.drag(action, const Offset(600, 0));
    await tester.pump();
  }

  void checkFits(WidgetTester tester, Finder finder, Size screen) {
    final rect = tester.getRect(finder);
    check(rect.left).isGreaterOrEqual(0);
    check(rect.top).isGreaterOrEqual(0);
    check(rect.right).isLessOrEqual(screen.width);
    check(rect.bottom).isLessOrEqual(screen.height);
  }

  const phones = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });
  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  cardTest('touch actions join, pass, receive, and start exactly once', (
    tester,
  ) async {
    final cards = <Widget Function(AsyncValueGetter<bool>)>[
      (action) => JoinTransitionCard(onActionPressed: action),
      (action) => PassTransitionCard(onActionPressed: action),
      (action) => ReceiveTransitionCard(onActionPressed: action),
      (action) => StartTransitionCard(onActionPressed: action),
    ];
    for (final card in cards) {
      var actions = 0;
      await pumpCard(
        tester,
        card(() async {
          actions++;
          return true;
        }),
      );
      await swipeAction(tester);
      check(actions).equals(1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  }, variant: phones);

  cardTest('desktop receive is clickable on wide and narrow viewports', (
    tester,
  ) async {
    for (final size in [const Size(1280, 900), const Size(500, 800)]) {
      var received = 0;
      await pumpCard(
        tester,
        ReceiveTransitionCard(
          onActionPressed: () async {
            received++;
            return true;
          },
        ),
        size: size,
      );
      await tester.tap(find.text('Receive'));
      await tester.pump();
      check(received).equals(1);
      check(tester.takeException()).isNull();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  }, variant: desktop);

  cardTest('disabled joining rejects input; waiting offers cancellation', (
    tester,
  ) async {
    var joined = 0;
    var cancelled = 0;
    Future<bool> join() async {
      joined++;
      return true;
    }

    await pumpCard(
      tester,
      JoinTransitionCard(onActionPressed: join, enabled: false),
      size: const Size(1280, 900),
    );
    await tester.tap(find.text('Join'));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    check(joined).equals(0);
    await pumpCard(
      tester,
      JoinTransitionCard(
        onActionPressed: join,
        waiting: true,
        onLeaveWaiting: () => cancelled++,
      ),
      size: const Size(1280, 900),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    check(joined).equals(0);
    await tester.tap(find.text('Leave waiting room'));
    await tester.pump();
    check(cancelled).equals(1);
  }, variant: desktop);

  for (final scenario in [
    (
      name: 'portrait receive',
      size: const Size(360, 740),
      receive: true,
      scale: 1.0,
      sideColumn: false,
      width: null,
    ),
    (
      name: 'large text portrait pass',
      size: const Size(360, 740),
      receive: false,
      scale: 1.5,
      sideColumn: false,
      width: null,
    ),
    (
      name: 'small landscape side column',
      size: const Size(667, 375),
      receive: false,
      scale: 1.0,
      sideColumn: true,
      width: null,
    ),
    (
      name: 'wide landscape pass',
      size: const Size(844, 390),
      receive: false,
      scale: 1.0,
      sideColumn: false,
      width: 560.0,
    ),
    (
      name: 'constrained medium pass',
      size: const Size(640, 900),
      receive: false,
      scale: 1.0,
      sideColumn: false,
      width: 481.0,
    ),
  ]) {
    cardTest('${scenario.name} keeps instruction and action usable', (
      tester,
    ) async {
      var performed = 0;
      Future<bool> perform() async {
        performed++;
        return true;
      }

      Widget card = scenario.receive
          ? ReceiveTransitionCard(onActionPressed: perform)
          : PassTransitionCard(onActionPressed: perform);
      if (scenario.sideColumn) {
        card = Row(
          spacing: 16,
          children: [
            const Expanded(child: SizedBox()),
            Flexible(
              child: Column(mainAxisSize: MainAxisSize.min, children: [card]),
            ),
          ],
        );
      } else if (scenario.width case final width?) {
        card = SizedBox(width: width, child: card);
      }
      await pumpCard(
        tester,
        card,
        size: scenario.size,
        textScale: scenario.scale,
      );
      final instruction = find.text(
        scenario.receive
            ? 'The Totem is being passed to you.'
            : 'When done, slide to pass the Totem to the next person.',
      );
      final action = find.byType(ActionSlider);
      checkFits(tester, instruction, scenario.size);
      checkFits(tester, action, scenario.size);
      check(
        tester.getRect(instruction).overlaps(tester.getRect(action)),
      ).isFalse();
      await swipeAction(tester);
      check(performed).equals(1);
      check(tester.takeException()).isNull();
    }, variant: phones);
  }

  cardTest('touch instructions do not advertise a hardware keyboard', (
    tester,
  ) async {
    await pumpCard(
      tester,
      PassTransitionCard(onActionPressed: () async => true),
    );
    check(find.textContaining('press space bar').evaluate()).isEmpty();
  }, variant: phones);

  cardTest('waiting for the receiver exposes no turn action', (tester) async {
    await pumpCard(tester, const WaitingReceiveTransitionCard());
    check(
      find
          .bySemanticsLabel(RegExp(r'^(Receive|Pass|Join|Start session)$'))
          .evaluate(),
    ).isEmpty();
    check(tester.takeException()).isNull();
  }, variant: desktop);

  for (final scenario in [
    (
      name: 'edited',
      initial: null,
      entered: 'My next prompt',
      expected: 'My next prompt',
      clear: false,
    ),
    (
      name: 'unchanged prepared',
      initial: 'Prepared prompt',
      entered: null,
      expected: null,
      clear: false,
    ),
    (
      name: 'removed',
      initial: 'Prepared prompt',
      entered: '',
      expected: null,
      clear: true,
    ),
  ]) {
    cardTest('${scenario.name} prompt submission preserves its intent', (
      tester,
    ) async {
      final submissions =
          <({String? customPrompt, int? sessionPromptId, bool clearPrompt})>[];
      var managed = 0;
      await pumpCard(
        tester,
        PromptTransitionCard(
          initialPrompt: scenario.initial,
          initialSessionPromptId: scenario.initial == null ? null : 42,
          onManagePrompts: () => managed++,
          onActionPressed:
              ({customPrompt, sessionPromptId, clearPrompt = false}) async {
                submissions.add((
                  customPrompt: customPrompt,
                  sessionPromptId: sessionPromptId,
                  clearPrompt: clearPrompt,
                ));
                return true;
              },
        ),
      );
      final field = find.byType(TextField);
      final action = find.byType(ActionSlider);
      checkFits(tester, field, const Size(360, 740));
      checkFits(tester, action, const Size(360, 740));
      check(tester.getRect(field).overlaps(tester.getRect(action))).isFalse();
      if (scenario.entered case final entered?) {
        await tester.enterText(field, entered);
      }
      await tester.tap(find.byTooltip('Manage discussion prompts'));
      await tester.pump();
      check(managed).equals(1);
      await swipeAction(tester);
      check(submissions).deepEquals([
        (
          customPrompt: scenario.expected,
          sessionPromptId: null,
          clearPrompt: scenario.clear,
        ),
      ]);
      check(tester.takeException()).isNull();
    }, variant: phones);
  }
}

import 'dart:ui' show PointerDeviceKind;

import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required Widget child,
    Size size = const Size(390, 844),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    );
  }

  testWidgets('only enabled accessible actions respond to taps', (
    tester,
  ) async {
    var taps = 0;
    await pumpBar(
      tester,
      child: ActionBar(
        children: [
          ActionBarButton(
            semanticsLabel: 'Send message',
            onPressed: () => taps++,
            child: const Icon(Icons.message),
          ),
          const ActionBarButton(
            semanticsLabel: 'Unavailable action',
            onPressed: null,
            child: Icon(Icons.message),
          ),
        ],
      ),
    );
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.tap(find.bySemanticsLabel('Unavailable action'));
    await tester.pump();
    check(taps).equals(1);
  });

  for (final scenario in [
    (name: 'phone', size: const Size(390, 844), constrained: false, row: false),
    (
      name: 'unbounded row',
      size: const Size(390, 844),
      constrained: false,
      row: true,
    ),
    (
      name: 'constrained phone',
      size: const Size(390, 844),
      constrained: true,
      row: false,
    ),
    (
      name: 'wide tablet',
      size: const Size(1200, 900),
      constrained: false,
      row: false,
    ),
  ]) {
    testWidgets('all actions fit and remain reachable in ${scenario.name}', (
      tester,
    ) async {
      final activated = <int>[];
      Widget bar = ActionBar(
        children: [
          for (var i = 0; i < 5; i++)
            ActionBarButton(
              semanticsLabel: 'Action $i',
              onPressed: () => activated.add(i),
              child: Text('$i'),
            ),
        ],
      );
      if (scenario.constrained) {
        bar = SizedBox(width: 250, child: bar);
      } else if (scenario.row) {
        bar = Row(
          children: [
            const Expanded(child: Text('Next up')),
            bar,
            const Spacer(),
          ],
        );
      }
      await pumpBar(tester, size: scenario.size, child: bar);
      Rect? previous;
      for (var i = 0; i < 5; i++) {
        final action = find.bySemanticsLabel('Action $i');
        final rect = tester.getRect(action);
        check(rect.left).isGreaterOrEqual(0);
        check(rect.right).isLessOrEqual(scenario.size.width);
        check(rect.top).isGreaterOrEqual(0);
        check(rect.bottom).isLessOrEqual(scenario.size.height);
        if (previous != null) check(previous.overlaps(rect)).isFalse();
        previous = rect;
        await tester.tap(action);
      }
      await tester.pump();
      check(activated).deepEquals([0, 1, 2, 3, 4]);
      check(tester.takeException()).isNull();
    });
  }

  testWidgets('shortcut help is discoverable only on desktop web', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpBar(
        tester,
        child: const ActionBarShortcutTooltip(
          shortcut: ActionBarShortcut.microphone,
          child: SizedBox(width: 48, height: 48, child: Text('Microphone')),
        ),
      );
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(
        location: tester.getCenter(find.text('Microphone')),
      );
      await tester.pump(const Duration(seconds: 1));
      check(
        find.text('Toggle microphone (M)').evaluate(),
      ).length.equals(kIsWeb && platform == TargetPlatform.windows ? 1 : 0);
      await pointer.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

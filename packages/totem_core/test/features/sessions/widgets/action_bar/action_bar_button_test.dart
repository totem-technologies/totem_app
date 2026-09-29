import 'package:checks/checks.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';

void main() {
  Future<void> pumpWidget(
    WidgetTester tester, {
    required Widget child,
    Size? surfaceSize,
    Color? textColor,
  }) async {
    if (surfaceSize != null) {
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DefaultTextStyle.merge(
            style: TextStyle(color: textColor),
            // Align is load-bearing: production pins the bar to the bottom
            // and keeps it from stretching to fill the scaffold.
            child: Align(alignment: Alignment.bottomCenter, child: child),
          ),
        ),
      ),
    );
  }

  double buttonWidthOf(WidgetTester tester) {
    return tester.getSize(find.byType(ActionBarButton).first).width;
  }

  List<Widget> ghostButtons(int count) {
    return [
      for (var i = 0; i < count; i++)
        ActionBarButton(onPressed: () {}, child: Text('$i')),
    ];
  }

  group('ActionBarShortcutTooltip', () {
    testWidgets('shows the shortcut only on a desktop web target', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpWidget(
          tester,
          child: const ActionBarShortcutTooltip(
            shortcut: ActionBarShortcut.microphone,
            child: Icon(Icons.mic),
          ),
        );

        check(
          tester.widgetList(find.byType(Tooltip)),
        ).length.equals(kIsWeb ? 1 : 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('does not show the shortcut on a mobile web target', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpWidget(
          tester,
          child: const ActionBarShortcutTooltip(
            shortcut: ActionBarShortcut.microphone,
            child: Icon(Icons.mic),
          ),
        );

        check(tester.widgetList(find.byType(Tooltip))).isEmpty();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('ActionBarButton', () {
    testWidgets('invokes callback on tap', (tester) async {
      var taps = 0;

      await pumpWidget(
        tester,
        child: ActionBarButton(
          onPressed: () => taps++,
          child: const Icon(Icons.message),
        ),
      );

      await tester.tap(find.byType(ActionBarButton));
      await tester.pump();

      check(taps).equals(1);
    });
  });

  group('ActionBar', () {
    testWidgets('uses compact metrics on a phone-width surface', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        surfaceSize: const Size(390, 844),
        child: ActionBar(children: ghostButtons(5)),
      );

      check(buttonWidthOf(tester)).equals(40);
    });

    testWidgets('uses compact metrics when nested in an unbounded Row', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        surfaceSize: const Size(390, 844),
        child: Row(
          children: [
            const Expanded(child: Text('next up')),
            ActionBar(children: ghostButtons(5)),
            const Spacer(),
          ],
        ),
      );

      check(buttonWidthOf(tester)).equals(40);
    });

    testWidgets('uses comfortable metrics on a wide tablet surface', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        surfaceSize: const Size(1200, 900),
        child: ActionBar(children: ghostButtons(2)),
      );

      check(buttonWidthOf(tester)).equals(44);
    });
  });
}

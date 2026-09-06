import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
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
            child: Align(
              alignment: Alignment.bottomCenter,
              child: child,
            ),
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
        ActionBarButton(
          onPressed: () {},
          child: Text('$i'),
        ),
    ];
  }

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

      expect(taps, 1);
    });

    testWidgets('is disabled when callback is null', (tester) async {
      await pumpWidget(
        tester,
        child: const ActionBarButton(
          onPressed: null,
          semanticsLabel: 'Disabled action',
          child: Icon(Icons.message),
        ),
      );

      final gesture = tester.widget<GestureDetector>(
        find.descendant(
          of: find.byType(ActionBarButton),
          matching: find.byType(GestureDetector),
        ),
      );
      expect(gesture.onTap, isNull);
    });
  });

  group('ActionBar', () {
    testWidgets('renders all provided children', (tester) async {
      await pumpWidget(
        tester,
        child: const ActionBar(
          children: [
            Text('One'),
            Text('Two'),
            Text('Three'),
          ],
        ),
      );

      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('Three'), findsOneWidget);
    });

    testWidgets('uses compact metrics on a phone-width surface', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        surfaceSize: const Size(390, 844),
        child: ActionBar(children: ghostButtons(5)),
      );

      expect(buttonWidthOf(tester), 48);
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

      expect(buttonWidthOf(tester), 48);
    });

    testWidgets('uses comfortable metrics on a wide tablet surface', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        surfaceSize: const Size(1200, 900),
        child: ActionBar(children: ghostButtons(2)),
      );

      expect(buttonWidthOf(tester), 78);
    });
  });

  group('ActionBarButton chrome', () {
    BoxDecoration decorationOf(WidgetTester tester) {
      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(ActionBarButton),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return container.decoration! as BoxDecoration;
    }

    testWidgets('ghost stays transparent', (tester) async {
      await pumpWidget(
        tester,
        child: const ActionBarButton(
          role: ActionBarButtonRole.ghost,
          onPressed: null,
          child: Icon(Icons.message),
        ),
      );

      final decoration = decorationOf(tester);
      expect(decoration.color, AppTheme.transparent);
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('muted uses pinkTint fill', (tester) async {
      await pumpWidget(
        tester,
        child: const ActionBarButton(
          role: ActionBarButtonRole.muted,
          onPressed: null,
          child: Icon(Icons.videocam_off),
        ),
      );

      expect(decorationOf(tester).color, AppTheme.pinkTint);
    });

    testWidgets('emphasized uses cream fill', (tester) async {
      await pumpWidget(
        tester,
        child: const ActionBarButton(
          role: ActionBarButtonRole.emphasized,
          onPressed: null,
          child: Icon(Icons.sentiment_satisfied_alt),
        ),
      );

      expect(decorationOf(tester).color, AppTheme.cream);
    });

    testWidgets('disabled ghost is faded', (tester) async {
      await pumpWidget(
        tester,
        child: const ActionBarButton(
          role: ActionBarButtonRole.ghost,
          onPressed: null,
          child: Icon(Icons.message),
        ),
      );

      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(ActionBarButton),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.opacity, 0.4);
    });

    testWidgets('ghost idle wash appears on hover', (tester) async {
      await pumpWidget(
        tester,
        textColor: Colors.white,
        child: ActionBar(
          children: [
            ActionBarButton(
              role: ActionBarButtonRole.ghost,
              onPressed: () {},
              child: const Icon(Icons.message),
            ),
          ],
        ),
      );

      expect(decorationOf(tester).color, AppTheme.transparent);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(ActionBarButton)));
      await tester.pumpAndSettle();

      expect(
        decorationOf(tester).color,
        AppTheme.white.withValues(alpha: 0.16),
      );
    });

    testWidgets('ghost foreground is slate on a light surrounding', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        textColor: Colors.black,
        child: ActionBar(
          children: [
            ActionBarButton(
              role: ActionBarButtonRole.ghost,
              onPressed: () {},
              child: const Icon(Icons.message),
            ),
          ],
        ),
      );

      final iconTheme = tester.widget<IconTheme>(
        find.descendant(
          of: find.byType(ActionBarButton),
          matching: find.byType(IconTheme),
        ),
      );
      expect(iconTheme.data.color, AppTheme.slate);
    });
  });
}

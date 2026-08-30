import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';

void main() {
  Future<void> pumpWidget(
    WidgetTester tester, {
    required Widget child,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: child),
      ),
    );
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
  });
}

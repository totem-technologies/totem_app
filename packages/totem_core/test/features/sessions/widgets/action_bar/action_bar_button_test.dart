import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

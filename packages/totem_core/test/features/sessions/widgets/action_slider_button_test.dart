import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';

void main() {
  Future<void> pumpTestWidget(
    WidgetTester tester, {
    required Widget child,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('ActionButton', () {
    testWidgets('invokes callback and shows loading while pending', (
      tester,
    ) async {
      var calls = 0;
      final completer = Completer<bool>();

      await pumpTestWidget(
        tester,
        child: ActionButton(
          text: 'Continue',
          onActionCompleted: () {
            calls++;
            return completer.future;
          },
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(false);
      await tester.pump();
      await tester.pump();

      expect(find.text('Continue'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('keeps loading on successful completion when configured', (
      tester,
    ) async {
      await pumpTestWidget(
        tester,
        child: ActionButton(
          text: 'Start',
          keepLoadingOnSuccess: true,
          onActionCompleted: () async => true,
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('respects external loading state and blocks presses', (
      tester,
    ) async {
      var calls = 0;

      await pumpTestWidget(
        tester,
        child: ActionButton(
          text: 'Receive',
          isLoading: true,
          onActionCompleted: () async {
            calls++;
            return true;
          },
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(calls, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ActionSlider', () {
    testWidgets('does not complete action on short drag', (tester) async {
      var calls = 0;

      await pumpTestWidget(
        tester,
        child: ActionSlider(
          text: 'Slide',
          onActionCompleted: () async {
            calls++;
            return true;
          },
        ),
      );

      await tester.drag(find.byType(ActionSlider), const Offset(30, 0));
      await tester.pump();

      expect(calls, 0);
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
    });

    testWidgets(
      'completes action on long drag and shows loading while pending',
      (
        tester,
      ) async {
        var calls = 0;
        final completer = Completer<bool>();

        await pumpTestWidget(
          tester,
          child: ActionSlider(
            text: 'Slide',
            onActionCompleted: () {
              calls++;
              return completer.future;
            },
          ),
        );

        await tester.drag(find.byType(ActionSlider), const Offset(500, 0));
        await tester.pump();

        expect(calls, 1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        completer.complete(false);
        await tester.pump();
        await tester.pump();

        expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      },
    );

    testWidgets('reflects external loading state', (tester) async {
      await pumpTestWidget(
        tester,
        child: ActionSlider(
          text: 'Slide',
          isLoading: true,
          onActionCompleted: () async => true,
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ActionSliderButton', () {
    testWidgets('switches between slider and button on mouse plug in-out', (
      tester,
    ) async {
      TestGesture? mouseGesture;

      Future<void> connectMouse() async {
        mouseGesture ??= await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await mouseGesture!.addPointer(location: const Offset(10, 10));
        await tester.pump();
      }

      Future<void> disconnectMouse() async {
        if (mouseGesture == null) return;
        await mouseGesture!.removePointer();
        mouseGesture = null;
        await tester.pump();
      }

      addTearDown(() async {
        if (mouseGesture != null) {
          await mouseGesture!.removePointer();
        }
      });

      await disconnectMouse();

      await pumpTestWidget(
        tester,
        child: ActionSliderButton(
          text: 'Continue',
          onActionCompleted: () async => true,
        ),
      );

      expect(find.byType(ActionSlider), findsOneWidget);
      expect(find.byType(ActionButton), findsNothing);

      await connectMouse();

      expect(find.byType(ActionButton), findsOneWidget);
      expect(find.byType(ActionSlider), findsNothing);

      await disconnectMouse();

      expect(find.byType(ActionSlider), findsOneWidget);
      expect(find.byType(ActionButton), findsNothing);
    });
  });
}

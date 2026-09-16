import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';

void main() {
  void autoSizeTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(
      description,
      body,
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );
  }

  Future<void> pumpTestWidget(
    WidgetTester tester, {
    required Widget child,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 320, child: child)),
        ),
      ),
    );
  }

  group('ActionButton', () {
    autoSizeTest('invokes callback and shows loading while pending', (
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

      check(calls).equals(1);
      check(
        tester.widgetList(find.byType(CircularProgressIndicator)),
      ).length.equals(1);

      completer.complete(false);
      await tester.pump();
      await tester.pump();

      check(tester.widgetList(find.text('Continue'))).length.equals(1);
      check(
        tester.widgetList(find.byType(CircularProgressIndicator)),
      ).length.equals(0);
    });

    autoSizeTest('keeps loading on successful completion when configured', (
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

      check(
        tester.widgetList(find.byType(CircularProgressIndicator)),
      ).length.equals(1);
      check(tester.widgetList(find.text('Start'))).length.equals(0);
    });

    autoSizeTest('respects external loading state and blocks presses', (
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

      check(calls).equals(0);
      check(
        tester.widgetList(find.byType(CircularProgressIndicator)),
      ).length.equals(1);
    });
  });

  group('ActionSlider', () {
    autoSizeTest('does not complete action on short drag', (tester) async {
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

      check(calls).equals(0);
      check(
        tester.widgetList(find.byIcon(Icons.arrow_forward_ios)),
      ).length.equals(1);
    });

    autoSizeTest(
      'completes action on long drag and shows loading while pending',
      (tester) async {
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

        check(calls).equals(1);
        check(
          tester.widgetList(find.byType(CircularProgressIndicator)),
        ).length.equals(1);

        completer.complete(false);
        await tester.pump();
        await tester.pump();

        check(
          tester.widgetList(find.byIcon(Icons.arrow_forward_ios)),
        ).length.equals(1);
      },
    );

    autoSizeTest('reflects external loading state', (tester) async {
      await pumpTestWidget(
        tester,
        child: ActionSlider(
          text: 'Slide',
          isLoading: true,
          onActionCompleted: () async => true,
        ),
      );

      await tester.pump();

      check(
        tester.widgetList(find.byType(CircularProgressIndicator)),
      ).length.equals(1);
    });
  });

  group('ActionSliderButton', () {
    autoSizeTest('renders ActionButton on desktop platforms', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpTestWidget(
          tester,
          child: ActionSliderButton(
            text: 'Continue',
            onActionCompleted: () async => true,
          ),
        );

        check(tester.widgetList(find.byType(ActionButton))).length.equals(1);
        check(tester.widgetList(find.byType(ActionSlider))).length.equals(0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    autoSizeTest('renders ActionSlider on mobile platforms', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await pumpTestWidget(
          tester,
          child: ActionSliderButton(
            text: 'Continue',
            onActionCompleted: () async => true,
          ),
        );

        check(tester.widgetList(find.byType(ActionSlider))).length.equals(1);
        check(tester.widgetList(find.byType(ActionButton))).length.equals(0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

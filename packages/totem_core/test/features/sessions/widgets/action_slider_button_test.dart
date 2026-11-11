import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/shared/totem_icons.dart';

void main() {
  void autoSizeTest(String description, AsyncValueSetter<WidgetTester> body) {
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
    double width = 320,
    TextScaler? textScaler,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: Scaffold(
              body: Center(
                child: SizedBox(width: width, child: child),
              ),
            ),
          ),
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

      await tester.tap(find.byType(InkWell));
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

      await tester.tap(find.byType(InkWell));
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

      await tester.tap(find.byType(InkWell));
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
      check(tester.widgetList(find.byType(TotemIcon))).length.equals(1);
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

        check(tester.widgetList(find.byType(TotemIcon))).length.equals(1);
      },
    );

    for (final (label, height) in [
      ('desktop 44dp track', 44.0),
      ('phone 48dp track', 48.0),
      ('default 50dp track', null),
    ]) {
      autoSizeTest('keeps the thumb round for a $label', (tester) async {
        await pumpTestWidget(
          tester,
          child: height == null
              ? ActionSlider(text: 'Slide', onActionCompleted: () async => true)
              : ActionSlider(
                  text: 'Slide',
                  onActionCompleted: () async => true,
                  height: height,
                ),
        );

        final track = tester.getSize(find.byType(ActionSlider));
        final thumb = tester.getSize(find.byKey(ActionSlider.thumbKey));
        check(track.height).equals(height ?? 50);
        check(thumb.width).equals(thumb.height);
        check(thumb.height).equals(track.height - 8);
      });
    }

    autoSizeTest('completes on a swipe across a phone 48dp track', (
      tester,
    ) async {
      var calls = 0;
      await pumpTestWidget(
        tester,
        child: ActionSlider(
          text: 'Receive',
          height: 48,
          onActionCompleted: () async {
            calls++;
            return true;
          },
        ),
      );

      await tester.drag(
        find.byKey(ActionSlider.thumbKey),
        const Offset(320, 0),
      );
      await tester.pump();

      check(calls).equals(1);
    });

    autoSizeTest('keeps the app button label unless a label style is given', (
      tester,
    ) async {
      final theme = AppTheme.lightTheme;
      const override = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
      // Join and other sliders keep the ElevatedButton label; only the
      // docked transition cards pass a smaller one.
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ActionSlider(
                      text: 'Default',
                      onActionCompleted: () async => true,
                    ),
                    ActionSlider(
                      text: 'Override',
                      labelStyle: override,
                      onActionCompleted: () async => true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      TextStyle? labelOf(String text) => tester
          .widget<AutoSizeText>(find.widgetWithText(AutoSizeText, text))
          .style;

      final buttonLabel = theme.elevatedButtonTheme.style?.textStyle?.resolve(
        {},
      );
      check(labelOf('Default')?.fontSize).equals(buttonLabel?.fontSize);
      check(labelOf('Default')?.fontWeight).equals(buttonLabel?.fontWeight);
      check(labelOf('Override')?.fontSize).equals(14);
      check(labelOf('Override')?.fontWeight).equals(FontWeight.w500);
      check(labelOf('Override')?.color).equals(AppTheme.white);
    });

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

  autoSizeTest('keeps Join usable with touch and desktop interactions', (
    tester,
  ) async {
    try {
      for (final scenario in [
        (
          platform: TargetPlatform.iOS,
          viewport: const Size(320, 640),
          width: 320.0,
          textScaler: const TextScaler.linear(2),
          control: find.byType(ActionSlider),
          interact: (WidgetTester tester) =>
              tester.drag(find.byType(ActionSlider), const Offset(500, 0)),
        ),
        (
          platform: TargetPlatform.macOS,
          viewport: const Size(1200, 900),
          width: 900.0,
          textScaler: null,
          control: find.byType(ActionButton),
          interact: (WidgetTester tester) => tester.tap(find.byType(InkWell)),
        ),
      ]) {
        var calls = 0;
        tester.view.physicalSize = scenario.viewport;
        tester.view.devicePixelRatio = 1;
        debugDefaultTargetPlatformOverride = scenario.platform;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpTestWidget(
          tester,
          width: scenario.width,
          textScaler: scenario.textScaler,
          child: ActionSliderButton(
            text: 'Join',
            onActionCompleted: () async {
              calls++;
              return true;
            },
          ),
        );

        check(tester.widgetList(find.text('Join'))).length.equals(1);
        check(tester.widgetList(scenario.control)).length.equals(1);

        await scenario.interact(tester);
        await tester.pump();

        check(calls).equals(1);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('selects the appropriate action control for the platform', (
    tester,
  ) async {
    for (final scenario in [
      (platform: TargetPlatform.macOS, desktop: true),
      (platform: TargetPlatform.iOS, desktop: false),
    ]) {
      debugDefaultTargetPlatformOverride = scenario.platform;
      try {
        await pumpTestWidget(
          tester,
          child: ActionSliderButton(
            text: 'Continue',
            onActionCompleted: () async => true,
          ),
        );

        check(
          tester.widgetList(
            scenario.desktop
                ? find.byType(ActionButton)
                : find.byType(ActionSlider),
          ),
        ).length.equals(1);
        check(
          tester.widgetList(
            scenario.desktop
                ? find.byType(ActionSlider)
                : find.byType(ActionButton),
          ),
        ).length.equals(0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }
  });
}

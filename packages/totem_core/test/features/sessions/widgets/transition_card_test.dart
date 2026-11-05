import 'package:auto_size_text/auto_size_text.dart';
import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/features/sessions/widgets/session_dock_surface.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';

void main() {
  void autoSizeTest(
    String description,
    AsyncValueSetter<WidgetTester> body, {
    TestVariant<Object?> variant = const DefaultTestVariant(),
  }) {
    testWidgets(
      description,
      body,
      variant: variant,
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );
  }

  group('Transition Cards', () {
    Widget buildTestWidget(Widget child, {ThemeData? theme}) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(body: Center(child: child)),
      );
    }

    autoSizeTest('actionable transition cards forward completion', (
      tester,
    ) async {
      final cards = <Widget Function(AsyncValueGetter<bool>)>[
        (onActionPressed) =>
            JoinTransitionCard(onActionPressed: onActionPressed),
        (onActionPressed) => PassTransitionCard(
          onActionPressed: onActionPressed,
          actionText: 'Pass',
        ),
        (onActionPressed) =>
            ReceiveTransitionCard(onActionPressed: onActionPressed),
        (onActionPressed) =>
            StartTransitionCard(onActionPressed: onActionPressed),
      ];

      for (final buildCard in cards) {
        var actionTriggered = false;
        await tester.pumpWidget(
          buildTestWidget(
            buildCard(() async {
              actionTriggered = true;
              return true;
            }),
          ),
        );

        check(
          tester.widgetList(find.byType(ActionSliderButton)),
        ).length.equals(1);
        await tester
            .widget<ActionSliderButton>(find.byType(ActionSliderButton))
            .onActionCompleted();
        check(actionTriggered).isTrue();
      }
    });

    Future<void> pumpAtSize(
      WidgetTester tester,
      Size size,
      Widget child, {
      ThemeData? theme,
      double textScale = 1,
    }) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(buildTestWidget(child, theme: theme));
    }

    group('with a keyboard on desktop', () {
      final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

      autoSizeTest(
        'large viewport keeps the space shortcut caption under the receive control',
        (tester) async {
          var received = false;
          await pumpAtSize(
            tester,
            const Size(1280, 900),
            ReceiveTransitionCard(
              onActionPressed: () async {
                received = true;
                return true;
              },
            ),
          );

          check(
            find.text('press space bar to receive').evaluate(),
          ).isNotEmpty();
          check(find.text('Space').evaluate()).isEmpty();
          check(tester.getSize(find.byType(ActionButton)).height).equals(44);

          await tester.tap(find.text('Receive'));
          await tester.pump();
          check(received).isTrue();
        },
        variant: desktop,
      );

      autoSizeTest(
        'small viewport keeps the space shortcut caption under the pill',
        (tester) async {
          await pumpAtSize(
            tester,
            const Size(500, 800),
            ReceiveTransitionCard(onActionPressed: () async => true),
          );

          check(
            find.text('press space bar to receive').evaluate(),
          ).isNotEmpty();
        },
        variant: desktop,
      );
    });

    group('on touch phones', () {
      const phones = TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      });
      const portrait = Size(360, 740);
      const landscape = Size(844, 390);
      const passInstruction =
          'When done, slide to pass the Totem to the next person.';

      /// The glass pill shared with the action bar.
      Finder dockSurface() {
        final glass = sessionDockDecoration(onLightBackground: false);
        // Radius differs between the row and stacked layouts, so match the
        // shared fill and stroke only.
        return find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.color == glass.color &&
              decoration.border == glass.border;
        });
      }

      void checkFitsScreen(WidgetTester tester, Finder finder, Size screen) {
        final rect = tester.getRect(finder);
        check(rect.left).isGreaterOrEqual(0);
        check(rect.top).isGreaterOrEqual(0);
        check(rect.right).isLessOrEqual(screen.width);
        check(rect.bottom).isLessOrEqual(screen.height);
      }

      void checkStacked(WidgetTester tester, String instruction) {
        final text = tester.getRect(find.text(instruction));
        final slider = tester.getRect(find.byType(ActionSlider));
        check(slider.height).equals(48);
        check(text.bottom).isLessOrEqual(slider.top);
      }

      void checkInline(WidgetTester tester, String instruction) {
        final text = tester.getRect(find.text(instruction));
        final slider = tester.getRect(find.byType(ActionSlider));
        check(text.right).isLessOrEqual(slider.left);
        check((text.center.dy - slider.center.dy).abs()).isLessOrEqual(1);
      }

      /// The speaking screen's landscape layout: the grid takes one half,
      /// the pill column the other.
      Widget landscapeSideColumn(Widget card) => Row(
        spacing: 16,
        children: [
          const Expanded(child: SizedBox()),
          Flexible(
            child: Column(mainAxisSize: MainAxisSize.min, children: [card]),
          ),
        ],
      );

      autoSizeTest(
        'pass card uses the glass dock surface instead of a white card',
        (tester) async {
          await pumpAtSize(
            tester,
            portrait,
            PassTransitionCard(
              onActionPressed: () async => true,
              actionText: 'Pass to Alexandra',
            ),
          );

          check(find.byType(Card).evaluate()).isEmpty();
          check(dockSurface().evaluate()).length.equals(1);
          final instruction = tester.widget<AutoSizeText>(
            find.byType(AutoSizeText).first,
          );
          check(instruction.style?.color).equals(AppTheme.cream);
        },
        variant: phones,
      );

      autoSizeTest(
        'stacks the instruction above a full-width 48dp slider on a 360px phone',
        (tester) async {
          await pumpAtSize(
            tester,
            portrait,
            ReceiveTransitionCard(onActionPressed: () async => true),
          );

          checkStacked(tester, 'The Totem is being passed to you.');
          // Stacked: the slider spans the pill rather than sharing a row.
          final slider = tester.getRect(find.byType(ActionSlider));
          final surface = tester.getRect(dockSurface());
          check(slider.width).isGreaterThan(surface.width - 20);
          checkFitsScreen(tester, dockSurface(), portrait);
        },
        variant: phones,
      );

      autoSizeTest(
        'gives the stacked instruction a third line at 1.5x text scale',
        (tester) async {
          await pumpAtSize(
            tester,
            portrait,
            PassTransitionCard(onActionPressed: () async => true),
            textScale: 1.5,
          );

          checkStacked(tester, passInstruction);
          check(
            tester
                .widget<AutoSizeText>(
                  find.widgetWithText(AutoSizeText, passInstruction),
                )
                .maxLines,
          ).equals(3);
          checkFitsScreen(tester, dockSurface(), portrait);
        },
        variant: phones,
      );

      autoSizeTest(
        'receive slider still completes on swipe',
        (tester) async {
          var received = false;
          await pumpAtSize(
            tester,
            portrait,
            ReceiveTransitionCard(
              onActionPressed: () async {
                received = true;
                return true;
              },
            ),
          );

          await tester.drag(
            find.byKey(ActionSlider.thumbKey),
            const Offset(400, 0),
          );
          await tester.pump();

          check(received).isTrue();
        },
        variant: phones,
      );

      autoSizeTest(
        'does not show the space bar caption without a keyboard',
        (tester) async {
          await pumpAtSize(
            tester,
            portrait,
            PassTransitionCard(onActionPressed: () async => true),
          );

          check(find.textContaining('press space bar').evaluate()).isEmpty();
        },
        variant: phones,
      );

      autoSizeTest(
        'stacks in the landscape side column and stays on screen',
        (tester) async {
          for (final size in [landscape, const Size(667, 375)]) {
            await pumpAtSize(
              tester,
              size,
              landscapeSideColumn(
                PassTransitionCard(onActionPressed: () async => true),
              ),
            );

            checkStacked(tester, passInstruction);
            checkFitsScreen(tester, find.byType(ActionSlider), size);
            checkFitsScreen(tester, dockSurface(), size);
          }
        },
        variant: phones,
      );

      autoSizeTest(
        'stacks 400-500dp pills on small viewports so Pass text has room',
        (tester) async {
          await pumpAtSize(
            tester,
            landscape,
            SizedBox(
              width: 520,
              child: PassTransitionCard(onActionPressed: () async => true),
            ),
          );

          checkStacked(tester, passInstruction);
        },
        variant: phones,
      );

      autoSizeTest(
        'keeps the row once a small-viewport pill is 500dp wide',
        (tester) async {
          await pumpAtSize(
            tester,
            landscape,
            SizedBox(
              width: 560,
              child: PassTransitionCard(onActionPressed: () async => true),
            ),
          );

          checkInline(tester, passInstruction);
        },
        variant: phones,
      );

      autoSizeTest(
        'keeps the row on a narrow medium viewport',
        (tester) async {
          // Shortest side 640: a medium viewport with a ~580dp pill.
          await pumpAtSize(
            tester,
            const Size(640, 900),
            PassTransitionCard(onActionPressed: () async => true),
          );

          final text = tester.getRect(find.text(passInstruction));
          final slider = tester.getRect(find.byType(ActionSlider));
          check(slider.height).equals(44);
          check(text.right).isLessOrEqual(slider.left);
        },
        variant: phones,
      );

      autoSizeTest(
        'keeps the row for a ~421dp pill on a medium viewport',
        (tester) async {
          // The speaking screen's 60dp side padding leaves a 601dp window
          // with a ~421dp pill; medium viewports must not stack it.
          await pumpAtSize(
            tester,
            const Size(640, 900),
            SizedBox(
              width: 481,
              child: PassTransitionCard(onActionPressed: () async => true),
            ),
          );

          check(tester.getSize(dockSurface()).width).equals(421);
          final slider = tester.getRect(find.byType(ActionSlider));
          check(slider.height).equals(44);
          checkInline(tester, passInstruction);
        },
        variant: phones,
      );

      autoSizeTest(
        'waiting card is a single-row pill at the inline pill height',
        (tester) async {
          await pumpAtSize(
            tester,
            portrait,
            const WaitingReceiveTransitionCard(),
          );

          check(find.byType(Card).evaluate()).isEmpty();
          check(dockSurface().evaluate()).length.equals(1);
          // Matches an inline actionable pill (48dp action + 6dp insets);
          // a stacked phone pill is taller.
          check(tester.getSize(dockSurface()).height).equals(48 + 6 * 2);
        },
        variant: phones,
      );

      autoSizeTest(
        'prompt card stacks the field above a 48dp slider',
        (tester) async {
          await pumpAtSize(
            tester,
            portrait,
            PromptTransitionCard(
              initialPrompt: 'What are you grateful for?',
              onManagePrompts: () {},
              onActionPressed:
                  ({
                    customPrompt,
                    sessionPromptId,
                    clearPrompt = false,
                  }) async => true,
            ),
          );

          check(find.byType(Card).evaluate()).isEmpty();
          check(dockSurface().evaluate()).length.equals(1);
          final field = tester.getRect(find.byType(TextField));
          final slider = tester.getRect(find.byType(ActionSlider));
          check(slider.height).equals(48);
          check(field.bottom).isLessOrEqual(slider.top);
          checkFitsScreen(tester, dockSurface(), portrait);
        },
        variant: phones,
      );

      autoSizeTest(
        'docked sliders use the action bar label; Join keeps its own',
        (tester) async {
          final theme = AppTheme.lightTheme;
          TextStyle? labelOf(String text) => tester
              .widget<AutoSizeText>(find.widgetWithText(AutoSizeText, text))
              .style;

          await pumpAtSize(
            tester,
            portrait,
            ReceiveTransitionCard(onActionPressed: () async => true),
            theme: theme,
          );
          check(
            labelOf('Receive')?.fontSize,
          ).equals(theme.textTheme.labelLarge?.fontSize);

          await pumpAtSize(
            tester,
            portrait,
            JoinTransitionCard(onActionPressed: () async => true),
            theme: theme,
          );
          check(labelOf('Join')?.fontSize).equals(
            theme.elevatedButtonTheme.style?.textStyle?.resolve({})?.fontSize,
          );
        },
        variant: phones,
      );
    });

    autoSizeTest('WaitingReceiveTransitionCard renders without action button', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(const WaitingReceiveTransitionCard()),
      );

      check(
        tester.widgetList(find.byType(ActionSliderButton)),
      ).length.equals(0);
      check(
        tester.widgetList(
          find.textContaining('Waiting for the receiver to accept'),
        ),
      ).length.equals(1);
    });

    autoSizeTest('PromptTransitionCard renders and triggers action', (
      tester,
    ) async {
      bool actionTriggered = false;
      String? message;

      await tester.pumpWidget(
        buildTestWidget(
          PromptTransitionCard(
            onActionPressed:
                ({customPrompt, sessionPromptId, clearPrompt = false}) async {
                  actionTriggered = true;
                  message = customPrompt;
                  return true;
                },
          ),
        ),
      );

      check(tester.widgetList(find.byType(TextField))).length.equals(1);
      check(
        tester.widgetList(find.byType(ActionSliderButton)),
      ).length.equals(1);

      await tester.enterText(find.byType(TextField), 'Test prompt');

      // Trigger the action
      final button = tester.widget<ActionSliderButton>(
        find.byType(ActionSliderButton),
      );
      await button.onActionCompleted();

      check(actionTriggered).equals(true);
      check(message).equals('Test prompt');
    });

    autoSizeTest(
      'PromptTransitionCard passes unchanged text without replacing the prompt',
      (tester) async {
        String? capturedCustomPrompt;
        int? capturedSessionPromptId;

        await tester.pumpWidget(
          buildTestWidget(
            PromptTransitionCard(
              initialPrompt: 'Prepared prompt',
              initialSessionPromptId: 42,
              onActionPressed:
                  ({customPrompt, sessionPromptId, clearPrompt = false}) async {
                    capturedCustomPrompt = customPrompt;
                    capturedSessionPromptId = sessionPromptId;
                    return true;
                  },
            ),
          ),
        );

        final button = tester.widget<ActionSliderButton>(
          find.byType(ActionSliderButton),
        );
        await button.onActionCompleted();

        check(capturedCustomPrompt).isNull();
        check(capturedSessionPromptId).isNull();
      },
    );

    autoSizeTest('PromptTransitionCard explicitly clears a removed prompt', (
      tester,
    ) async {
      var clearRequested = false;
      await tester.pumpWidget(
        buildTestWidget(
          PromptTransitionCard(
            initialPrompt: 'Prepared prompt',
            onActionPressed:
                ({customPrompt, sessionPromptId, clearPrompt = false}) async {
                  clearRequested = clearPrompt;
                  return true;
                },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '');
      await tester
          .widget<ActionSliderButton>(find.byType(ActionSliderButton))
          .onActionCompleted();

      check(clearRequested).isTrue();
    });
  });
}

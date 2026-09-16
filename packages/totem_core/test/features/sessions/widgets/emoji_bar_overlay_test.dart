import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';

void main() {
  group('EmojiBarOverlay', () {
    final buttonKey = GlobalKey();

    Widget buildOverlay({
      required ValueChanged<String> onEmojiSelected,
      required VoidCallback onDismissed,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: SizedBox(key: buttonKey, width: 48, height: 48),
              ),
              EmojiBarOverlay(
                buttonKey: buttonKey,
                onEmojiSelected: onEmojiSelected,
                onDismissed: onDismissed,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders all default emojis', (tester) async {
      await tester.pumpWidget(
        buildOverlay(onEmojiSelected: (_) {}, onDismissed: () {}),
      );

      // Complete initial layout and fade-in animation.
      await tester.pumpAndSettle();

      for (final emoji in EmojiBar.defaultEmojis) {
        check(tester.widgetList(find.text(emoji))).length.equals(1);
      }
    });

    testWidgets('does not auto-dismiss after a few seconds', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        buildOverlay(
          onEmojiSelected: (_) {},
          onDismissed: () => dismissed = true,
        ),
      );

      await tester.pumpAndSettle();

      // Pump well past the old 4-second displayDuration
      await tester.pump(const Duration(seconds: 6));

      check(because: 'Should not auto-dismiss', dismissed).equals(false);
      check(
        because: 'EmojiBar should still be visible',
        tester.widgetList(find.byType(EmojiBar)),
      ).length.equals(1);
    });

    testWidgets('selecting an emoji calls onEmojiSelected', (tester) async {
      String? selectedEmoji;
      var dismissed = false;

      await tester.pumpWidget(
        buildOverlay(
          onEmojiSelected: (emoji) => selectedEmoji = emoji,
          onDismissed: () => dismissed = true,
        ),
      );

      await tester.pumpAndSettle();

      // Tap the first emoji
      await tester.tap(find.text(EmojiBar.defaultEmojis.first));
      await tester.pumpAndSettle();

      check(selectedEmoji).equals(EmojiBar.defaultEmojis.first);
      check(
        because: 'Overlay should not be dismissed',
        dismissed,
      ).equals(false);
    });

    testWidgets('tapping outside the menu dismisses it', (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        buildOverlay(
          onEmojiSelected: (_) {},
          onDismissed: () => dismissed = true,
        ),
      );

      await tester.pumpAndSettle();

      // Tap the background barrier (the Positioned.fill behind the menu)
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      check(
        because: 'Tapping outside should dismiss the overlay',
        dismissed,
      ).equals(true);
    });

    testWidgets('dismiss plays a fade-out animation before completing', (
      tester,
    ) async {
      var dismissed = false;

      await tester.pumpWidget(
        buildOverlay(
          onEmojiSelected: (_) {},
          onDismissed: () => dismissed = true,
        ),
      );

      await tester.pumpAndSettle();

      // Tap outside to trigger dismiss
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();

      // Should still be visible mid-animation
      check(
        because: 'onDismissed should not fire mid-animation',
        dismissed,
      ).equals(false);

      await tester.pumpAndSettle();

      check(
        because: 'onDismissed should fire after animation completes',
        dismissed,
      ).equals(true);
    });
  });
}

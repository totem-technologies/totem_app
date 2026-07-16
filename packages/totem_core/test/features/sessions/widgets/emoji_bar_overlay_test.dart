import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
                child: SizedBox(
                  key: buttonKey,
                  width: 48,
                  height: 48,
                ),
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
        buildOverlay(
          onEmojiSelected: (_) {},
          onDismissed: () {},
        ),
      );

      // Complete initial layout and fade-in animation.
      await tester.pumpAndSettle();

      for (final emoji in EmojiBar.defaultEmojis) {
        expect(find.text(emoji), findsOneWidget);
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

      expect(dismissed, isFalse, reason: 'Should not auto-dismiss');
      expect(
        find.byType(EmojiBar),
        findsOneWidget,
        reason: 'EmojiBar should still be visible',
      );
    });

    testWidgets('selecting an emoji calls onEmojiSelected', (
      tester,
    ) async {
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

      expect(selectedEmoji, equals(EmojiBar.defaultEmojis.first));
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

      expect(
        dismissed,
        isTrue,
        reason: 'Tapping outside should dismiss the overlay',
      );
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
      expect(
        dismissed,
        isFalse,
        reason: 'onDismissed should not fire mid-animation',
      );

      await tester.pumpAndSettle();

      expect(
        dismissed,
        isTrue,
        reason: 'onDismissed should fire after animation completes',
      );
    });
  });
}

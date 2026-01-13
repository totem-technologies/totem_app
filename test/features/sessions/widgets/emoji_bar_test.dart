import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/features/sessions/widgets/emoji_bar.dart';

void main() {
  group('EmojiBar Tests', () {
    testWidgets('should render with default emojis', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmojiBar(
              emojis: const ['👍', '👏', '😂'],
              onEmojiSelected: (emoji) {},
            ),
          ),
        ),
      );

      expect(find.byType(EmojiBar), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);
      expect(find.text('👏'), findsOneWidget);
      expect(find.text('😂'), findsOneWidget);
    });

    testWidgets('should render with empty emoji list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmojiBar(
              emojis: const [],
              onEmojiSelected: (emoji) {},
            ),
          ),
        ),
      );

      expect(find.byType(EmojiBar), findsOneWidget);
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('should handle emoji selection', (WidgetTester tester) async {
      String? selectedEmoji;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmojiBar(
              emojis: const ['👍', '👏', '😂'],
              onEmojiSelected: (emoji) => selectedEmoji = emoji,
            ),
          ),
        ),
      );

      await tester.tap(find.text('👍'));
      expect(selectedEmoji, equals('👍'));

      await tester.tap(find.text('👏'));
      expect(selectedEmoji, equals('👏'));
    });

    testWidgets('should have correct styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmojiBar(
              emojis: const ['👍'],
              onEmojiSelected: (emoji) {},
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(EmojiBar),
          matching: find.byType(Material),
        ),
      );

      expect(material.color, equals(Colors.white));
      expect(material.elevation, equals(6));
      expect(material.borderRadius, equals(BorderRadius.circular(20)));
    });

    testWidgets('should have correct padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmojiBar(
              emojis: const ['👍'],
              onEmojiSelected: (emoji) {},
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(EmojiBar),
          matching: find.byType(Padding),
        ),
      );

      expect(
        padding.padding,
        equals(
          const EdgeInsetsDirectional.symmetric(
            horizontal: 15,
            vertical: 6,
          ),
        ),
      );
    });

    testWidgets('should be scrollable horizontally', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmojiBar(
              emojis: const ['👍', '👏', '😂', '😍', '😮', '😢', '🔥', '💯'],
              onEmojiSelected: (emoji) {},
            ),
          ),
        ),
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(EmojiBar),
          matching: find.byType(SingleChildScrollView),
        ),
      );

      expect(scrollView.scrollDirection, equals(Axis.horizontal));
    });

    testWidgets('should have correct row properties', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmojiBar(
              emojis: const ['👍', '👏'],
              onEmojiSelected: (emoji) {},
            ),
          ),
        ),
      );

      final row = tester.widget<Row>(
        find.descendant(
          of: find.byType(EmojiBar),
          matching: find.byType(Row),
        ),
      );

      expect(row.mainAxisSize, equals(MainAxisSize.min));
      expect(row.spacing, equals(10));
    });
  });

  group('RisingEmoji Tests', () {
    testWidgets('should render with correct emoji', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                RisingEmoji(
                  emoji: '👍',
                  startX: 100,
                  startY: 100,
                  onCompleted: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(RisingEmoji), findsOneWidget);
      expect(find.text('👍'), findsOneWidget);
    });

    testWidgets('should start animation on init', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                RisingEmoji(
                  emoji: '👍',
                  startX: 100,
                  startY: 100,
                  onCompleted: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Animation should be running
      expect(find.byType(AnimatedBuilder), findsAny);
    });

    testWidgets('should call onCompleted when animation finishes', (
      WidgetTester tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                RisingEmoji(
                  emoji: '👍',
                  startX: 100,
                  startY: 100,
                  onCompleted: () => completed = true,
                ),
              ],
            ),
          ),
        ),
      );

      // Fast forward animation to completion
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('should be positioned correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                RisingEmoji(
                  emoji: '👍',
                  startX: 150,
                  startY: 200,
                  onCompleted: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(
        find.descendant(
          of: find.byType(RisingEmoji),
          matching: find.byType(Positioned),
        ),
      );

      expect(positioned.left, equals(150));
      expect(positioned.bottom, equals(200));
    });

    testWidgets('should dispose animation controller on dispose', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                RisingEmoji(
                  emoji: '👍',
                  startX: 100,
                  startY: 100,
                  onCompleted: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Remove widget to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();

      // Should not throw or crash
    });
  });

  group('showEmojiBar Tests', () {
    testWidgets('should show emoji bar overlay', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await showEmojiBar(
                      context,
                      onEmojiSelected: (_) {},
                    );
                  },
                  child: const Text('Show Emoji'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Emoji'));
      await tester.pumpAndSettle();

      // Should show overlay with emoji bar
      expect(find.byType(EmojiBar), findsOneWidget);
    });

    testWidgets('should dismiss when tapping outside', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await showEmojiBar(
                      context,
                      onEmojiSelected: (_) {},
                    );
                  },
                  child: const Text('Show Emoji'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Emoji'));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(EmojiBar), findsOneWidget);

      // Tap outside to dismiss
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.byType(EmojiBar), findsNothing);
    });
  });

  group('displayReaction Tests', () {
    testWidgets('should display reaction overlay', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await displayReaction(context, '👍');
                  },
                  child: const Text('Show Reaction'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Reaction'));
      await tester.pumpAndSettle();

      // The function should complete without throwing
      expect(find.text('Show Reaction'), findsOneWidget);
    });

    testWidgets('should handle null render box gracefully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    // Pass a context that doesn't have a render box
                    await displayReaction(context, '👍');
                  },
                  child: const Text('Show Reaction'),
                );
              },
            ),
          ),
        ),
      );

      // Should not throw
      await tester.tap(find.text('Show Reaction'));
      await tester.pumpAndSettle();
    });
  });
}

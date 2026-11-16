import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';

void main() {
  Widget buildOverlay({
    required ValueChanged<String> onEmojiSelected,
    required VoidCallback onDismissed,
  }) {
    final buttonKey = GlobalKey();
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets(
    'reaction chooser remains usable after repeated selections and time',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final selected = <String>[];
        var dismissals = 0;
        await tester.pumpWidget(
          buildOverlay(
            onEmojiSelected: selected.add,
            onDismissed: () => dismissals++,
          ),
        );
        await tester.pumpAndSettle();
        final first = EmojiBar.defaultEmojis.first;
        final last = EmojiBar.defaultEmojis.last;
        await tester.tap(find.bySemanticsLabel(RegExp('Send $first reaction')));
        await tester.pump(const Duration(seconds: 6));
        await tester.tap(find.bySemanticsLabel(RegExp('Send $last reaction')));
        await tester.pump();
        check(selected).deepEquals([first, last]);
        check(dismissals).equals(0);
        await unmount(tester);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('all reactions remain tappable in a narrow layout', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: EmojiBar(
                  emojis: EmojiBar.defaultEmojis,
                  onEmojiSelected: selected.add,
                ),
              ),
            ),
          ),
        ),
      );
      for (final emoji in EmojiBar.defaultEmojis) {
        final action = find.bySemanticsLabel(RegExp('Send $emoji reaction'));
        check(tester.getSemantics(action).flagsCollection.isButton).isTrue();
        await tester.tap(action);
        await tester.pump();
      }
      check(selected).deepEquals(EmojiBar.defaultEmojis);
      check(tester.takeException()).isNull();
      await unmount(tester);
    } finally {
      semantics.dispose();
    }
  });

  for (final keyboard in [false, true]) {
    testWidgets('${keyboard ? 'Escape' : 'barrier taps'} dismisses once', (
      tester,
    ) async {
      var dismissals = 0;
      final selected = <String>[];
      await tester.pumpWidget(
        buildOverlay(
          onEmojiSelected: selected.add,
          onDismissed: () => dismissals++,
        ),
      );
      await tester.pumpAndSettle();
      for (var index = 0; index < 2; index++) {
        if (keyboard) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.tapAt(const Offset(5, 5));
        }
      }
      await tester.pumpAndSettle();
      check(dismissals).equals(1);
      check(selected).isEmpty();
      await unmount(tester);
    });
  }

  testWidgets('unmount during dismissal cancels the completion callback', (
    tester,
  ) async {
    var dismissals = 0;
    await tester.pumpWidget(
      buildOverlay(onEmojiSelected: (_) {}, onDismissed: () => dismissals++),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await unmount(tester);
    await tester.pump(const Duration(seconds: 1));
    check(dismissals).equals(0);
    check(tester.takeException()).isNull();
  });
}

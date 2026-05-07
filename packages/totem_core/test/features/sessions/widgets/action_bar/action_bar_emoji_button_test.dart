import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar_emoji_button.dart';

void main() {
  testWidgets('ActionBarEmojiButton renders send reaction control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionBarEmojiButton(
            onEmojiSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Send reaction'), findsOneWidget);
  });
}

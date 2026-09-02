import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';

void main() {
  Future<void> pumpChip(
    WidgetTester tester, {
    required bool isDesktop,
    required VoidCallback onSend,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickMessageChip(
            label: 'Please mute your mic',
            isDesktop: isDesktop,
            onSend: onSend,
          ),
        ),
      ),
    );
  }

  group('QuickMessageChip', () {
    testWidgets('sends immediately on tap when desktop', (tester) async {
      var sendCount = 0;
      await pumpChip(tester, isDesktop: true, onSend: () => sendCount++);

      await tester.tap(find.text('Please mute your mic'));
      await tester.pump();
      expect(sendCount, 1);
    });

    testWidgets('ignores a quick tap and sends on long press when mobile', (
      tester,
    ) async {
      var sendCount = 0;
      await pumpChip(tester, isDesktop: false, onSend: () => sendCount++);

      await tester.tap(find.text('Please mute your mic'));
      await tester.pump();
      expect(sendCount, 0);

      await tester.longPress(find.text('Please mute your mic'));
      await tester.pump();
      expect(sendCount, 1);
    });
  });
}

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/chat/message_bubble.dart';

void main() {
  testWidgets('lays out a content-width bubble with trailing timestamp', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: MessageBubble(
              text: 'Hello',
              timestamp: '10:25 AM',
              isOwn: true,
            ),
          ),
        ),
      ),
    );

    final bubble = find.ancestor(
      of: find.text('Hello'),
      matching: find.byType(DecoratedBox),
    );

    check(tester.widgetList(find.byType(IntrinsicWidth))).length.equals(1);
    check(tester.getSize(find.byType(MessageBubble)).width).equals(400);
    check(tester.getSize(bubble).width).isLessThan(336);
    check(
      tester.getTopRight(find.text('10:25 AM')).dx,
    ).isCloseTo(tester.getTopRight(bubble).dx - 14, 0.1);
  });
}

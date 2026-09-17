import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/chat/message_bubble.dart';

void main() {
  testWidgets('lays out a content-width bubble without intrinsic sizing', (
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

    check(tester.widgetList(find.byType(IntrinsicWidth))).isEmpty();
    check(tester.getSize(find.byType(MessageBubble)).width).equals(400);
    check(tester.getSize(bubble).width).isLessThan(336);
  });
}

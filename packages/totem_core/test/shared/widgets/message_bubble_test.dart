import 'package:checks/checks.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/chat/message_bubble.dart';

Iterable<TextSpan> _textSpans(InlineSpan span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _textSpans(child);
  }
}

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

  testWidgets('highlights URLs, emails, and phone numbers as actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            text:
                'Visit https://example.com, email hello@example.com, or call +1 (415) 555-2671.',
            timestamp: '10:25 AM',
            isOwn: false,
          ),
        ),
      ),
    );

    final messageText = tester.widget<RichText>(find.byType(RichText).first);
    final actionableSpans = _textSpans(
      messageText.text,
    ).where((span) => span.recognizer is TapGestureRecognizer).toList();

    check(
      actionableSpans.map((span) => span.text),
    ).contains('https://example.com');
    check(
      actionableSpans.map((span) => span.text),
    ).contains('hello@example.com');
    check(
      actionableSpans.map((span) => span.text),
    ).contains('+1 (415) 555-2671');
    for (final span in actionableSpans) {
      check(span.style?.decoration).equals(TextDecoration.underline);
    }
  });
}

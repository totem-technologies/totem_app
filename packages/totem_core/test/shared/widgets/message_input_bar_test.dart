import 'dart:async';

import 'package:checks/checks.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/chat/message_input_bar.dart';

void main() {
  testWidgets('prevents concurrent submissions', (tester) async {
    final sendCompleter = Completer<bool>();
    var sendCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageInputBar(
            onSend: (_) {
              sendCount++;
              return sendCompleter.future;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('message-input-send')));
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    check(sendCount).equals(1);

    sendCompleter.complete(false);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('message-input-send')));
    await tester.pump();

    check(sendCount).equals(2);
  });

  testWidgets('grows from one line to at most three lines', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MessageInputBar())),
    );

    final editableText = tester.widget<EditableText>(find.byType(EditableText));

    check(editableText.minLines).equals(1);
    check(editableText.maxLines).equals(3);
  });

  testWidgets('keeps text when the send callback throws', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageInputBar(
            onSend: (_) => throw StateError('transport failed'),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Retry me');
    await tester.tap(find.byKey(const ValueKey('message-input-send')));
    await tester.pump();

    check(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
    ).equals('Retry me');
    check(tester.takeException()).isNull();
  });

  testWidgets('uses a focusable 48px send button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MessageInputBar(onSend: (_) async => true)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Keyboard send');
    await tester.pump();

    final sendButton = find.byType(IconButton);
    check(tester.widgetList(sendButton)).length.equals(1);
    check(tester.getSize(sendButton).width).equals(48);
    check(tester.getSize(sendButton).height).equals(48);
  });

  testWidgets('keeps focus after submitting from the keyboard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MessageInputBar(onSend: (_) async => true)),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    check(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
    ).isTrue();
  });
}

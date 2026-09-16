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

    await tester.tap(find.byTooltip('Send'));
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    check(sendCount).equals(1);

    sendCompleter.complete(false);
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    check(sendCount).equals(2);
  });
}

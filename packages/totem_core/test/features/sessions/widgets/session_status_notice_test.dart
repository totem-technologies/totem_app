import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/session_status_notice.dart';

void main() {
  testWidgets(
    'waiting status remains visible without scheduling animation frames',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SessionStatusNotice(
            label: 'Starting soon',
            message: 'Waiting for the session',
          ),
        ),
      );
      await tester.pump();
      check(find.text('STARTING SOON').evaluate()).length.equals(1);
      check(find.text('Waiting for the session').evaluate()).length.equals(1);
      check(tester.binding.transientCallbackCount).equals(0);
      check(tester.binding.hasScheduledFrame).isFalse();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_panel.dart';

void main() {
  testWidgets('keeper can decide separately and admit the remaining queue', (
    tester,
  ) async {
    final requests = [
      AdmissionRequest(
        id: 'one',
        senderIdentity: 'alice',
        recipientIdentity: 'keeper',
        expiresAt: DateTime.utc(2026, 10, 19, 12, 2),
        displayName: 'Alice',
      ),
      AdmissionRequest(
        id: 'two',
        senderIdentity: 'bob',
        recipientIdentity: 'keeper',
        expiresAt: DateTime.utc(2026, 10, 19, 12, 3),
        displayName: 'Bob',
      ),
    ];
    final decisions = <String>[];
    var admittedAll = false;
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeeperAdmissionPanel(
            requests: requests,
            onDecision: (request, approve) async {
              decisions.add('${request.id}:$approve');
            },
            onAdmitAll: () => admittedAll = true,
            onClose: () => dismissed = true,
            busy: false,
            desktop: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Admit Alice'));
    await tester.tap(find.byTooltip('Decline Bob'));
    await tester.tap(find.text('Admit all'));
    await tester.tap(find.byTooltip('Close admission queue'));
    check(decisions).deepEquals(['one:true', 'two:false']);
    check(admittedAll).isTrue();
    check(dismissed).isTrue();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

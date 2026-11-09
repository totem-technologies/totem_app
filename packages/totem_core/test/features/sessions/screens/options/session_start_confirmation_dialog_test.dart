import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/session_admission_scope.dart';
import 'package:totem_core/features/sessions/screens/options/session_start_confirmation_dialog.dart';

Future<void> pumpConfirmation(
  WidgetTester tester, {
  required int waitingCount,
  required Future<bool> Function() onAdmitAll,
  required Future<bool> Function() onStart,
}) async {
  await tester.pumpWidget(
    SessionAdmissionScope(
      requests: List.generate(
        waitingCount,
        (index) => AdmissionRequest(
          id: 'request-$index',
          senderIdentity: 'guest-$index',
          recipientIdentity: 'keeper',
          expiresAt: DateTime(2030),
          displayName: 'Guest $index',
        ),
      ),
      attempts: const [],
      enabled: true,
      busy: false,
      onRetry: null,
      onResetCorruptData: null,
      onDecision: (_, _) async {},
      onDeclinePermanently: (_) async {},
      onAdmitAll: onAdmitAll,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    SessionStartConfirmationDialog(onStart: onStart),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('waits for admission before starting the session', (
    tester,
  ) async {
    final admission = Completer<bool>();
    var admissions = 0;
    var starts = 0;
    await pumpConfirmation(
      tester,
      waitingCount: 2,
      onAdmitAll: () {
        admissions++;
        return admission.future;
      },
      onStart: () async {
        starts++;
        return true;
      },
    );

    check(
      find.textContaining('2 participants waiting').evaluate(),
    ).length.equals(1);
    await tester.tap(find.text('Admit all and start'));
    await tester.pump();
    check(admissions).equals(1);
    check(starts).equals(0);

    admission.complete(true);
    await tester.pumpAndSettle();
    check(starts).equals(1);
    check(find.text('Admit all and start').evaluate()).isEmpty();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('failed admission keeps the dialog open and allows retry', (
    tester,
  ) async {
    var admissions = 0;
    var starts = 0;
    await pumpConfirmation(
      tester,
      waitingCount: 1,
      onAdmitAll: () async => ++admissions > 1,
      onStart: () async {
        starts++;
        return true;
      },
    );

    check(
      find.textContaining('1 participant waiting').evaluate(),
    ).length.equals(1);
    await tester.tap(find.text('Admit all and start'));
    await tester.pump();
    check(admissions).equals(1);
    check(starts).equals(0);
    check(find.text('Admit all and start').evaluate()).length.equals(1);

    await tester.tap(find.text('Admit all and start'));
    await tester.pumpAndSettle();
    check(admissions).equals(2);
    check(starts).equals(1);
    check(find.text('Admit all and start').evaluate()).isEmpty();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

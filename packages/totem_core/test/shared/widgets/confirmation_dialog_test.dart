import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required ConfirmationDialog dialog,
  }) async {
    final hostKey = GlobalKey();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: SizedBox(key: hostKey)),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    showDialog<void>(context: hostKey.currentContext!, builder: (_) => dialog);

    await tester.pumpAndSettle();
  }

  group('ConfirmationDialog', () {
    testWidgets('renders default title, content, and actions', (tester) async {
      await pumpDialog(
        tester,
        dialog: ConfirmationDialog(
          content: 'Delete this item?',
          confirmButtonText: 'Delete',
          onConfirm: () async {},
        ),
      );

      check(tester.widgetList(find.text('Are you sure?'))).length.equals(1);
      check(tester.widgetList(find.text('Delete this item?'))).length.equals(1);
      check(tester.widgetList(find.text('Delete'))).length.equals(1);
      check(tester.widgetList(find.text('Cancel'))).length.equals(1);
    });

    testWidgets('uses custom title and calls onConfirm once', (tester) async {
      var callCount = 0;

      await pumpDialog(
        tester,
        dialog: ConfirmationDialog(
          title: 'Start Session',
          content: 'Ready to begin?',
          confirmButtonText: 'Start',
          onConfirm: () async {
            callCount++;
          },
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('Start Session'))).length.equals(1);
      check(callCount).equals(1);
    });

    testWidgets('shows loading while confirm callback is pending', (
      tester,
    ) async {
      final completer = Completer<void>();

      await pumpDialog(
        tester,
        dialog: ConfirmationDialog(
          content: 'Wait for operation',
          confirmButtonText: 'Confirm',
          onConfirm: () => completer.future,
        ),
      );

      await tester.tap(find.text('Confirm'));
      await tester.pump();

      check(tester.widgetList(find.byType(LoadingIndicator))).length.equals(1);

      final cancelButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Cancel'),
      );
      check(cancelButton.onPressed).isNull();

      completer.complete();
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(LoadingIndicator))).length.equals(0);
    });

    testWidgets('cancel closes the dialog route', (tester) async {
      await pumpDialog(
        tester,
        dialog: ConfirmationDialog(
          content: 'Cancel test',
          confirmButtonText: 'Confirm',
          onConfirm: () async {},
        ),
      );

      check(tester.widgetList(find.byType(AlertDialog))).length.equals(1);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(AlertDialog))).length.equals(0);
    });

    testWidgets('shows timeout error dialog when confirm exceeds 10 seconds', (
      tester,
    ) async {
      final neverCompletes = Completer<void>();

      await pumpDialog(
        tester,
        dialog: ConfirmationDialog(
          content: 'This will time out',
          confirmButtonText: 'Proceed',
          onConfirm: () => neverCompletes.future,
        ),
      );

      await tester.tap(find.text('Proceed'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.text('Something Went Wrong')),
      ).length.equals(1);
      check(tester.widgetList(find.text('OK'))).length.equals(1);
    });
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';

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

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
      ),
    );

    unawaited(
      showDialog<void>(
        context: hostKey.currentContext!,
        builder: (_) => dialog,
      ),
    );

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

      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Delete this item?'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
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

      expect(find.text('Start Session'), findsOneWidget);
      expect(callCount, 1);
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

      expect(find.byType(LoadingIndicator), findsOneWidget);

      final cancelButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Cancel'),
      );
      expect(cancelButton.onPressed, isNull);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byType(LoadingIndicator), findsNothing);
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

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
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

      expect(find.text('Error'), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('OK'), findsOneWidget);
    });
  });
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checks/checks.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';
import 'package:totem_core/shared/widgets/user_feedback.dart';

void main() {
  Future<void> pumpPopup(
    WidgetTester tester, {
    OnFeedbackSubmitted? onSubmitted,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open-button'),
                onPressed: () => showUserFeedbackPopup(
                  context,
                  onFeedbackSubmitted: onSubmitted,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('renders feedback form', (tester) async {
    await pumpPopup(tester);

    check(tester.widgetList(find.text('Feedback'))).length.equals(1);
    check(tester.widgetList(find.byType(TextFormField))).length.equals(1);
    check(tester.widgetList(find.text('Submit Feedback'))).length.equals(1);
  });

  testWidgets('shows validation errors for empty feedback', (tester) async {
    await pumpPopup(tester);

    await tester.tap(find.text('Submit Feedback'));
    await tester.pumpAndSettle();

    check(
      tester.widgetList(find.text('Please enter your feedback')),
    ).length.equals(1);
  });

  testWidgets('shows validation errors for short feedback', (tester) async {
    await pumpPopup(tester);

    await tester.enterText(find.byType(TextFormField), 'short');
    await tester.tap(find.text('Submit Feedback'));
    await tester.pumpAndSettle();

    check(
      tester.widgetList(
        find.text(
          'Please provide more detailed feedback (at least 8 characters)',
        ),
      ),
    ).length.equals(1);
  });

  testWidgets('submits successfully with valid text', (tester) async {
    String? submittedFeedback;
    await pumpPopup(
      tester,
      onSubmitted: (text) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        submittedFeedback = text;
      },
    );

    await tester.enterText(
      find.byType(TextFormField),
      'This is a valid piece of feedback.',
    );
    await tester.tap(find.text('Submit Feedback'));
    await tester.pump();

    // Verify loading indicator is shown
    check(tester.widgetList(find.byType(LoadingIndicator))).length.equals(1);

    await tester.pumpAndSettle();

    // Verify callback was called
    check(submittedFeedback).equals('This is a valid piece of feedback.');

    // Verify success snackbar and dialog closed
    check(
      tester.widgetList(
        find.text('Thank you for your feedback!\nWe appreciate your input.'),
      ),
    ).length.equals(1);
    check(tester.widgetList(find.byType(UserFeedback))).length.equals(0);
  });

  testWidgets(
    'shows discard confirmation if text is populated and user tries to close',
    (tester) async {
      await pumpPopup(tester);

      await tester.enterText(find.byType(TextFormField), 'Some text');

      // Trigger pop by using the navigator
      final _ = tester.state<NavigatorState>(find.byType(Navigator).last)
        ..maybePop();
      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.byType(ConfirmationDialog)),
      ).length.equals(1);
      check(tester.widgetList(find.text('Discard Feedback?'))).length.equals(1);

      // Tap Discard
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(UserFeedback))).length.equals(0);
    },
  );

  testWidgets(
    'does not show discard confirmation if text is empty and user tries to close',
    (tester) async {
      await pumpPopup(tester);

      final _ = tester.state<NavigatorState>(find.byType(Navigator).last)
        ..maybePop();
      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.byType(ConfirmationDialog)),
      ).length.equals(0);
      check(tester.widgetList(find.byType(UserFeedback))).length.equals(0);
    },
  );
}

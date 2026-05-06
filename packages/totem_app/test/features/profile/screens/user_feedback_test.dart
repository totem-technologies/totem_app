import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';

import '../../../../lib/features/profile/screens/user_feedback.dart';

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

    expect(find.text('Feedback'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Submit Feedback'), findsOneWidget);
  });

  testWidgets('shows validation errors for empty feedback', (tester) async {
    await pumpPopup(tester);

    await tester.tap(find.text('Submit Feedback'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your feedback'), findsOneWidget);
  });

  testWidgets('shows validation errors for short feedback', (tester) async {
    await pumpPopup(tester);

    await tester.enterText(find.byType(TextFormField), 'short');
    await tester.tap(find.text('Submit Feedback'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Please provide more detailed feedback (at least 10 characters)',
      ),
      findsOneWidget,
    );
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
    expect(find.byType(LoadingIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // Verify callback was called
    expect(submittedFeedback, 'This is a valid piece of feedback.');

    // Verify success snackbar and dialog closed
    expect(
      find.text('Thank you for your feedback!\nWe appreciate your input.'),
      findsOneWidget,
    );
    expect(find.byType(UserFeedback), findsNothing);
  });

  testWidgets(
    'shows discard confirmation if text is populated and user tries to close',
    (tester) async {
      await pumpPopup(tester);

      await tester.enterText(find.byType(TextFormField), 'Some text');

      // Trigger pop by using the navigator
      final _ = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      )..maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationDialog), findsOneWidget);
      expect(find.text('Discard Feedback?'), findsOneWidget);

      // Tap Discard
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(UserFeedback), findsNothing);
    },
  );

  testWidgets(
    'does not show discard confirmation if text is empty and user tries to close',
    (tester) async {
      await pumpPopup(tester);

      final _ = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      )..maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationDialog), findsNothing);
      expect(find.byType(UserFeedback), findsNothing);
    },
  );
}

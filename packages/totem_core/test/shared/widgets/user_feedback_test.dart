import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';
import 'package:totem_core/shared/widgets/user_feedback.dart';

void main() {
  Future<void> pumpFeedbackHost(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
    OnFeedbackSubmitted? onSubmitted,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(900, 900)),
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open-feedback'),
                  onPressed: () => showUserFeedbackPopup(
                    context,
                    onFeedbackSubmitted: onSubmitted,
                  ),
                  child: const Text('Open Feedback'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    await tester.tap(find.byKey(const Key('open-feedback')));
    await tester.pumpAndSettle();
  }

  Future<void> sendModifiedEnter(
    WidgetTester tester, {
    required LogicalKeyboardKey modifierKey,
  }) async {
    await tester.sendKeyDownEvent(modifierKey);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(modifierKey);
    await tester.pump();
  }

  group('UserFeedback', () {
    testWidgets('does not submit empty or too-short feedback', (tester) async {
      var submissionCount = 0;
      await pumpFeedbackHost(
        tester,
        onSubmitted: (_) async => submissionCount++,
      );

      await tester.tap(find.text('Submit Feedback'));
      await tester.pumpAndSettle();
      check(
        tester.widgetList(find.text('Please enter your feedback')),
      ).length.equals(1);
      check(submissionCount).equals(0);

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
      check(submissionCount).equals(0);
    });

    testWidgets('submits trimmed feedback and reports success', (tester) async {
      String? submittedFeedback;
      final submission = Completer<void>();
      await pumpFeedbackHost(
        tester,
        onSubmitted: (text) async {
          submittedFeedback = text;
          await submission.future;
        },
      );

      await tester.enterText(
        find.byType(TextFormField),
        '  This is a valid piece of feedback.  ',
      );
      await tester.tap(find.text('Submit Feedback'));
      await tester.pump();

      check(tester.widgetList(find.byType(LoadingIndicator))).length.equals(1);
      check(tester.widgetList(find.byType(UserFeedback))).length.equals(1);

      submission.complete();
      await tester.pumpAndSettle();

      check(submittedFeedback).equals('This is a valid piece of feedback.');
      check(
        tester.widgetList(
          find.text('Thank you for your feedback!\nWe appreciate your input.'),
        ),
      ).length.equals(1);
      check(tester.widgetList(find.byType(UserFeedback))).length.equals(0);
    });

    testWidgets('submits with the platform keyboard shortcut', (tester) async {
      String? submittedFeedback;
      await pumpFeedbackHost(
        tester,
        platform: TargetPlatform.macOS,
        onSubmitted: (feedback) async => submittedFeedback = feedback,
      );

      await tester.enterText(
        find.byType(TextFormField),
        '  Keyboard feedback.  ',
      );
      await sendModifiedEnter(tester, modifierKey: LogicalKeyboardKey.metaLeft);

      check(submittedFeedback).equals('Keyboard feedback.');
      check(tester.widgetList(find.byType(UserFeedback))).length.equals(0);
    });

    testWidgets('uses Control+Enter on Windows', (tester) async {
      String? submittedFeedback;
      await pumpFeedbackHost(
        tester,
        platform: TargetPlatform.windows,
        onSubmitted: (feedback) async => submittedFeedback = feedback,
      );

      await tester.enterText(
        find.byType(TextFormField),
        'Keyboard feedback from Windows.',
      );
      await sendModifiedEnter(
        tester,
        modifierKey: LogicalKeyboardKey.controlLeft,
      );

      check(submittedFeedback).equals('Keyboard feedback from Windows.');
      check(tester.widgetList(find.byType(UserFeedback))).length.equals(0);
    });

    testWidgets('asks for confirmation before discarding entered feedback', (
      tester,
    ) async {
      await pumpFeedbackHost(tester);
      await tester.enterText(find.byType(TextFormField), 'Some text');

      await tester
          .state<NavigatorState>(find.byType(Navigator).last)
          .maybePop();
      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.byType(ConfirmationDialog)),
      ).length.equals(1);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(UserFeedback))).length.equals(0);
    });

    testWidgets('closes immediately when discarding empty feedback', (
      tester,
    ) async {
      await pumpFeedbackHost(tester);

      await tester
          .state<NavigatorState>(find.byType(Navigator).last)
          .maybePop();
      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.byType(ConfirmationDialog)),
      ).length.equals(0);
      check(tester.widgetList(find.byType(UserFeedback))).length.equals(0);
    });
  });
}

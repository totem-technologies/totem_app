import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/shared/widgets/user_feedback.dart';

void main() {
  Future<void> pumpFeedbackHost(
    WidgetTester tester, {
    required TargetPlatform platform,
    required OnFeedbackSubmitted onFeedbackSubmitted,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(platform: platform),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(900, 900)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () => showUserFeedbackPopup(
                      context,
                      onFeedbackSubmitted: onFeedbackSubmitted,
                    ),
                    child: const Text('Open Feedback'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Feedback'));
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
    testWidgets('submits on Command+Enter on macOS', (tester) async {
      String? submittedFeedback;

      await pumpFeedbackHost(
        tester,
        platform: TargetPlatform.macOS,
        onFeedbackSubmitted: (feedback) async {
          submittedFeedback = feedback;
        },
      );

      await tester.enterText(
        find.byType(TextFormField),
        '  This is useful feedback.  ',
      );
      await tester.pump();

      await sendModifiedEnter(
        tester,
        modifierKey: LogicalKeyboardKey.metaLeft,
      );

      expect(submittedFeedback, 'This is useful feedback.');
      expect(find.byType(UserFeedback), findsNothing);
    });

    testWidgets('submits on Control+Enter on windows', (tester) async {
      String? submittedFeedback;

      await pumpFeedbackHost(
        tester,
        platform: TargetPlatform.windows,
        onFeedbackSubmitted: (feedback) async {
          submittedFeedback = feedback;
        },
      );

      await tester.enterText(
        find.byType(TextFormField),
        'This feedback should submit from the keyboard.',
      );
      await tester.pump();

      await sendModifiedEnter(
        tester,
        modifierKey: LogicalKeyboardKey.controlLeft,
      );

      expect(
        submittedFeedback,
        'This feedback should submit from the keyboard.',
      );
      expect(find.byType(UserFeedback), findsNothing);
    });
  });
}

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/features/sessions/presentation/session_action_feedback.dart';
import 'package:totem_core/features/sessions/services/session_commands.dart';

import '../../../setup.dart';
import 'action_feedback_host.dart';

SessionCommandFailure _failure(SessionCommandFailureKind kind) =>
    SessionCommandFailure(kind, SessionCommandException(kind, 'detail'));

void main() {
  setUp(silenceLogger);

  group('sessionActionErrorCopy', () {
    for (final (action, kind, subject, title, message) in [
      (
        SessionAction.passTotem,
        SessionCommandFailureKind.network,
        null,
        "Couldn't pass the totem",
        "It's still your turn. Check your connection and try again.",
      ),
      (
        SessionAction.passTotem,
        SessionCommandFailureKind.unknownOutcome,
        null,
        'Still passing the totem',
        "We couldn't confirm the pass. If the totem doesn't move in a moment, try again.",
      ),
      (
        SessionAction.passTotem,
        SessionCommandFailureKind.partialSuccess,
        null,
        'Totem passed',
        "Your microphone couldn't be muted. Please mute it from the controls below.",
      ),
      (
        SessionAction.acceptTotem,
        SessionCommandFailureKind.unknownOutcome,
        null,
        'Still receiving the totem',
        "We couldn't confirm it. If it's not your turn in a moment, try again.",
      ),
      (
        SessionAction.acceptTotem,
        SessionCommandFailureKind.network,
        null,
        "Couldn't receive the totem",
        'We were unable to accept the totem. Please try again.',
      ),
      (
        SessionAction.forcePass,
        SessionCommandFailureKind.conflict,
        'Ana',
        "Couldn't pass to Ana",
        "The totem hasn't moved. Please try again.",
      ),
      (
        SessionAction.forcePass,
        SessionCommandFailureKind.network,
        null,
        "Couldn't pass to the next person",
        "The totem hasn't moved. Please try again.",
      ),
      (
        SessionAction.forcePass,
        SessionCommandFailureKind.unknownOutcome,
        'Ana',
        'Still passing to Ana',
        "We couldn't confirm it. Check the room before trying again.",
      ),
      (
        SessionAction.startSession,
        SessionCommandFailureKind.network,
        null,
        "Couldn't start the session",
        'Everyone is still in the waiting room. Please try again.',
      ),
      (
        SessionAction.endSession,
        SessionCommandFailureKind.network,
        null,
        "Couldn't end the session",
        'The session is still running. Please try again.',
      ),
      (
        SessionAction.muteEveryone,
        SessionCommandFailureKind.network,
        null,
        "Couldn't mute everyone",
        'Please check your connection and try again.',
      ),
      (
        SessionAction.muteParticipant,
        SessionCommandFailureKind.network,
        'Ana',
        "Couldn't mute Ana",
        'Please check your connection and try again.',
      ),
      (
        SessionAction.disableParticipantCamera,
        SessionCommandFailureKind.network,
        'Ana',
        "Couldn't turn off Ana's camera",
        'Please check your connection and try again.',
      ),
      (
        SessionAction.removeParticipant,
        SessionCommandFailureKind.recoveryRequired,
        'Ana',
        "Couldn't remove Ana",
        'Please check your connection and try again.',
      ),
      (
        SessionAction.removeParticipant,
        SessionCommandFailureKind.unknownOutcome,
        'Ana',
        "We're not sure Ana was removed",
        'Give it a moment before trying again.',
      ),
      (
        SessionAction.removeParticipant,
        SessionCommandFailureKind.partialSuccess,
        'Ana',
        'Ana was removed',
        "Some cleanup didn't finish. Please keep the session open.",
      ),
      (
        SessionAction.banParticipant,
        SessionCommandFailureKind.unauthorized,
        'Ana',
        "Couldn't ban Ana",
        'Please check your connection and try again.',
      ),
      (
        SessionAction.setPrompt,
        SessionCommandFailureKind.conflict,
        null,
        "Couldn't update the prompt",
        'Please try again.',
      ),
    ]) {
      test('${action.name} ${kind.name} reads "$title"', () {
        final copy = sessionActionErrorCopy(
          action,
          _failure(kind),
          subject: subject,
        );
        check(copy).isNotNull()
          ..has((copy) => copy.title, 'title').equals(title)
          ..has((copy) => copy.message, 'message').equals(message);
      });
    }

    test('stays silent for a superseded connection and never shows the '
        'developer message', () {
      for (final action in SessionAction.values) {
        check(
          sessionActionErrorCopy(
            action,
            _failure(SessionCommandFailureKind.superseded),
          ),
        ).isNull();
        for (final kind in SessionCommandFailureKind.values) {
          final copy = sessionActionErrorCopy(
            action,
            SessionCommandFailure(
              kind,
              SessionCommandException(kind, 'Developer detail for logs.'),
            ),
            subject: 'Ana',
          );
          if (copy == null) continue;
          check(copy.title).not((it) => it.contains('Developer detail'));
          check(copy.message).not((it) => it.contains('Developer detail'));
        }
      }
    });
  });

  test('a repeated failure is reported again, and a superseded one is not', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reports = <SessionActionReport?>[];
    container.listen(
      sessionActionFeedbackProvider,
      (_, next) => reports.add(next),
    );
    container.read(sessionActionFeedbackProvider.notifier)
      ..report(
        SessionAction.muteParticipant,
        AppNetworkException.noConnection(),
        subject: 'Ana',
      )
      ..report(
        SessionAction.muteParticipant,
        AppNetworkException.noConnection(),
        subject: 'Ana',
      )
      ..report(
        SessionAction.muteParticipant,
        SessionCommandException(
          SessionCommandFailureKind.superseded,
          'This session connection has ended',
        ),
        subject: 'Ana',
      );

    check(reports).length.equals(2);
    check(reports.map((report) => report?.dedupeKey).toSet()).length.equals(1);
  });

  testWidgets(
    'repeated failures of one action replace its banner instead of stacking',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ActionFeedbackHost(child: SizedBox())),
        ),
      );
      final feedback = container.read(sessionActionFeedbackProvider.notifier);

      for (var attempt = 0; attempt < 3; attempt++) {
        feedback.report(
          SessionAction.muteEveryone,
          AppNetworkException.noConnection(),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      check(find.text("Couldn't mute everyone").evaluate()).length.equals(1);
      // Nothing is queued behind the latest banner once it expires.
      for (var tick = 0; tick < 16; tick++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      check(find.text("Couldn't mute everyone").evaluate()).isEmpty();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    // auto_size_text's notification banner does not dispose its TextPainters.
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      classes: <String>['TextPainter'],
    ),
  );
}

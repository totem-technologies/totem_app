import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/options/end_session_confirmation_dialog.dart';
import 'package:totem_core/features/sessions/screens/options/leave_session_confirmation_dialog.dart';
import 'package:totem_core/shared/router.dart';

import '../../../../setup.dart';
import '../../presentation/action_feedback_host.dart';

class _Session extends Mock implements SessionController {}

class _Keeper extends Mock implements SessionKeeperController {}

const _activeState = SessionRoomState(
  connection: ConnectionState(
    phase: SessionPhase.connected,
    state: RoomConnectionState.connected,
  ),
  participants: ParticipantsState(),
  turn: SessionTurnState(
    roomState: RoomState(
      keeper: 'keeper',
      nextSpeaker: Omittable(''),
      currentSpeaker: Omittable('keeper'),
      status: RoomStatus.active,
      turnState: TurnState.speaking,
      sessionSlug: 'session',
      statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
      talkingOrder: [],
      version: 1,
      roundNumber: 1,
    ),
  ),
);

Future<Completer<bool?>> _pumpConfirmation(
  WidgetTester tester, {
  required SessionController session,
  required bool leaveAfterEnd,
}) async {
  final dialogCompleted = Completer<bool?>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSessionProvider.overrideWith((_) => session),
        currentSessionStateProvider.overrideWithValue(_activeState),
        isCurrentUserKeeperProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        home: ActionFeedbackHost(
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    useRootNavigator: false,
                    builder: (_) => leaveAfterEnd
                        ? const LeaveSessionConfirmationDialog()
                        : EndSessionConfirmationDialog(session: session),
                  );
                  dialogCompleted.complete(result);
                  // Mirrors the caller's leave contract: the dialog must
                  // return true before connection cleanup is requested.
                  if (leaveAfterEnd && result == true) {
                    await session.leave();
                  }
                },
                child: const Text('Open confirmation'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return dialogCompleted;
}

void main() {
  setUp(() {
    setupAppConfig();
    silenceLogger();
    TotemRouter.instance = FakeTotemRouter();
  });

  for (final leaveAfterEnd in [false, true]) {
    testWidgets(
      '${leaveAfterEnd ? 'end and leave' : 'end'} keeps confirmation open after failure and closes only on success',
      (tester) async {
        final session = _Session();
        final keeper = _Keeper();
        final pendingEnd = Completer<bool>();
        when(() => session.keeper).thenReturn(keeper);
        when(keeper.endSession).thenAnswer((_) => pendingEnd.future);
        when(session.leave).thenAnswer((_) async {});
        final dialogCompleted = await _pumpConfirmation(
          tester,
          session: session,
          leaveAfterEnd: leaveAfterEnd,
        );
        await tester.tap(find.text('Open confirmation'));
        await tester.pumpAndSettle();
        final action = leaveAfterEnd ? 'End session and Leave' : 'End session';
        await tester.tap(find.text(action).last);
        await tester.pump();
        // Ending owns its deadline, so a slow end is not shown as a failure.
        await tester.pump(const Duration(seconds: 11));
        check(find.text('Something Went Wrong').evaluate()).isEmpty();
        check(dialogCompleted.isCompleted).isFalse();
        pendingEnd.completeError(AppNetworkException.noConnection());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        check(find.text("Couldn't end the session").evaluate()).isNotEmpty();
        check(
          find
              .text('The session is still running. Please try again.')
              .evaluate(),
        ).isNotEmpty();
        // The confirmation stays open, so confirming again is the retry.
        check(dialogCompleted.isCompleted).isFalse();
        verifyNever(session.leave);
        check(find.text(action).evaluate()).isNotEmpty();

        when(keeper.endSession).thenAnswer((_) async => true);
        await tester.tap(find.text(action).last);
        await tester.pumpAndSettle();
        check(dialogCompleted.isCompleted).isTrue();
        check(await dialogCompleted.future).equals(leaveAfterEnd ? true : null);
        if (leaveAfterEnd) {
          verify(session.leave).called(1);
        } else {
          verifyNever(session.leave);
        }
        verify(keeper.endSession).called(2);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
      // auto_size_text's notification banner does not dispose its TextPainters.
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );
  }
}

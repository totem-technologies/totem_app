import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
        home: Builder(
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
        check(dialogCompleted.isCompleted).isFalse();
        pendingEnd.completeError(AppNetworkException.noConnection());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        check(find.text('Retry').evaluate()).length.equals(1);
        // Dismiss only the error recovery route; the session confirmation must
        // remain available instead of treating a handled failure as success.
        await tester.tap(find.text('Cancel').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
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
    );
  }

  for (final retrySucceeds in [false, true]) {
    testWidgets(
      '${retrySucceeds ? 'successful' : 'failed'} explicit retry waits for its backend outcome before leaving',
      (tester) async {
        final session = _Session();
        final keeper = _Keeper();
        final firstEnd = Completer<bool>();
        final retriedEnd = Completer<bool>();
        var requests = 0;
        when(() => session.keeper).thenReturn(keeper);
        when(keeper.endSession).thenAnswer((_) {
          requests++;
          return requests == 1 ? firstEnd.future : retriedEnd.future;
        });
        when(session.leave).thenAnswer((_) async {});
        final dialogCompleted = await _pumpConfirmation(
          tester,
          session: session,
          leaveAfterEnd: true,
        );
        await tester.tap(find.text('Open confirmation'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('End session and Leave'));
        await tester.pump();
        firstEnd.completeError(AppNetworkException.noConnection());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        check(requests).equals(2);
        check(dialogCompleted.isCompleted).isFalse();
        verifyNever(session.leave);
        if (retrySucceeds) {
          retriedEnd.complete(true);
        } else {
          retriedEnd.completeError(AppNetworkException.noConnection());
        }
        await tester.pumpAndSettle();
        if (retrySucceeds) {
          check(dialogCompleted.isCompleted).isTrue();
          check(await dialogCompleted.future).equals(true);
          verify(session.leave).called(1);
        } else {
          check(dialogCompleted.isCompleted).isFalse();
          verifyNever(session.leave);
          await tester.tap(find.text('Cancel').last);
          await tester.pumpAndSettle();
          check(await dialogCompleted.future).isNull();
          verifyNever(session.leave);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}

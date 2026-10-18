import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart'
    as session_state;
import 'package:totem_core/features/sessions/controllers/features/session_prompts_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/session_prompts_modal.dart';

import '../../../setup.dart';
import '../controllers/core/session_controller_mock.dart';
import '../session_test_mocks.dart';

SessionRoomState _sessionState() => const SessionRoomState(
  connection: session_state.ConnectionState(
    phase: SessionPhase.connected,
    state: RoomConnectionState.connected,
  ),
  participants: ParticipantsState(participants: []),
  chat: ChatState(),
  turn: SessionTurnState(
    roomState: RoomState(
      keeper: 'keeper-1',
      sessionSlug: 'test-session',
      status: RoomStatus.active,
      statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
      turnState: TurnState.idle,
      talkingOrder: [],
      roundNumber: 1,
      version: 1,
    ),
  ),
);

void main() {
  setUpAll(setupAppConfig);

  testWidgets('reports a failed prepared prompt selection', (tester) async {
    final session = MockSessionController();
    final keeper = MockSessionKeeperController();
    when(() => session.keeper).thenReturn(keeper);
    when(
      () => keeper.setPrompt(
        customPrompt: null,
        sessionPromptId: 1,
        clearPrompt: false,
      ),
    ).thenThrow(Exception('selection failed'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWithValue(session),
          currentSessionStateProvider.overrideWithValue(_sessionState()),
          sessionPromptsControllerProvider('test-session').overrideWithValue(
            const SessionPromptsState(
              snapshot: SessionPromptsSchema(
                revision: 1,
                prompts: [
                  SessionPromptSchema(
                    id: 1,
                    prompt: 'A prepared prompt',
                    position: 0,
                    consumedRoundNumbers: [],
                  ),
                ],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SessionPromptsModal(sessionSlug: 'test-session'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Use now'));
    await tester.pump();

    check(tester.widgetList(find.text('Oops! Something went wrong.'))).length
        .equals(1);
    verify(
      () => keeper.setPrompt(
        customPrompt: null,
        sessionPromptId: 1,
        clearPrompt: false,
      ),
    ).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

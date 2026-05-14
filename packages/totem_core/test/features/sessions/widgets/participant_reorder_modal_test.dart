import 'dart:async';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/participant_reorder_modal.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';

class MockSessionController extends Mock implements SessionController {}

class MockSessionKeeperController extends Mock
    implements SessionKeeperController {}

class MockSessionRoomState extends Mock implements SessionRoomState {}

class MockParticipant extends Mock implements Participant {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(TrackSource.camera);
    registerFallbackValue(<String>[]);
  });

  testWidgets('save sends reordered identities with keeper first', (
    tester,
  ) async {
    final session = MockSessionController();
    final keeper = MockSessionKeeperController();
    final sessionState = MockSessionRoomState();
    const roomState = RoomState(
      sessionSlug: 'test-session',
      version: 1,
      status: RoomStatus.waitingRoom,
      turnState: TurnState.idle,
      statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
      talkingOrder: ['keeper-1', 'user-1', 'user-2', 'user-3'],
      keeper: 'keeper-1',
      roundNumber: 1,
    );
    final keeperParticipant = MockParticipant();
    final user1 = MockParticipant();
    final user2 = MockParticipant();
    final user3 = MockParticipant();

    when(() => session.keeper).thenReturn(keeper);
    when(() => keeper.reorder(any())).thenAnswer((_) async {});
    when(() => keeperParticipant.identity).thenReturn('keeper-1');
    when(() => keeperParticipant.name).thenReturn('Keeper');
    when(() => user1.identity).thenReturn('user-1');
    when(() => user1.name).thenReturn('User 1');
    when(() => user2.identity).thenReturn('user-2');
    when(() => user2.name).thenReturn('User 2');
    when(() => user3.identity).thenReturn('user-3');
    when(() => user3.name).thenReturn('User 3');
    when(() => sessionState.participantsList).thenReturn([
      keeperParticipant,
      user1,
      user2,
      user3,
    ]);
    when(() => sessionState.roomState).thenReturn(roomState);
    when(() => sessionState.speakingNow).thenReturn('keeper-1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith((ref) => session),
          currentSessionStateProvider.overrideWith((ref) => sessionState),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ParticipantReorderWidget(),
          ),
        ),
      ),
    );

    expect(find.text('Reorder Participants'), findsOneWidget);

    final handle = find.byType(ReorderableDragStartListener).at(3);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final captured =
        verify(() => keeper.reorder(captureAny())).captured.single
            as List<String>;

    expect(captured.first, 'keeper-1');
    expect(captured.toSet(), {'keeper-1', 'user-1', 'user-2', 'user-3'});
    expect(captured, isNot(equals(['keeper-1', 'user-1', 'user-2', 'user-3'])));
  });

  testWidgets('save shows loading until reorder completes', (tester) async {
    final session = MockSessionController();
    final keeper = MockSessionKeeperController();
    final sessionState = MockSessionRoomState();
    const roomState = RoomState(
      sessionSlug: 'test-session',
      version: 1,
      status: RoomStatus.waitingRoom,
      turnState: TurnState.idle,
      statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
      talkingOrder: ['keeper-1', 'user-1', 'user-2'],
      keeper: 'keeper-1',
      roundNumber: 1,
    );
    final keeperParticipant = MockParticipant();
    final user1 = MockParticipant();
    final user2 = MockParticipant();
    final reorderCompleter = Completer<void>();

    when(() => session.keeper).thenReturn(keeper);
    when(
      () => keeper.reorder(any()),
    ).thenAnswer((_) => reorderCompleter.future);
    when(() => keeperParticipant.identity).thenReturn('keeper-1');
    when(() => keeperParticipant.name).thenReturn('Keeper');
    when(() => user1.identity).thenReturn('user-1');
    when(() => user1.name).thenReturn('User 1');
    when(() => user2.identity).thenReturn('user-2');
    when(() => user2.name).thenReturn('User 2');
    when(() => sessionState.participantsList).thenReturn([
      keeperParticipant,
      user1,
      user2,
    ]);
    when(() => sessionState.roomState).thenReturn(roomState);
    when(() => sessionState.speakingNow).thenReturn('keeper-1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith((ref) => session),
          currentSessionStateProvider.overrideWith((ref) => sessionState),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ParticipantReorderWidget(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.byType(LoadingIndicator), findsOneWidget);

    reorderCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.byType(LoadingIndicator), findsNothing);
    verify(() => keeper.reorder(any())).called(1);
  });

  testWidgets('save closes the modal after reorder completes', (tester) async {
    final session = MockSessionController();
    final keeper = MockSessionKeeperController();
    final sessionState = MockSessionRoomState();
    const roomState = RoomState(
      sessionSlug: 'test-session',
      version: 1,
      status: RoomStatus.waitingRoom,
      turnState: TurnState.idle,
      statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
      talkingOrder: ['keeper-1', 'user-1', 'user-2'],
      keeper: 'keeper-1',
      roundNumber: 1,
    );
    final keeperParticipant = MockParticipant();
    final user1 = MockParticipant();
    final user2 = MockParticipant();
    final reorderCompleter = Completer<void>();

    when(() => session.keeper).thenReturn(keeper);
    when(
      () => keeper.reorder(any()),
    ).thenAnswer((_) => reorderCompleter.future);
    when(() => keeperParticipant.identity).thenReturn('keeper-1');
    when(() => keeperParticipant.name).thenReturn('Keeper');
    when(() => user1.identity).thenReturn('user-1');
    when(() => user1.name).thenReturn('User 1');
    when(() => user2.identity).thenReturn('user-2');
    when(() => user2.name).thenReturn('User 2');
    when(() => sessionState.participantsList).thenReturn([
      keeperParticipant,
      user1,
      user2,
    ]);
    when(() => sessionState.roomState).thenReturn(roomState);
    when(() => sessionState.speakingNow).thenReturn('keeper-1');

    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith((ref) => session),
          currentSessionStateProvider.overrideWith((ref) => sessionState),
        ],
        child: MaterialApp(
          home: Navigator(
            onGenerateRoute: (settings) {
              return MaterialPageRoute<void>(
                builder: (routeContext) {
                  return Scaffold(
                    body: Builder(
                      builder: (context) {
                        return Center(
                          child: ElevatedButton(
                            onPressed: () {
                              showParticipantReorderModals(context);
                            },
                            child: const Text('Open reorder modal'),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open reorder modal'));
    await tester.pumpAndSettle();

    expect(find.text('Reorder Participants'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.byType(LoadingIndicator), findsOneWidget);

    reorderCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('Reorder Participants'), findsNothing);
    verify(() => keeper.reorder(any())).called(1);
  });
}

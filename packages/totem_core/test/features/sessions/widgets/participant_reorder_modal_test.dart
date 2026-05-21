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

class _ReorderTestHarness {
  _ReorderTestHarness({
    required this.session,
    required this.keeper,
    required this.sessionState,
    required this.participants,
  });

  final MockSessionController session;
  final MockSessionKeeperController keeper;
  final MockSessionRoomState sessionState;
  final Map<String, MockParticipant> participants;
}

void _stubParticipant(
  MockParticipant participant, {
  required String id,
}) {
  when(() => participant.identity).thenReturn(id);
  when(() => participant.name).thenReturn(
    switch (id) {
      'keeper-1' => 'Keeper',
      _ => 'User ${id.split('-').last}',
    },
  );
}

_ReorderTestHarness _createHarness({
  required List<String> participantIds,
  required RoomState roomState,
  required String speakingNow,
  Future<void> Function(List<String>)? reorderHandler,
}) {
  final session = MockSessionController();
  final keeper = MockSessionKeeperController();
  final sessionState = MockSessionRoomState();
  final participants = <String, MockParticipant>{};
  final participantList = <MockParticipant>[];

  for (final id in participantIds) {
    final participant = MockParticipant();
    _stubParticipant(participant, id: id);
    participants[id] = participant;
    participantList.add(participant);
  }

  when(() => session.keeper).thenReturn(keeper);
  when(() => sessionState.roomState).thenReturn(roomState);
  when(() => sessionState.speakingNow).thenReturn(speakingNow);
  when(() => sessionState.participantsList).thenReturn(participantList);
  when(() => keeper.reorder(any())).thenAnswer((invocation) async {
    final order = invocation.positionalArguments.first as List<String>;
    if (reorderHandler != null) {
      await reorderHandler(order);
    }
  });

  return _ReorderTestHarness(
    session: session,
    keeper: keeper,
    sessionState: sessionState,
    participants: participants,
  );
}

Future<void> _pumpReorderWidget(
  WidgetTester tester,
  _ReorderTestHarness harness, {
  required Widget child,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSessionProvider.overrideWith((ref) => harness.session),
        currentSessionStateProvider.overrideWith((ref) => harness.sessionState),
      ],
      child: child,
    ),
  );
}

final _testTheme = ThemeData(splashFactory: NoSplash.splashFactory);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(TrackSource.camera);
    registerFallbackValue(<String>[]);
  });

  testWidgets('save sends reordered identities with keeper first', (
    tester,
  ) async {
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
    final harness = _createHarness(
      participantIds: ['keeper-1', 'user-1', 'user-2', 'user-3'],
      roomState: roomState,
      speakingNow: 'keeper-1',
    );

    await _pumpReorderWidget(
      tester,
      harness,
      child: const MaterialApp(theme: _testTheme, 
        home: Scaffold(
          body: ParticipantReorderWidget(),
        ),
      ),
    );

    expect(find.text('Reorder Participants'), findsOneWidget);

    final handle = find.byType(ReorderableDragStartListener).at(2);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => harness.keeper.reorder(captureAny()),
            ).captured.single
            as List<String>;

    expect(captured.first, 'keeper-1');
    expect(captured.toSet(), {'keeper-1', 'user-1', 'user-2', 'user-3'});
    expect(captured, isNot(equals(['keeper-1', 'user-1', 'user-2', 'user-3'])));
  });

  testWidgets('keeps the keeper visually pinned above reordered items', (
    tester,
  ) async {
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
    final harness = _createHarness(
      participantIds: ['keeper-1', 'user-1', 'user-2', 'user-3'],
      roomState: roomState,
      speakingNow: 'keeper-1',
    );

    await _pumpReorderWidget(
      tester,
      harness,
      child: const MaterialApp(theme: _testTheme, 
        home: Scaffold(
          body: ParticipantReorderWidget(),
        ),
      ),
    );

    final handle = find.byType(ReorderableDragStartListener).at(0);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    final keeperFinder = find.text('Keeper').evaluate().isNotEmpty
        ? find.text('Keeper')
        : find.text('keeper-1');
    final firstParticipantFinder = find.text('User 1').evaluate().isNotEmpty
        ? find.text('User 1')
        : find.text('user-1');

    final keeperTop = tester.getTopLeft(keeperFinder).dy;
    final firstParticipantTop = tester.getTopLeft(firstParticipantFinder).dy;

    expect(keeperTop, lessThan(firstParticipantTop));
  });

  testWidgets('save shows loading until reorder completes', (tester) async {
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
    final reorderCompleter = Completer<void>();

    final harness = _createHarness(
      participantIds: ['keeper-1', 'user-1', 'user-2'],
      roomState: roomState,
      speakingNow: 'keeper-1',
      reorderHandler: (order) => reorderCompleter.future,
    );

    await _pumpReorderWidget(
      tester,
      harness,
      child: const MaterialApp(theme: _testTheme, 
        home: Scaffold(
          body: ParticipantReorderWidget(),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.byType(LoadingIndicator), findsOneWidget);

    reorderCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.byType(LoadingIndicator), findsNothing);
    verify(() => harness.keeper.reorder(any())).called(1);
  });

  testWidgets('save closes the modal after reorder completes', (tester) async {
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
    final reorderCompleter = Completer<void>();

    final harness = _createHarness(
      participantIds: ['keeper-1', 'user-1', 'user-2'],
      roomState: roomState,
      speakingNow: 'keeper-1',
      reorderHandler: (order) => reorderCompleter.future,
    );

    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith((ref) => harness.session),
          currentSessionStateProvider.overrideWith(
            (ref) => harness.sessionState,
          ),
        ],
        child: MaterialApp(theme: _testTheme, 
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
    verify(() => harness.keeper.reorder(any())).called(1);
  });

  testWidgets('cancel closes the modal without saving', (tester) async {
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

    final harness = _createHarness(
      participantIds: ['keeper-1', 'user-1', 'user-2'],
      roomState: roomState,
      speakingNow: 'keeper-1',
    );

    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWith((ref) => harness.session),
          currentSessionStateProvider.overrideWith(
            (ref) => harness.sessionState,
          ),
        ],
        child: MaterialApp(theme: _testTheme, 
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

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Reorder Participants'), findsNothing);
    verifyNever(() => harness.keeper.reorder(any()));
  });

  testWidgets('save failure shows error dialog and keeps modal open', (
    tester,
  ) async {
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

    final harness = _createHarness(
      participantIds: ['keeper-1', 'user-1', 'user-2'],
      roomState: roomState,
      speakingNow: 'keeper-1',
      reorderHandler: (order) async {
        throw Exception('reorder failed');
      },
    );

    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await _pumpReorderWidget(
      tester,
      harness,
      child: MaterialApp(theme: _testTheme, 
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
    );

    await tester.tap(find.text('Open reorder modal'));
    await tester.pumpAndSettle();

    expect(find.text('Reorder Participants'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Error Reordering Participants'), findsOneWidget);
    expect(find.text('Reorder Participants'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Error Reordering Participants'), findsNothing);
    expect(find.text('Reorder Participants'), findsOneWidget);
    verify(() => harness.keeper.reorder(any())).called(1);
  });
}

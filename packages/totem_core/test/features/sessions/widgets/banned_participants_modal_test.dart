import 'dart:async';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/banned_participants_modal.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../controllers/core/session_controller_mock.dart';
import '../screens/receive_totem_screen_test.dart';
import 'participant_reorder_modal_test.dart'
    hide MockSessionController, MockSessionKeeperController;

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  MockSessionController createMockSession({
    required SessionRoomState state,
    Future<void> Function(String)? unbanHandler,
  }) {
    final session = MockSessionController();
    final keeper = MockSessionKeeperController();

    when(() => session.keeper).thenReturn(keeper);
    when(() => session.state).thenReturn(state);

    if (unbanHandler != null) {
      when(() => keeper.unbanParticipant(any())).thenAnswer(
        (invocation) async {
          final slug = invocation.positionalArguments.first as String;
          await unbanHandler(slug);
          return;
        },
      );
    } else {
      when(() => keeper.unbanParticipant(any())).thenAnswer((_) async {
        return;
      });
    }

    return session;
  }

  Future<void> pumpModal(
    WidgetTester tester,
    MockSessionController session,
    SessionRoomState state, {
    required Widget child,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(AuthState.unauthenticated()),
          ),
          currentSessionProvider.overrideWith((ref) => session),
          currentSessionStateProvider.overrideWith((ref) => state),
          userProfileProvider.overrideWith(
            (ref, slug) => Future.value(
              PublicUserSchema(
                slug: slug,
                name: 'User $slug',
                profileAvatarType: ProfileAvatarTypeEnum.td,
                dateCreated: DateTime(2024),
                circleCount: 0,
              ),
            ),
          ),
        ],
        child: child,
      ),
    );
  }

  group('BannedParticipantsModal', () {
    testWidgets('removes tile after successful unban', (tester) async {
      const roomState = RoomState(
        sessionSlug: 'test-session',
        version: 1,
        status: RoomStatus.waitingRoom,
        turnState: TurnState.idle,
        statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
        talkingOrder: [],
        keeper: 'keeper-1',
        bannedParticipants: ['user-1', 'user-2'],
        roundNumber: 1,
      );

      final sessionState = MockSessionRoomState();
      when(() => sessionState.roomState).thenReturn(roomState);

      final unbanCompleter = Completer<void>();
      final session = createMockSession(
        state: sessionState,
        unbanHandler: (_) => unbanCompleter.future,
      );

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await pumpModal(
        tester,
        session,
        sessionState,
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
                              showBannedParticipantsModal(
                                context,
                                session,
                                sessionState,
                              );
                            },
                            child: const Text('Open banned modal'),
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

      // Open the modal
      await tester.tap(find.text('Open banned modal'));
      await tester.pumpAndSettle();

      expect(find.text('Banned Participants'), findsOneWidget);
      expect(find.text('User user-1'), findsOneWidget);
      expect(find.text('User user-2'), findsOneWidget);

      final unbanButtons = find.text('Unban');
      expect(unbanButtons, findsNWidgets(2));

      // Tap the first Unban button
      await tester.tap(unbanButtons.first);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      unbanCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('User user-1'), findsNothing);
      expect(find.text('User user-2'), findsOneWidget);
      expect(find.text('Unban'), findsOneWidget);
    });

    testWidgets('shows empty state when no banned participants', (
      tester,
    ) async {
      const roomState = RoomState(
        sessionSlug: 'test-session',
        version: 1,
        status: RoomStatus.waitingRoom,
        turnState: TurnState.idle,
        statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
        talkingOrder: [],
        keeper: 'keeper-1',
        bannedParticipants: [],
        roundNumber: 1,
      );

      final sessionState = MockSessionRoomState();
      when(() => sessionState.roomState).thenReturn(roomState);

      final session = createMockSession(state: sessionState);

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await pumpModal(
        tester,
        session,
        sessionState,
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
                              showBannedParticipantsModal(
                                context,
                                session,
                                sessionState,
                              );
                            },
                            child: const Text('Open banned modal'),
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

      await tester.tap(find.text('Open banned modal'));
      await tester.pumpAndSettle();

      expect(find.text('Banned Participants'), findsOneWidget);
      expect(find.text('No participants have been banned'), findsOneWidget);
      expect(find.text('Unban'), findsNothing);
    });

    testWidgets('shows error dialog and keeps tile on unban failure', (
      tester,
    ) async {
      const roomState = RoomState(
        sessionSlug: 'test-session',
        version: 1,
        status: RoomStatus.waitingRoom,
        turnState: TurnState.idle,
        statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
        talkingOrder: [],
        keeper: 'keeper-1',
        bannedParticipants: ['user-1'],
        roundNumber: 1,
      );

      final sessionState = MockSessionRoomState();
      when(() => sessionState.roomState).thenReturn(roomState);

      final errorCompleter = Completer<void>();
      final session = createMockSession(
        state: sessionState,
        unbanHandler: (_) => errorCompleter.future,
      );

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await pumpModal(
        tester,
        session,
        sessionState,
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
                              showBannedParticipantsModal(
                                context,
                                session,
                                sessionState,
                              );
                            },
                            child: const Text('Open banned modal'),
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

      await tester.tap(find.text('Open banned modal'));
      await tester.pumpAndSettle();

      expect(find.text('User user-1'), findsOneWidget);
      expect(find.text('Unban'), findsOneWidget);

      // Tap Unban
      await tester.tap(find.text('Unban'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      errorCompleter.completeError(Exception('unban failed'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('User user-1'), findsOneWidget);
      expect(find.text('Unban'), findsOneWidget);

      expect(
        find.text('Something went wrong!\nPlease try again later'),
        findsOneWidget,
      );

      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong!\nPlease try again later'),
        findsNothing,
      );
    });
  });
}

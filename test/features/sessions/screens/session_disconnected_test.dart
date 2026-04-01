import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/session_disconnected.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';

/// A minimal [SessionDetailSchema] for testing.
SessionDetailSchema _createTestSession({
  String slug = 'test-session',
  List<NextSessionSchema> nextEvents = const [],
}) {
  return SessionDetailSchema(
    slug: slug,
    title: 'Test Session',
    space: MobileSpaceDetailSchema(
      slug: 'test-space',
      title: 'Test Space',
      imageLink: null,
      shortDescription: 'A test space.',
      content: '',
      author: PublicUserSchema(
        profileAvatarType: ProfileAvatarTypeEnum.td,
        dateCreated: DateTime(2024),
      ),
      category: null,
      subscribers: 0,
      recurring: null,
      price: 0,
      nextEvents: nextEvents,
    ),
    content: '',
    seatsLeft: 10,
    duration: 60,
    start: DateTime(2024, 6, 1),
    attending: true,
    open: true,
    started: true,
    cancelled: false,
    joinable: false,
    ended: true,
    rsvpUrl: '',
    joinUrl: null,
    subscribeUrl: '',
    calLink: '',
    subscribed: false,
    userTimezone: null,
    meetingProvider: MeetingProviderEnum.livekit,
  );
}

SessionRoomState _createEndedState({
  RoomStatus status = RoomStatus.ended,
  EndReason? endReason,
  bool removed = false,
  DisconnectReason? disconnectReason,
}) {
  return SessionRoomState(
    connection: ConnectionState(
      phase: SessionPhase.ended,
      state: RoomConnectionState.disconnected,
      error: disconnectReason != null
          ? RoomDisconnectionError(disconnectReason)
          : null,
    ),
    participants: ParticipantsState(
      participants: const [],
      removed: removed,
    ),
    chat: const ChatState(),
    turn: SessionTurnState(
      roomState: RoomState(
        keeper: 'keeper-1',
        nextSpeaker: '',
        currentSpeaker: '',
        status: status,
        turnState: TurnState.idle,
        sessionSlug: 'test-session',
        statusDetail: RoomStateStatusDetailEnded(
          EndedDetail(reason: endReason ?? EndReason.keeperEnded),
        ),

        talkingOrder: const [],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

void main() {
  Future<void> pumpDisconnectedScreen(
    WidgetTester tester, {
    required SessionRoomState sessionState,
    SessionDetailSchema? session,
    DisconnectReason? disconnectReason,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionStateProvider.overrideWithValue(sessionState),
          getRecommendedSessionsProvider().overrideWith((ref) => []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SessionDisconnectedScreen(
              session: session ?? _createTestSession(),
              disconnectReason: disconnectReason,
            ),
          ),
        ),
      ),
    );
    // Allow post-frame callbacks to run.
    await tester.pump();
    // Drain the 2.75s Future.delayed timer created in initState.
    await tester.pump(const Duration(seconds: 3));
  }

  group('SessionDisconnectedScreen', () {
    group('keeperEnded reason', () {
      testWidgets('shows "Session Ended" title', (tester) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(),
        );

        expect(find.text('Session Ended'), findsOneWidget);
      });

      testWidgets('shows thank-you body text', (tester) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(),
        );

        expect(
          find.text(
            'Thank you for joining!\nWe hope you found the session enjoyable.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows feedback widget', (tester) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(),
        );

        expect(
          find.text('How was your experience?'),
          findsOneWidget,
        );
      });
    });

    group('keeperAbsent reason', () {
      testWidgets('shows rescheduled title and description', (tester) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(
            endReason: EndReason.keeperAbsent,
          ),
        );

        expect(
          find.text('Session will be rescheduled'),
          findsOneWidget,
        );
        expect(
          find.textContaining('ended due to technical difficulties'),
          findsOneWidget,
        );
      });

      testWidgets('does NOT show feedback widget', (tester) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(
            endReason: EndReason.keeperAbsent,
          ),
        );

        expect(find.text('How was your experience?'), findsNothing);
      });
    });

    group('roomEmpty reason', () {
      testWidgets('shows "Session Ended" title', (tester) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(
            endReason: EndReason.roomEmpty,
          ),
        );

        expect(find.text('Session Ended'), findsOneWidget);
      });
    });

    group('duplicateIdentity (moved to another device)', () {
      testWidgets(
        'shows "Session moved to another device" title',
        (tester) async {
          await pumpDisconnectedScreen(
            tester,
            sessionState: _createEndedState(),
            disconnectReason: DisconnectReason.duplicateIdentity,
          );

          expect(
            find.text('Session moved to another device'),
            findsOneWidget,
          );
          expect(
            find.textContaining('joined the same session on another device'),
            findsOneWidget,
          );
        },
      );

      testWidgets('does NOT show feedback widget', (tester) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(),
          disconnectReason: DisconnectReason.duplicateIdentity,
        );

        expect(find.text('How was your experience?'), findsNothing);
      });
    });

    group('removed reason', () {
      testWidgets('shows removed title', (tester) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(removed: true),
        );

        expect(
          find.text("You've been removed from this session."),
          findsOneWidget,
        );
      });

      testWidgets('shows Community Guidelines link', (tester) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(removed: true),
        );

        expect(find.textContaining('Community Guidelines'), findsOneWidget);
      });

      testWidgets('does NOT show feedback widget', (tester) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(removed: true),
        );

        expect(find.text('How was your experience?'), findsNothing);
      });
    });

    group('next events', () {
      testWidgets('shows next sessions when available', (tester) async {
        final nextEvent = NextSessionSchema(
          slug: 'next-session',
          start: DateTime(2024, 7, 1),
          link: 'https://example.com',
          title: 'Upcoming Session',
          seatsLeft: 5,
          duration: 60,
          meetingProvider: MeetingProviderEnum.livekit,
          calLink: '',
          attending: false,
          cancelled: false,
          open: true,
          joinable: true,
        );

        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(),
          session: _createTestSession(nextEvents: [nextEvent]),
        );

        expect(
          find.text('Join this upcoming session'),
          findsOneWidget,
        );
      });
    });

    group('explore more button', () {
      testWidgets('shows Explore More button', (tester) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(),
        );

        expect(find.text('Explore More'), findsOneWidget);
        expect(
          find.widgetWithText(ElevatedButton, 'Explore More'),
          findsOneWidget,
        );
      });
    });

    group('feedback widget', () {
      testWidgets('shows thumb-up and thumb-down buttons for keeperEnded', (
        tester,
      ) async {
        await pumpDisconnectedScreen(
          tester,
          sessionState: _createEndedState(),
        );

        // The feedback widget should have two interactive containers
        // (thumb up and thumb down).
        expect(find.text('How was your experience?'), findsOneWidget);

        // Both thumbs are GestureDetectors
        final gestureDetectors = find.byType(GestureDetector);
        expect(gestureDetectors, findsWidgets);
      });
    });
  });
}

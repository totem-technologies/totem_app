import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/session_disconnected.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockInAppReview extends Mock implements InAppReview {}

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
      phase: status == RoomStatus.ended
          ? SessionPhase.ended
          : SessionPhase.connected,
      state: status == RoomStatus.ended
          ? RoomConnectionState.disconnected
          : RoomConnectionState.connected,
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
        statusDetail: status == RoomStatus.ended
            ? RoomStateStatusDetailEnded(
                EndedDetail(reason: endReason ?? EndReason.keeperEnded),
              )
            : const RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: const [],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

void main() {
  group('SessionDisconnectedScreen', () {
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
            getRecommendedSessionsProvider().overrideWith(
              (ref) => <SessionDetailSchema>[],
            ),
            spacesSummaryProvider.overrideWith(
              (ref) => throw UnimplementedError(),
            ),
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

    group('UI Rendering (Widget Tests)', () {
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

    group('Reason Resolution (Unit Tests)', () {
      test('returns movedToAnotherDevice when duplicateIdentity', () {
        final result = resolveDisconnectedReason(
          disconnectReason: DisconnectReason.duplicateIdentity,
          sessionState: _createEndedState(),
        );

        expect(result, SessionDisconnectedReason.movedToAnotherDevice);
      });

      test('duplicateIdentity takes priority over removed', () {
        final result = resolveDisconnectedReason(
          disconnectReason: DisconnectReason.duplicateIdentity,
          sessionState: _createEndedState(removed: true),
        );

        expect(result, SessionDisconnectedReason.movedToAnotherDevice);
      });

      test('returns removed when participant was removed', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(removed: true),
        );

        expect(result, SessionDisconnectedReason.removed);
      });

      test('removed takes priority over endReason', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(
            removed: true,
            endReason: EndReason.keeperAbsent,
          ),
        );

        expect(result, SessionDisconnectedReason.removed);
      });

      test('returns keeperAbsent when EndReason.keeperAbsent', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(endReason: EndReason.keeperAbsent),
        );

        expect(result, SessionDisconnectedReason.keeperAbsent);
      });

      test('returns roomEmpty when EndReason.roomEmpty', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(endReason: EndReason.roomEmpty),
        );

        expect(result, SessionDisconnectedReason.roomEmpty);
      });

      test('returns keeperEnded when EndReason.keeperEnded', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(endReason: EndReason.keeperEnded),
        );

        expect(result, SessionDisconnectedReason.keeperEnded);
      });

      test('returns keeperEnded for unrecognized EndReason values', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(
            endReason: EndReason.fromJson('some_unknown'),
          ),
        );

        expect(result, SessionDisconnectedReason.keeperEnded);
      });

      test('returns keeperEnded when sessionState is null', () {
        final result = resolveDisconnectedReason();

        expect(result, SessionDisconnectedReason.keeperEnded);
      });

      test('returns keeperEnded when room status is not ended', () {
        final result = resolveDisconnectedReason(
          sessionState: _createEndedState(status: RoomStatus.active),
        );

        expect(result, SessionDisconnectedReason.keeperEnded);
      });
    });

    group('App Review Logic (Unit Tests)', () {
      late MockSharedPreferences prefs;
      late MockInAppReview inAppReview;

      setUp(() {
        prefs = MockSharedPreferences();
        inAppReview = MockInAppReview();
      });

      test('does nothing if review already requested', () async {
        when(
          () => prefs.getBool(SessionDisconnectedScreen.reviewRequestedKey),
        ).thenReturn(true);

        await SessionDisconnectedScreen.incrementSessionLikedCount(
          prefs: prefs,
          inAppReview: inAppReview,
        );

        verifyNever(
          () => prefs.setInt(
            SessionDisconnectedScreen.sessionLikedCountKey,
            any(),
          ),
        );
        verifyNever(() => inAppReview.requestReview());
      });

      test(
        'increments count and does not request review if count < 5',
        () async {
          when(
            () => prefs.getBool(SessionDisconnectedScreen.reviewRequestedKey),
          ).thenReturn(false);
          when(
            () => prefs.getInt(SessionDisconnectedScreen.sessionLikedCountKey),
          ).thenReturn(2);
          when(
            () =>
                prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 3),
          ).thenAnswer((_) async => true);

          await SessionDisconnectedScreen.incrementSessionLikedCount(
            prefs: prefs,
            inAppReview: inAppReview,
          );

          verify(
            () =>
                prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 3),
          ).called(1);
          verifyNever(() => inAppReview.requestReview());
        },
      );

      test('requests review and sets key when count reaches 5', () async {
        when(
          () => prefs.getBool(SessionDisconnectedScreen.reviewRequestedKey),
        ).thenReturn(false);
        when(
          () => prefs.getInt(SessionDisconnectedScreen.sessionLikedCountKey),
        ).thenReturn(4);
        when(
          () => prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 5),
        ).thenAnswer((_) async => true);
        when(
          () =>
              prefs.setBool(SessionDisconnectedScreen.reviewRequestedKey, true),
        ).thenAnswer((_) async => true);

        when(() => inAppReview.isAvailable()).thenAnswer((_) async => true);
        when(
          () => inAppReview.requestReview(),
        ).thenAnswer((_) async => Future.value());

        await SessionDisconnectedScreen.incrementSessionLikedCount(
          prefs: prefs,
          inAppReview: inAppReview,
        );

        verify(
          () => prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 5),
        ).called(1);
        verify(() => inAppReview.isAvailable()).called(1);
        verify(() => inAppReview.requestReview()).called(1);
        verify(
          () =>
              prefs.setBool(SessionDisconnectedScreen.reviewRequestedKey, true),
        ).called(1);
      });

      test('does not request review if not available', () async {
        when(
          () => prefs.getBool(SessionDisconnectedScreen.reviewRequestedKey),
        ).thenReturn(false);
        when(
          () => prefs.getInt(SessionDisconnectedScreen.sessionLikedCountKey),
        ).thenReturn(4);
        when(
          () => prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 5),
        ).thenAnswer((_) async => true);

        when(() => inAppReview.isAvailable()).thenAnswer((_) async => false);

        await SessionDisconnectedScreen.incrementSessionLikedCount(
          prefs: prefs,
          inAppReview: inAppReview,
        );

        verify(
          () => prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 5),
        ).called(1);
        verify(() => inAppReview.isAvailable()).called(1);
        verifyNever(() => inAppReview.requestReview());
        verifyNever(
          () =>
              prefs.setBool(SessionDisconnectedScreen.reviewRequestedKey, true),
        );
      });

      test('handles errors silently', () async {
        when(
          () => prefs.getBool(SessionDisconnectedScreen.reviewRequestedKey),
        ).thenReturn(false);
        when(
          () => prefs.getInt(SessionDisconnectedScreen.sessionLikedCountKey),
        ).thenReturn(4);
        when(
          () => prefs.setInt(SessionDisconnectedScreen.sessionLikedCountKey, 5),
        ).thenAnswer((_) async => true);

        when(() => inAppReview.isAvailable()).thenAnswer((_) async => true);
        when(
          () => inAppReview.requestReview(),
        ).thenThrow(Exception('Simulated error'));

        // Should not throw
        await SessionDisconnectedScreen.incrementSessionLikedCount(
          prefs: prefs,
          inAppReview: inAppReview,
        );

        verify(() => inAppReview.requestReview()).called(1);
        // setBool should NOT be called if it threw before
        verifyNever(
          () =>
              prefs.setBool(SessionDisconnectedScreen.reviewRequestedKey, true),
        );
      });
    });
  });
}

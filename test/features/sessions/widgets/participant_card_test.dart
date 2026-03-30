// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, logger;
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/auth/models/auth_state.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/widgets/participant_card.dart';
import 'package:totem_app/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../controllers/core/session_controller_mock.dart';
import '../livekit_mocks.dart';

class FakeTrackEventsListener extends MockTrackEventsListener {
  void Function(TrackEvent)? capturedListener;

  @override
  CancelListenFunc listen(void Function(TrackEvent event) listener) {
    capturedListener = listener;
    return () async {};
  }
}

void main() {
  late MockRemoteParticipant remoteParticipant;
  late FakeSessionController fakeSessionState;

  setUpAll(() {
    registerFallbackValue(VideoQuality.HIGH);
    registerFallbackValue(GlobalKey());
  });

  setUp(() {
    remoteParticipant = MockRemoteParticipant('user-2', 'John Doe');
    fakeSessionState = FakeSessionController();

    when(
      () => remoteParticipant.createListener(),
    ).thenReturn(MockParticipantEventsListener());
  });

  Future<void> pumpWidget(
    WidgetTester tester, {
    required Widget child,
    required AuthState authState,
    List<Object?> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(authState),
          ),
          ...overrides.cast(),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
  }

  group('ParticipantCard', () {
    testWidgets('renders participant properties and smart name', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            fakeSessionState.mockState,
          ),
        ],
        child: ParticipantCard(
          participant: remoteParticipant,
          session: null,
          participantIdentity: remoteParticipant.identity,
        ),
      );

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.byType(SpeakingIndicatorOrEmoji), findsOneWidget);
    });

    testWidgets(
      'does NOT show participant control button if currentUser is NOT Keeper',
      (tester) async {
        final authState = AuthState.authenticated(
          user: UserSchema(
            email: 'user@example.com',
            name: 'Normal User',
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime.now(),
          ),
        );

        await pumpWidget(
          tester,
          authState: authState,
          overrides: [
            currentSessionStateProvider.overrideWithValue(
              fakeSessionState.mockState,
            ),
          ],
          child: ParticipantCard(
            participant: remoteParticipant,
            session: null,
            participantIdentity: remoteParticipant.identity,
          ),
        );

        expect(find.byType(ParticipantControlButton), findsNothing);
      },
    );

    testWidgets('shows keeper shield icon if participant is keeper', (
      tester,
    ) async {
      final keeperParticipant = MockRemoteParticipant('keeper-1', 'The Keeper');
      when(
        keeperParticipant.createListener,
      ).thenReturn(MockParticipantEventsListener());

      // Add keeper-1 as keeper to the room state
      fakeSessionState.mockState = SessionRoomState(
        connection: fakeSessionState.mockState.connection,
        chat: fakeSessionState.mockState.chat,
        participants: fakeSessionState.mockState.participants,
        turn: const SessionTurnState(
          roomState: RoomState(
            keeper: 'keeper-1',
            nextSpeaker: 'user-2',
            currentSpeaker: 'user-1',
            status: RoomStatus.waitingRoom,
            turnState: TurnState.idle,
            sessionSlug: 'test-session',
            statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
            talkingOrder: [],
            version: 1,
            roundNumber: 1,
          ),
        ),
      );

      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            fakeSessionState.mockState,
          ),
        ],
        child: ParticipantCard(
          participant: keeperParticipant,
          session: null,
          participantIdentity: keeperParticipant.identity,
        ),
      );

      expect(find.byType(TotemIconLogo), findsOneWidget);
    });
  });

  group('FeaturedParticipantCard', () {
    testWidgets('shows waiting room when session has no keeper', (
      tester,
    ) async {
      // By default FakeSessionController sets waitingRoom status but leaves keeper null?
      // Wait, _createRoomState has keeper: 'keeper-1'. Let's set it to null.
      fakeSessionState.mockState = SessionRoomState(
        connection: fakeSessionState.mockState.connection,
        chat: fakeSessionState.mockState.chat,
        participants: fakeSessionState.mockState.participants,
        turn: const SessionTurnState(
          roomState: RoomState(
            keeper: '',
            nextSpeaker: 'user-2',
            currentSpeaker: 'user-1',
            status: RoomStatus.waitingRoom,
            turnState: TurnState.idle,
            sessionSlug: 'test-session',
            statusDetail: RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
            talkingOrder: [],
            version: 1,
            roundNumber: 1,
          ),
        ),
      );

      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            fakeSessionState.mockState,
          ),
        ],
        child: const FeaturedParticipantCard(),
      );

      expect(find.text('Waiting room'), findsOneWidget);
      expect(find.byType(TotemIcon), findsOneWidget); // clock icon
    });
  });

  group('ParticipantVideo', () {
    testWidgets('updates video quality when requested', (tester) async {
      final mockParticipant = MockRemoteParticipant('user-2', 'John Doe');
      final mockPublication = MockRemoteTrackPublication();
      final mockTrack = MockRemoteVideoTrack();

      when(
        () => mockParticipant.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(mockPublication);
      when(
        mockParticipant.createListener,
      ).thenReturn(MockParticipantEventsListener());

      when(() => mockPublication.track).thenReturn(mockTrack);
      when(() => mockPublication.source).thenReturn(TrackSource.camera);
      when(() => mockPublication.sid).thenReturn('pub-sid');
      when(() => mockPublication.videoQuality).thenReturn(VideoQuality.HIGH);
      when(
        () => mockPublication.setVideoQuality(any()),
      ).thenAnswer((_) async {});
      when(() => mockPublication.subscribed).thenReturn(true);
      when(() => mockPublication.muted).thenReturn(false);

      when(mockTrack.createListener).thenReturn(MockTrackEventsListener());
      when(() => mockTrack.sid).thenReturn('track-sid');
      when(() => mockTrack.isActive).thenReturn(true);
      when(() => mockTrack.muted).thenReturn(false);
      when(mockTrack.addViewKey).thenReturn(GlobalKey());
      when(() => mockTrack.removeViewKey(any<GlobalKey>())).thenAnswer((_) {});

      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            fakeSessionState.mockState,
          ),
        ],
        child: ParticipantVideo(
          participant: mockParticipant,
          preferredVideoQuality: VideoQuality.HIGH,
        ),
      );

      await tester.pump(const Duration(milliseconds: 400));

      verify(
        () => mockPublication.setVideoQuality(VideoQuality.HIGH),
      ).called(greaterThan(0));
    });

    testWidgets('hides track when connection is lost (isTrackInactive)', (
      tester,
    ) async {
      final mockParticipant = MockRemoteParticipant('user-2', 'John Doe');
      final mockPublication = MockRemoteTrackPublication();
      final mockTrack = MockRemoteVideoTrack();

      when(
        () => mockParticipant.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(mockPublication);
      when(
        mockParticipant.createListener,
      ).thenReturn(MockParticipantEventsListener());

      when(() => mockPublication.track).thenReturn(mockTrack);
      when(() => mockPublication.source).thenReturn(TrackSource.camera);
      when(() => mockPublication.sid).thenReturn('pub-sid');
      when(() => mockPublication.videoQuality).thenReturn(VideoQuality.HIGH);
      when(
        () => mockPublication.setVideoQuality(any()),
      ).thenAnswer((_) async {});
      when(() => mockPublication.subscribed).thenReturn(true);
      when(() => mockPublication.muted).thenReturn(false);

      final trackListener = FakeTrackEventsListener();
      when(mockTrack.createListener).thenReturn(trackListener);
      when(() => mockTrack.sid).thenReturn('track-sid');
      when(() => mockTrack.isActive).thenReturn(true);
      when(() => mockTrack.muted).thenReturn(false);
      when(mockTrack.addViewKey).thenReturn(GlobalKey());
      when(() => mockTrack.removeViewKey(any<GlobalKey>())).thenAnswer((_) {});

      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            fakeSessionState.mockState,
          ),
        ],
        child: ParticipantVideo(
          participant: mockParticipant,
          preferredVideoQuality: VideoQuality.HIGH,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(VideoTrackRenderer), findsOneWidget);

      final event = MockVideoReceiverStatsEvent();
      when(() => event.currentBitrate).thenReturn(5);
      trackListener.capturedListener?.call(event);

      await tester.pumpAndSettle();

      expect(find.byType(VideoTrackRenderer), findsNothing);
    });
  });
}

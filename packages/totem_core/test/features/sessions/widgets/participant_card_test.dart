import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, logger;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/participant_card.dart';
import 'package:totem_core/features/sessions/widgets/participant_control_button.dart';
import 'package:totem_core/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/totem_icon.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../controllers/core/session_controller_mock.dart';
import '../livekit_mocks.dart';

void main() {
  late MockRemoteParticipant remoteParticipant;
  late FakeSessionController fakeSessionState;

  late VoidCallback restoreWebRtcChannels;

  setUpAll(() {
    registerFallbackValue(GlobalKey());
    restoreWebRtcChannels = stubFlutterWebRtcChannels();
  });

  tearDownAll(() {
    restoreWebRtcChannels();
  });

  setUp(() {
    remoteParticipant = MockRemoteParticipant('user-2', 'John Doe');
    fakeSessionState = FakeSessionController();
  });

  Future<void> pumpWidget(
    WidgetTester tester, {
    required Widget child,
    required AuthState authState,
    List<Object?> overrides = const [],
    Size? viewSize,
  }) async {
    if (viewSize != null) {
      tester.view.physicalSize = viewSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuthController(authState),
          ),
          userProfileProvider.overrideWith(
            (ref, slug) => Future.value(
              PublicUserSchema(
                slug: slug,
                name: 'Mocked User $slug',
                profileAvatarType: ProfileAvatarTypeEnum.td,
                circleCount: 0,
                dateCreated: DateTime.now(),
              ),
            ),
          ),
          ...overrides.cast(),
        ],
        child: MaterialApp(
          home: Scaffold(body: RepaintBoundary(child: child)),
        ),
      ),
    );
  }

  PositionedDirectional overlayPosition(WidgetTester tester) {
    return tester.widget<PositionedDirectional>(
      find
          .ancestor(
            of: find.byType(SpeakingIndicatorOrEmoji),
            matching: find.byType(PositionedDirectional),
          )
          .first,
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

      check(tester.widgetList(find.text('John Doe'))).length.equals(1);
      check(
        tester.widgetList(find.byType(SpeakingIndicatorOrEmoji)),
      ).length.equals(1);
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

        check(
          tester.widgetList(find.byType(ParticipantControlButton)),
        ).length.equals(0);
      },
    );

    testWidgets('shows keeper shield icon if participant is keeper', (
      tester,
    ) async {
      final keeperParticipant = MockRemoteParticipant('keeper-1', 'The Keeper');

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

      check(tester.widgetList(find.byType(TotemIconLogo))).length.equals(1);
    });

    testWidgets('keeps compact corner chrome on phone-sized windows', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        viewSize: const Size(400, 800),
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

      check(
        tester.getSize(find.byType(SpeakingIndicatorOrEmoji)),
      ).equals(const Size(20, 20));
      check(overlayPosition(tester).top).equals(10);
      check(overlayPosition(tester).start).equals(10);
    });

    testWidgets('uses larger corner chrome on desktop-class windows', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        viewSize: const Size(1200, 900),
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

      check(
        tester.getSize(find.byType(SpeakingIndicatorOrEmoji)),
      ).equals(const Size(40, 40));
      check(overlayPosition(tester).top).equals(12);
      check(overlayPosition(tester).start).equals(12);
    });

    testWidgets('scales the keeper logo badge on desktop-class windows', (
      tester,
    ) async {
      final keeperParticipant = MockRemoteParticipant('keeper-1', 'The Keeper');

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
        viewSize: const Size(1200, 900),
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

      check(
        tester.widget<TotemIconLogo>(find.byType(TotemIconLogo)).size,
      ).equals(22);
      check(
        tester.getSize(find.byType(TotemIconLogo)),
      ).equals(const Size(22, 22));
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

      check(tester.widgetList(find.text('Waiting room'))).length.equals(1);
      check(
        tester.widgetList(find.byType(TotemIcon)),
      ).length.equals(1); // clock icon
    });

    testWidgets('keeps 24dp overlay badges on phone-sized windows', (
      tester,
    ) async {
      final speaker = MockRemoteParticipant('user-1', 'Jane Doe');
      when(
        () => speaker.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(null);
      when(
        () => speaker.getTrackPublicationBySource(TrackSource.microphone),
      ).thenReturn(null);
      fakeSessionState.mockState = SessionRoomState(
        connection: fakeSessionState.mockState.connection,
        chat: fakeSessionState.mockState.chat,
        participants: ParticipantsState(participants: [speaker]),
        turn: const SessionTurnState(
          roomState: RoomState(
            keeper: 'keeper-1',
            nextSpeaker: 'user-2',
            currentSpeaker: 'user-1',
            status: RoomStatus.active,
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
        viewSize: const Size(400, 800),
        authState: AuthState.unauthenticated(),
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            fakeSessionState.mockState,
          ),
        ],
        child: const FeaturedParticipantCard(),
      );

      check(
        tester.getSize(find.byType(SpeakingIndicatorOrEmoji)),
      ).equals(const Size(24, 24));
      final decoration = tester
          .widget<Container>(
            find.descendant(
              of: find.byType(SpeakingIndicatorOrEmoji),
              matching: find.byType(Container),
            ),
          )
          .decoration;
      check(decoration).isA<BoxDecoration>();
      check(
        (decoration! as BoxDecoration).boxShadow!,
      ).deepEquals(kElevationToShadow[6]!);
    });

    testWidgets('uses keeper timers to send a private reminder', (
      tester,
    ) async {
      final speaker = MockRemoteParticipant('user-1', 'Jane Doe');
      when(
        () => speaker.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(null);
      when(
        () => speaker.getTrackPublicationBySource(TrackSource.microphone),
      ).thenReturn(null);
      final keeper = MockLocalParticipant('keeper-1');
      when(
        () => keeper.publishData(
          any(),
          reliable: true,
          destinationIdentities: const ['user-1'],
          topic: SessionCommunicationTopics.shareTimeReminder.topic,
        ),
      ).thenAnswer((_) async {});
      final semantics = tester.ensureSemantics();
      fakeSessionState
        ..isCurrentUserKeeperValue = true
        ..mockRoom = FakeRoom(keeper)
        ..mockState = SessionRoomState(
          connection: fakeSessionState.mockState.connection,
          chat: fakeSessionState.mockState.chat,
          participants: ParticipantsState(participants: [speaker]),
          turn: const SessionTurnState(
            roomState: RoomState(
              keeper: 'keeper-1',
              nextSpeaker: 'user-2',
              currentSpeaker: 'user-1',
              status: RoomStatus.active,
              turnState: TurnState.idle,
              sessionSlug: 'test-session',
              statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
              talkingOrder: ['user-1', 'user-2'],
              version: 1,
              roundNumber: 1,
            ),
          ),
          turnStartedAt: DateTime.now(),
        );

      await pumpWidget(
        tester,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'keeper@example.com',
            name: 'Keeper',
            slug: 'keeper-1',
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime.now(),
          ),
        ),
        overrides: [
          currentSessionProvider.overrideWithValue(fakeSessionState),
          currentSessionStateProvider.overrideWithValue(
            fakeSessionState.mockState,
          ),
        ],
        child: const FeaturedParticipantCard(),
      );

      await tester.tap(
        find.bySemanticsLabel(RegExp('Send a private share time reminder')),
      );
      await tester.pump();

      verify(
        () => keeper.publishData(
          any(),
          reliable: true,
          destinationIdentities: const ['user-1'],
          topic: SessionCommunicationTopics.shareTimeReminder.topic,
        ),
      ).called(1);

      await pumpWidget(
        tester,
        authState: AuthState.authenticated(
          user: UserSchema(
            email: 'keeper@example.com',
            name: 'Keeper',
            slug: 'keeper-1',
            profileAvatarType: ProfileAvatarTypeEnum.td,
            circleCount: 0,
            dateCreated: DateTime.now(),
          ),
        ),
        overrides: [
          currentSessionProvider.overrideWithValue(fakeSessionState),
          currentSessionStateProvider.overrideWithValue(
            fakeSessionState.mockState,
          ),
        ],
        child: ParticipantCard(
          participant: speaker,
          session: null,
          participantIdentity: speaker.identity,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(RegExp('Send a private share time reminder')),
      );
      await tester.pump();

      verify(
        () => keeper.publishData(
          any(),
          reliable: true,
          destinationIdentities: const ['user-1'],
          topic: SessionCommunicationTopics.shareTimeReminder.topic,
        ),
      ).called(1);
      semantics.dispose();
    });

    testWidgets('uses 40dp overlay badges on desktop-class windows', (
      tester,
    ) async {
      final speaker = MockRemoteParticipant('user-1', 'Jane Doe');
      when(
        () => speaker.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(null);
      when(
        () => speaker.getTrackPublicationBySource(TrackSource.microphone),
      ).thenReturn(null);
      fakeSessionState.mockState = SessionRoomState(
        connection: fakeSessionState.mockState.connection,
        chat: fakeSessionState.mockState.chat,
        participants: ParticipantsState(participants: [speaker]),
        turn: const SessionTurnState(
          roomState: RoomState(
            keeper: 'keeper-1',
            nextSpeaker: 'user-2',
            currentSpeaker: 'user-1',
            status: RoomStatus.active,
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
        viewSize: const Size(1200, 900),
        authState: AuthState.unauthenticated(),
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            fakeSessionState.mockState,
          ),
        ],
        child: const FeaturedParticipantCard(),
      );

      check(
        tester.getSize(find.byType(SpeakingIndicatorOrEmoji)),
      ).equals(const Size(40, 40));
    });
  });

  group('ParticipantVideo', () {
    testWidgets('hides track when muted', (tester) async {
      final mockParticipant = MockRemoteParticipant('user-2', 'John Doe');
      Future<void> show() {
        return pumpWidget(
          tester,
          authState: AuthState.unauthenticated(),
          overrides: [
            currentSessionStateProvider.overrideWithValue(
              fakeSessionState.mockState,
            ),
          ],
          child: ParticipantVideo(participant: mockParticipant),
        );
      }

      final mockPublication = MockRemoteTrackPublication<RemoteVideoTrack>();
      final mockTrack = MockRemoteVideoTrack();

      when(
        () => mockParticipant.getTrackPublicationBySource(TrackSource.camera),
      ).thenReturn(mockPublication);

      when(() => mockPublication.track).thenReturn(mockTrack);
      when(() => mockPublication.source).thenReturn(TrackSource.camera);
      when(() => mockPublication.sid).thenReturn('pub-sid');
      when(() => mockPublication.subscribed).thenReturn(true);
      when(() => mockPublication.muted).thenReturn(false);

      when(() => mockTrack.sid).thenReturn('track-sid');
      when(() => mockTrack.isActive).thenReturn(true);
      when(() => mockTrack.muted).thenReturn(false);

      await show();
      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.byType(VideoTrackRenderer)),
      ).length.equals(1);

      when(() => mockPublication.muted).thenReturn(true);
      when(() => mockTrack.muted).thenReturn(true);

      await show();
      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.byType(VideoTrackRenderer)),
      ).length.equals(0);
    });

    testWidgets('shows a camera track subscribed after the initial build', (
      tester,
    ) async {
      final participant = MockRemoteParticipant('user-2', 'John Doe');
      final publication = MockRemoteTrackPublication<RemoteVideoTrack>();
      final track = MockRemoteVideoTrack();
      RemoteTrackPublication<RemoteVideoTrack>? cameraPublication;

      when(
        () => participant.getTrackPublicationBySource(TrackSource.camera),
      ).thenAnswer((_) => cameraPublication);
      when(() => publication.track).thenReturn(track);
      when(() => publication.source).thenReturn(TrackSource.camera);
      when(() => publication.sid).thenReturn('pub-sid');
      when(() => publication.subscribed).thenReturn(true);
      when(() => publication.muted).thenReturn(false);
      when(() => track.sid).thenReturn('track-sid');
      when(() => track.isActive).thenReturn(true);
      when(() => track.muted).thenReturn(false);

      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            fakeSessionState.mockState,
          ),
        ],
        child: ParticipantVideo(participant: participant),
      );

      check(tester.widgetList(find.byType(VideoTrackRenderer))).isEmpty();

      cameraPublication = publication;
      participant.listener.emitParticipantEvent(
        TrackSubscribedEvent(
          participant: participant,
          publication: publication,
          track: track,
        ),
      );
      await tester.pump();

      check(
        tester.widgetList(find.byType(VideoTrackRenderer)),
      ).length.equals(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('ParticipantControlButton', () {
    testWidgets('closes menu when unmounted', (tester) async {
      // Use a StatefulWidget wrapper to toggle button visibility.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => FakeAuthController(AuthState.unauthenticated()),
            ),
            userProfileProvider.overrideWith(
              (ref, slug) => Future.value(
                PublicUserSchema(
                  slug: slug,
                  name: 'Mocked User $slug',
                  profileAvatarType: ProfileAvatarTypeEnum.td,
                  circleCount: 0,
                  dateCreated: DateTime.now(),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: _MenuCloseTestWrapper(participant: remoteParticipant),
            ),
          ),
        ),
      );

      // Tap the control button to open the menu.
      await tester.tap(find.byType(ParticipantControlButton));
      await tester.pumpAndSettle();

      // The menu should be visible.
      check(tester.widgetList(find.text('Remove'))).length.equals(1);
      check(tester.widgetList(find.text('Ban'))).length.equals(1);

      // Unmount the control button by toggling visibility.
      final _ = tester
          .state<_MenuCloseTestWrapperState>(find.byType(_MenuCloseTestWrapper))
          .hide();
      await tester.pumpAndSettle();

      // The menu should be gone.
      check(tester.widgetList(find.text('Remove'))).length.equals(0);
      check(tester.widgetList(find.text('Ban'))).length.equals(0);
    });

    testWidgets('uses a compact badge on phone-sized windows', (tester) async {
      await pumpWidget(
        tester,
        viewSize: const Size(400, 800),
        authState: AuthState.unauthenticated(),
        child: ParticipantControlButton(
          participant: remoteParticipant,
          menuVerticalOffset: 10,
        ),
      );

      check(
        tester.getSize(find.byType(ParticipantControlButton)),
      ).equals(const Size(20, 20));
      check(tester.widget<TotemIcon>(find.byType(TotemIcon)).size).equals(16);
    });

    testWidgets('uses a larger badge on desktop-class windows', (tester) async {
      await pumpWidget(
        tester,
        viewSize: const Size(1200, 900),
        authState: AuthState.unauthenticated(),
        child: ParticipantControlButton(
          participant: remoteParticipant,
          menuVerticalOffset: 12,
        ),
      );

      check(
        tester.getSize(find.byType(ParticipantControlButton)),
      ).equals(const Size(40, 40));
      check(tester.widget<TotemIcon>(find.byType(TotemIcon)).size).equals(22);
    });
  });
}

class _MenuCloseTestWrapper extends StatefulWidget {
  const _MenuCloseTestWrapper({required this.participant});

  final Participant participant;

  @override
  State<_MenuCloseTestWrapper> createState() => _MenuCloseTestWrapperState();
}

class _MenuCloseTestWrapperState extends State<_MenuCloseTestWrapper> {
  bool _visible = true;

  void hide() => setState(() => _visible = false);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _visible
          ? ParticipantControlButton(
              participant: widget.participant,
              menuVerticalOffset: 10,
            )
          : const SizedBox.shrink(),
    );
  }
}

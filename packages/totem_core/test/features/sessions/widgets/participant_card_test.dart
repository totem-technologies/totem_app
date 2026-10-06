import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, logger;
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/participant_card.dart';
import 'package:totem_core/features/sessions/widgets/participant_control_button.dart';
import 'package:totem_core/features/sessions/widgets/participant_overlay_metrics.dart';
import 'package:totem_core/features/sessions/widgets/speaking_indicator.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/totem_icon.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

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
                slug: Omittable(slug),
                name: Omittable('Mocked User $slug'),
                profileAvatarType: ProfileAvatarTypeEnum.td,
                circleCount: const Omittable(0),
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
            name: const Omittable('Normal User'),
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
            nextSpeaker: Omittable('user-2'),
            currentSpeaker: Omittable('user-1'),
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
            nextSpeaker: Omittable('user-2'),
            currentSpeaker: Omittable('user-1'),
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

    testWidgets('sizes overlay badges from the card on phone-sized windows', (
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
            nextSpeaker: Omittable('user-2'),
            currentSpeaker: Omittable('user-1'),
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
      ).equals(const Size(28, 28));
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

    testWidgets('caps overlay badges on desktop-class windows', (tester) async {
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
            nextSpeaker: Omittable('user-2'),
            currentSpeaker: Omittable('user-1'),
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
      ).equals(const Size(28, 28));
    });
  });

  group('LocalParticipantCard', () {
    testWidgets('keeps a local renderer mounted while the camera is covered', (
      tester,
    ) async {
      final cameraOn = ValueNotifier(true);
      final track = MockLocalVideoTrack();
      when(() => track.sid).thenReturn('local-track');
      addTearDown(cameraOn.dispose);

      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        child: ValueListenableBuilder<bool>(
          valueListenable: cameraOn,
          builder: (_, isCameraOn, _) =>
              LocalParticipantCard(isCameraOn: isCameraOn, videoTrack: track),
        ),
      );
      await tester.pumpAndSettle();
      final renderer = tester.element(find.byType(VideoTrackRenderer));

      cameraOn.value = false;
      await tester.pump();

      check(
        tester.element(find.byType(VideoTrackRenderer)),
      ).identicalTo(renderer);
      check(tester.widgetList(find.byType(UserAvatar))).length.equals(2);

      cameraOn.value = true;
      await tester.pump();

      check(
        tester.element(find.byType(VideoTrackRenderer)),
      ).identicalTo(renderer);
      check(tester.widgetList(find.byType(UserAvatar))).length.equals(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('ParticipantVideo', () {
    testWidgets('keeps a camera renderer mounted across mute transitions', (
      tester,
    ) async {
      final mockParticipant = MockRemoteParticipant('user-2', 'John Doe');
      final mockPublication = MockRemoteTrackPublication<RemoteVideoTrack>();
      final mockTrack = MockRemoteVideoTrack();
      final mutedEvent = MockTrackMutedEvent();
      final unmutedEvent = MockTrackUnmutedEvent();

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
      when(() => mutedEvent.publication).thenReturn(mockPublication);
      when(() => unmutedEvent.publication).thenReturn(mockPublication);

      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        overrides: [
          currentSessionStateProvider.overrideWithValue(
            fakeSessionState.mockState,
          ),
        ],
        child: ParticipantVideo(participant: mockParticipant),
      );
      await tester.pumpAndSettle();

      final renderer = tester.element(find.byType(VideoTrackRenderer));
      check(
        tester.widgetList(find.byType(VideoTrackRenderer)),
      ).length.equals(1);
      final visibleAvatarCount = tester
          .widgetList(find.byType(UserAvatar))
          .length;

      for (final event in [
        mutedEvent,
        unmutedEvent,
        mutedEvent,
        unmutedEvent,
      ]) {
        final isMuted = identical(event, mutedEvent);
        when(() => mockPublication.muted).thenReturn(isMuted);
        when(() => mockTrack.muted).thenReturn(isMuted);
        if (isMuted) {
          mockParticipant.listener.emitMuted(event as TrackMutedEvent);
        } else {
          mockParticipant.listener.emitUnmuted(event as TrackUnmutedEvent);
        }
        await tester.pump();

        check(
          tester.element(find.byType(VideoTrackRenderer)),
        ).identicalTo(renderer);
        check(
          tester.widgetList(find.byType(UserAvatar)),
        ).length.equals(visibleAvatarCount);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('replaces or removes the renderer when the track changes', (
      tester,
    ) async {
      final participant = MockRemoteParticipant('user-2', 'John Doe');
      final firstPublication = MockRemoteTrackPublication<RemoteVideoTrack>();
      final firstTrack = MockRemoteVideoTrack();
      final secondPublication = MockRemoteTrackPublication<RemoteVideoTrack>();
      final secondTrack = MockRemoteVideoTrack();
      RemoteTrackPublication<RemoteVideoTrack>? cameraPublication =
          firstPublication;

      when(
        () => participant.getTrackPublicationBySource(TrackSource.camera),
      ).thenAnswer((_) => cameraPublication);
      for (final entry in [
        (publication: firstPublication, track: firstTrack, sid: 'first'),
        (publication: secondPublication, track: secondTrack, sid: 'second'),
      ]) {
        when(() => entry.publication.track).thenReturn(entry.track);
        when(() => entry.publication.source).thenReturn(TrackSource.camera);
        when(() => entry.publication.sid).thenReturn('pub-${entry.sid}');
        when(() => entry.publication.subscribed).thenReturn(true);
        when(() => entry.publication.muted).thenReturn(false);
        when(() => entry.track.sid).thenReturn('track-${entry.sid}');
        when(() => entry.track.isActive).thenReturn(true);
        when(() => entry.track.muted).thenReturn(false);
      }

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
      await tester.pumpAndSettle();
      final firstRenderer = tester.element(find.byType(VideoTrackRenderer));

      cameraPublication = secondPublication;
      participant.listener.emitParticipantEvent(
        TrackSubscribedEvent(
          participant: participant,
          publication: secondPublication,
          track: secondTrack,
        ),
      );
      await tester.pumpAndSettle();

      check(
        tester.widgetList(find.byType(VideoTrackRenderer)),
      ).length.equals(1);
      check(
        tester.element(find.byType(VideoTrackRenderer)),
      ).not((it) => it.identicalTo(firstRenderer));

      cameraPublication = null;
      participant.listener.emitParticipantEvent(
        TrackUnpublishedEvent(
          participant: participant,
          publication: secondPublication,
        ),
      );
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(VideoTrackRenderer))).isEmpty();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'shows a locally published camera after the initial build',
      (tester) async {
        final participant = MockLocalParticipant();
        final publication = MockLocalTrackPublication();
        final track = MockLocalVideoTrack();
        LocalTrackPublication<LocalVideoTrack>? cameraPublication;

        when(
          () => participant.getTrackPublicationBySource(TrackSource.camera),
        ).thenAnswer((_) => cameraPublication);
        when(() => publication.track).thenReturn(track);
        when(() => publication.source).thenReturn(TrackSource.camera);
        when(() => publication.sid).thenReturn('local-pub-sid');
        when(() => publication.subscribed).thenReturn(true);
        when(() => publication.muted).thenReturn(false);
        when(() => track.sid).thenReturn('local-track-sid');
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
          LocalTrackPublishedEvent(
            participant: participant,
            publication: publication,
          ),
        );
        await tester.pumpAndSettle();

        check(
          tester.widgetList(find.byType(VideoTrackRenderer)),
        ).length.equals(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['RTCVideoRenderer'],
      ),
    );

    testWidgets(
      'shows a camera track subscribed after the initial build',
      (tester) async {
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
        await tester.pumpAndSettle();

        check(
          tester.widgetList(find.byType(VideoTrackRenderer)),
        ).length.equals(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['RTCVideoRenderer'],
      ),
    );
  });

  group('ParticipantControlButton', () {
    testWidgets('updates mute action when participant audio changes', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        child: _MenuCloseTestWrapper(participant: remoteParticipant),
      );

      await tester.tap(find.byType(ParticipantControlButton));
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Mute'))).length.equals(1);

      remoteParticipant.audioMuted = true;
      remoteParticipant.listener.emitMuted(MockTrackMutedEvent());
      await tester.pump();

      check(tester.widgetList(find.text('Muted'))).length.equals(1);
      final mutedButton = tester.widget<MenuItemButton>(
        find.ancestor(
          of: find.text('Muted'),
          matching: find.byType(MenuItemButton),
        ),
      );
      check(mutedButton.onPressed).isNull();

      remoteParticipant.audioMuted = false;
      remoteParticipant.listener.emitUnmuted(MockTrackUnmutedEvent());
      await tester.pump();

      check(tester.widgetList(find.text('Mute'))).length.equals(1);
      final unmutedButton = tester.widget<MenuItemButton>(
        find.ancestor(
          of: find.text('Mute'),
          matching: find.byType(MenuItemButton),
        ),
      );
      check(unmutedButton.onPressed).isNotNull();
    });

    testWidgets('closes menu when unmounted', (tester) async {
      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        child: _MenuCloseTestWrapper(participant: remoteParticipant),
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
              metrics: ParticipantOverlayMetrics.forCard(const Size(160, 120)),
            )
          : const SizedBox.shrink(),
    );
  }
}

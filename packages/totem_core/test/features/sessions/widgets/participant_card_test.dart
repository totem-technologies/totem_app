import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';
import 'package:totem_core/features/sessions/media/room_media_providers.dart';
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
import '../media/fake_room_media.dart';
import '../media/test_participants.dart';

void main() {
  final remoteParticipant = testParticipant('user-2', name: 'John Doe');
  late FakeSessionController fakeSessionState;
  late FakeRoomMedia roomMedia;

  setUp(() {
    fakeSessionState = FakeSessionController();
    roomMedia = FakeRoomMedia();
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
          roomMediaProvider.overrideWithValue(roomMedia),
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
        child: ParticipantCard(participant: remoteParticipant),
      );

      check(tester.widgetList(find.text('John Doe'))).length.equals(1);
      check(
        tester.widgetList(find.byType(SpeakingIndicatorOrEmoji)),
      ).length.equals(1);
    });

    testWidgets(
      'shows elapsed text only to a keeper while an active speaker is featured',
      (tester) async {
        final minuteElapsed = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(r'^01:\d{2}$').hasMatch(widget.data ?? ''),
          description: 'one-minute elapsed timer',
        );
        final turnStartedAt = DateTime.now().subtract(
          const Duration(minutes: 1, seconds: 5),
        );

        SessionRoomState stateFor(RoomStatus status) {
          return SessionRoomState(
            connection: fakeSessionState.mockState.connection,
            participants: ParticipantsState(participants: [remoteParticipant]),
            chat: const ChatState(),
            turn: SessionTurnState(
              roomState: RoomState(
                keeper: 'keeper-1',
                nextSpeaker: const Omittable(''),
                currentSpeaker: Omittable(remoteParticipant.identity),
                status: status,
                turnState: TurnState.idle,
                sessionSlug: 'test-session',
                statusDetail: const RoomStateStatusDetailWaitingRoom(
                  WaitingRoomDetail(),
                ),
                talkingOrder: const [],
                version: 1,
                roundNumber: 1,
              ),
            ),
            turnStartedAt: turnStartedAt,
          );
        }

        Future<void> pumpCard({
          required bool isKeeper,
          required RoomStatus status,
        }) {
          return pumpWidget(
            tester,
            viewSize: const Size(240, 180),
            authState: AuthState.unauthenticated(),
            overrides: [
              currentSessionStateProvider.overrideWithValue(stateFor(status)),
              isCurrentUserKeeperProvider.overrideWith((ref) => isKeeper),
            ],
            child: Center(
              child: SizedBox(
                width: 160,
                height: 120,
                child: ParticipantCard(participant: remoteParticipant),
              ),
            ),
          );
        }

        await pumpCard(isKeeper: true, status: RoomStatus.active);
        check(tester.widgetList(minuteElapsed)).length.equals(1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await pumpCard(isKeeper: false, status: RoomStatus.active);
        check(tester.widgetList(minuteElapsed)).length.equals(0);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await pumpCard(isKeeper: true, status: RoomStatus.waitingRoom);
        check(tester.widgetList(minuteElapsed)).length.equals(0);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

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
          child: ParticipantCard(participant: remoteParticipant),
        );

        check(
          tester.widgetList(find.byType(ParticipantControlButton)),
        ).length.equals(0);
      },
    );

    testWidgets('shows keeper shield icon if participant is keeper', (
      tester,
    ) async {
      final keeperParticipant = testParticipant('keeper-1', name: 'The Keeper');

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
        child: ParticipantCard(participant: keeperParticipant),
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
      final speaker = testParticipant('user-1', name: 'Jane Doe');
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

    testWidgets(
      'shows and clears a passive timer as keeper session state changes',
      (tester) async {
        final states = StreamController<SessionRoomState?>.broadcast();
        addTearDown(states.close);
        final sessionStateProvider = StreamProvider<SessionRoomState?>(
          (ref) => states.stream,
        );
        final keeper = testParticipant('keeper-1', name: 'The Keeper');
        final participant = testParticipant('user-1', name: 'Participant');
        final minuteElapsed = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(r'^01:\d{2}$').hasMatch(widget.data ?? ''),
          description: 'one-minute elapsed timer',
        );
        final secondElapsed = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(r'^00:\d{2}$').hasMatch(widget.data ?? ''),
          description: 'sub-minute elapsed timer',
        );

        SessionRoomState stateFor({
          required RoomConnectionState connectionState,
          required SessionPhase phase,
          required RoomStatus status,
          required DateTime turnStartedAt,
          String currentSpeaker = '',
        }) {
          return SessionRoomState(
            connection: fakeSessionState.mockState.connection.copyWith(
              state: connectionState,
              phase: phase,
            ),
            participants: ParticipantsState(
              participants: [keeper, participant],
            ),
            chat: const ChatState(),
            turn: SessionTurnState(
              roomState: RoomState(
                keeper: keeper.identity,
                nextSpeaker: const Omittable(''),
                currentSpeaker: Omittable(currentSpeaker),
                status: status,
                turnState: TurnState.idle,
                sessionSlug: 'test-session',
                statusDetail: const RoomStateStatusDetailWaitingRoom(
                  WaitingRoomDetail(),
                ),
                talkingOrder: const [],
                version: 1,
                roundNumber: 1,
              ),
            ),
            turnStartedAt: turnStartedAt,
          );
        }

        Future<void> pumpProviderUpdate() async {
          await tester.pump();
          await tester.pump();
        }

        await pumpWidget(
          tester,
          viewSize: const Size(240, 180),
          authState: AuthState.unauthenticated(),
          overrides: [
            currentSessionStateProvider.overrideWith((ref) {
              return ref
                  .watch(sessionStateProvider)
                  .when(
                    data: (state) => state,
                    error: (_, _) => null,
                    loading: () => null,
                  );
            }),
            isCurrentUserKeeperProvider.overrideWith((ref) => true),
          ],
          child: const FeaturedParticipantCard(),
        );

        states.add(
          stateFor(
            connectionState: RoomConnectionState.connected,
            phase: SessionPhase.connected,
            status: RoomStatus.active,
            turnStartedAt: DateTime.now().subtract(
              const Duration(minutes: 1, seconds: 5),
            ),
          ),
        );
        await pumpProviderUpdate();
        check(tester.widgetList(minuteElapsed)).length.equals(1);

        states.add(
          stateFor(
            connectionState: RoomConnectionState.connected,
            phase: SessionPhase.connected,
            status: RoomStatus.active,
            currentSpeaker: participant.identity,
            turnStartedAt: DateTime.now().subtract(const Duration(seconds: 2)),
          ),
        );
        await pumpProviderUpdate();
        check(tester.widgetList(minuteElapsed)).length.equals(0);
        check(tester.widgetList(secondElapsed)).length.equals(1);

        states.add(
          stateFor(
            connectionState: RoomConnectionState.disconnected,
            phase: SessionPhase.disconnected,
            status: RoomStatus.active,
            currentSpeaker: participant.identity,
            turnStartedAt: DateTime.now().subtract(const Duration(seconds: 2)),
          ),
        );
        await pumpProviderUpdate();
        check(tester.widgetList(secondElapsed)).length.equals(0);

        states.add(
          stateFor(
            connectionState: RoomConnectionState.connected,
            phase: SessionPhase.ended,
            status: RoomStatus.ended,
            currentSpeaker: participant.identity,
            turnStartedAt: DateTime.now().subtract(const Duration(seconds: 2)),
          ),
        );
        await pumpProviderUpdate();
        check(tester.widgetList(secondElapsed)).length.equals(0);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('caps overlay badges on desktop-class windows', (tester) async {
      final speaker = testParticipant('user-1', name: 'Jane Doe');
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

  group('ParticipantVideo', () {
    /// Whether an avatar paints above the participant's video. Children of a
    /// Stack paint in order, which matches element tree order.
    bool avatarCoversVideo(WidgetTester tester) {
      final elements = tester.allElements.toList();
      final video = elements.indexWhere((e) => e.widget is FakeVideoView);
      final lastAvatar = elements.lastIndexWhere((e) => e.widget is UserAvatar);
      return lastAvatar > video;
    }

    testWidgets('covers the video with the avatar while the camera is off', (
      tester,
    ) async {
      roomMedia.setMediaState(
        remoteParticipant.identity,
        const ParticipantMediaState(hasCamera: true),
      );
      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        child: ParticipantVideo(participant: remoteParticipant),
      );
      await tester.pump();
      final video = tester.element(find.byType(FakeVideoView));
      check(avatarCoversVideo(tester)).isTrue();

      roomMedia.setMediaState(
        remoteParticipant.identity,
        const ParticipantMediaState(hasCamera: true, isCameraOn: true),
      );
      await tester.pump();
      await tester.pump();

      check(avatarCoversVideo(tester)).isFalse();
      // The video stays mounted, so turning the camera on doesn't reload it.
      check(tester.element(find.byType(FakeVideoView))).identicalTo(video);
    });

    testWidgets('a camera that is already on shows from the first frame', (
      tester,
    ) async {
      roomMedia.setMediaState(
        remoteParticipant.identity,
        const ParticipantMediaState(hasCamera: true, isCameraOn: true),
      );

      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        child: ParticipantVideo(participant: remoteParticipant),
      );

      check(avatarCoversVideo(tester)).isFalse();
    });
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

      roomMedia.setMediaState(
        remoteParticipant.identity,
        const ParticipantMediaState(hasMicrophone: true, isMicrophoneOn: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ParticipantControlButton));
      await tester.pumpAndSettle();
      check(tester.widgetList(find.text('Mute'))).length.equals(1);

      roomMedia.setMediaState(
        remoteParticipant.identity,
        const ParticipantMediaState(hasMicrophone: true),
      );
      await tester.pumpAndSettle();

      check(tester.widgetList(find.text('Muted'))).length.equals(1);
      final mutedButton = tester.widget<MenuItemButton>(
        find.ancestor(
          of: find.text('Muted'),
          matching: find.byType(MenuItemButton),
        ),
      );
      check(mutedButton.onPressed).isNull();

      roomMedia.setMediaState(
        remoteParticipant.identity,
        const ParticipantMediaState(hasMicrophone: true, isMicrophoneOn: true),
      );
      await tester.pumpAndSettle();

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

  final ParticipantInfo participant;

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

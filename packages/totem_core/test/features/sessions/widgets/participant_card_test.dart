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
    testWidgets('draws the room media video over the participant avatar', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        authState: AuthState.unauthenticated(),
        child: ParticipantVideo(participant: remoteParticipant),
      );

      final video = tester.widget<FakeVideoView>(find.byType(FakeVideoView));
      check(video.participant).equals(remoteParticipant);
      final layers = tester
          .widget<Stack>(
            find
                .descendant(
                  of: find.byType(ParticipantVideo),
                  matching: find.byType(Stack),
                )
                .first,
          )
          .children;
      check(layers.length).equals(2);
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

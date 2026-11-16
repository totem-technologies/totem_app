import 'package:checks/checks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/consts.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_prompts_controller.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/speaking_turn_screen.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/action_slider_button.dart';
import 'package:totem_core/features/sessions/widgets/participant_card.dart';
import 'package:totem_core/features/sessions/widgets/session_keyboard_shortcuts.dart';

import '../../../auth/controllers/auth_controller_mock.dart';
import '../../../setup.dart';
import '../../permissions/fake_media_permission_adapter.dart';
import '../controllers/core/session_controller_mock.dart';
import '../controllers/features/session_device_controller_mock.dart';
import '../livekit_mocks.dart';
import '../media/test_participants.dart';
import '../session_test_fixtures.dart';
import '../session_test_mocks.dart';

class _TestSessionCuesService extends SessionCuesService {
  int swipePulseCount = 0;

  @override
  Future<void> pulseSwipeCompletion() async {
    swipePulseCount += 1;
  }

  @override
  Future<void> playSessionTransitionCue() async {}

  @override
  Future<void> playTotemReceivedCue() async {}

  @override
  void dispose() {}
}

/// A minimal [SessionDetailSchema] for testing.
SessionDetailSchema _createTestSession() {
  return SessionDetailSchema(
    slug: 'test-session',
    title: 'Test session',
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
      nextEvents: const [],
    ),
    content: '',
    seatsLeft: 10,
    duration: 60,
    start: DateTime(2024, 6, 1),
    attending: true,
    open: true,
    started: true,
    cancelled: false,
    joinable: true,
    ended: false,
    rsvpUrl: '',
    joinUrl: null,
    subscribeUrl: '',
    calLink: '',
    subscribed: false,
    userTimezone: null,
    meetingProvider: MeetingProviderEnum.livekit,
  );
}

ParticipantInfo _mockRemote(String id, String name) =>
    testParticipant(id, name: name);

List<ParticipantInfo> _buildParticipantsWithLocal(
  MockLocalParticipant localParticipant,
  int count,
) {
  final local = testParticipant(
    localParticipant.identity,
    name: localParticipant.name,
    isLocal: true,
  );
  if (count <= 1) return [local];

  return [
    local,
    ...List.generate(
      count - 1,
      (index) => _mockRemote('user-${index + 2}', 'User ${index + 2}'),
    ),
  ];
}

SessionRoomState _buildState({
  RoomStatus status = RoomStatus.active,
  TurnState turnState = TurnState.idle,
  String keeper = 'user-1',
  String currentSpeaker = 'user-1',
  String? nextSpeaker = 'user-2',
  List<ParticipantInfo>? participants,
  DateTime? turnStartedAt,
}) {
  final defaultParticipants =
      participants ??
      [
        _mockRemote('user-1', 'User One'),
        _mockRemote('user-2', 'User Two'),
        _mockRemote('user-3', 'User Three'),
      ];

  return SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.connected,
      state: RoomConnectionState.connected,
    ),
    participants: ParticipantsState(participants: defaultParticipants),

    turn: SessionTurnState(
      roomState: RoomState(
        keeper: keeper,
        nextSpeaker: Omittable(nextSpeaker ?? ''),
        currentSpeaker: Omittable(currentSpeaker),
        status: status,
        turnState: turnState,
        sessionSlug: 'test-session',
        statusDetail: status == RoomStatus.waitingRoom
            ? const RoomStateStatusDetailWaitingRoom(WaitingRoomDetail())
            : const RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: const [],
        version: 1,
        roundNumber: 1,
      ),
    ),
    turnStartedAt: turnStartedAt,
  );
}

void main() {
  late MockSessionController session;
  late MockSessionKeeperController keeper;
  late MockSessionDeviceController devices;
  late MockSessionMessagingController messaging;
  late MockLocalParticipant localParticipant;
  late FakeRoom room;

  setUpAll(() {
    setupAppConfig();
    registerFallbackValue(TrackSource.camera);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    session = MockSessionController();
    keeper = MockSessionKeeperController();
    devices = MockSessionDeviceController();
    messaging = MockSessionMessagingController();
    localParticipant = MockLocalParticipant('user-1');
    room = FakeRoom(localParticipant);

    when(() => session.room).thenReturn(room);
    when(() => session.keeper).thenReturn(keeper);
    when(() => session.devices).thenReturn(devices);
    when(() => session.messaging).thenReturn(messaging);
    when(() => session.options).thenReturn(testSessionOptions);
    when(() => session.isCurrentUserKeeper()).thenReturn(true);
    when(() => devices.isCameraEnabled).thenReturn(false);
    when(() => devices.isMicrophoneEnabled).thenReturn(false);
    when(() => devices.isSpeakerphoneEnabled).thenReturn(false);
    when(() => devices.selectedCameraDeviceId).thenReturn(null);
    when(() => devices.selectedAudioOutputDeviceId).thenReturn(null);
    when(
      () => devices.turnOn(MediaKind.microphone),
    ).thenAnswer((_) async => const TurnedOn());
    when(() => devices.disableMicrophone()).thenAnswer((_) async {});
    when(
      () => devices.turnOn(MediaKind.camera),
    ).thenAnswer((_) async => const TurnedOn());
    when(() => devices.disableCamera()).thenAnswer((_) async {});
    when(() => messaging.sendReaction(any())).thenAnswer((_) async {});

    when(
      () =>
          localParticipant.getTrackPublicationBySource(TrackSource.microphone),
    ).thenReturn(null);
    when(
      () => localParticipant.getTrackPublicationBySource(TrackSource.camera),
    ).thenReturn(null);
    when(() => localParticipant.isCameraEnabled()).thenReturn(false);
  });

  Future<void> pumpSpeakingTurn(
    WidgetTester tester, {
    required SessionRoomState sessionState,
    required bool isKeeper,
    SessionCuesService? cuesService,
    String? currentPrompt,
  }) async {
    when(() => session.isCurrentUserKeeper()).thenReturn(isKeeper);
    when(() => session.state).thenReturn(sessionState);
    final testCuesService = cuesService ?? _TestSessionCuesService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...grantedMediaPermissionOverrides(),
          authControllerProvider.overrideWith(
            () => FakeAuthController(testAuthenticatedState()),
          ),
          currentSessionStateProvider.overrideWithValue(sessionState),
          admittedSessionParticipantIdentitiesProvider.overrideWith(
            () => TestAdmittedSessionParticipantIdentities({
              sessionState.roomState.keeper,
              ...sessionState.participantsList.map(
                (participant) => participant.identity,
              ),
            }),
          ),
          currentSessionProvider.overrideWith((ref) => session),
          currentSessionPromptProvider.overrideWith((ref) => currentPrompt),
          sessionPromptsControllerProvider('test-session').overrideWithValue(
            const SessionPromptsState(
              snapshot: SessionPromptsSchema(revision: 0, prompts: []),
            ),
          ),
          sessionCuesServiceProvider.overrideWithValue(testCuesService),
          userProfileProvider.overrideWith((ref, slug) async {
            return PublicUserSchema(
              slug: Omittable(slug),
              name: Omittable('User $slug'),
              profileAvatarType: ProfileAvatarTypeEnum.td,
              dateCreated: DateTime(2024),
            );
          }),
          selfViewSettingsProvider.overrideWith(SelfViewSettings.new),
        ],
        child: MaterialApp(
          home: SessionKeyboardShortcuts(
            child: Scaffold(
              body: SpeakingTurnScreen(session: _createTestSession()),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
  }

  group('SpeakingTurn', () {
    Future<void> runOnDesktop(AsyncCallback body) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    testWidgets(
      'keeps every participant visible without overlapping controls at grid boundaries',
      (tester) async {
        for (final participantCount in [1, 7, 12]) {
          final state = _buildState(
            keeper: 'user-1',
            currentSpeaker: 'speaker-0',
            nextSpeaker: 'user-2',
            participants: _buildParticipantsWithLocal(
              localParticipant,
              participantCount,
            ),
          );

          await pumpSpeakingTurn(tester, sessionState: state, isKeeper: true);

          final cards = tester.widgetList<ParticipantCard>(
            find.byType(ParticipantCard),
          );
          check(
            cards.map((card) => card.participant.identity).toSet(),
          ).deepEquals(
            state.participantsList
                .map((participant) => participant.identity)
                .toSet(),
          );
          final controls = tester.getRect(find.byType(SessionActionBar));
          final bounds =
              Offset.zero &
              (tester.view.physicalSize / tester.view.devicePixelRatio);
          final rects = [
            for (final card in cards) tester.getRect(find.byWidget(card)),
          ];
          for (var index = 0; index < rects.length; index++) {
            final rect = rects[index];
            check(rect.width > 0 && rect.height > 0).isTrue();
            check(bounds.contains(rect.topLeft)).isTrue();
            check(
              rect.right <= bounds.right && rect.bottom <= bounds.bottom,
            ).isTrue();
            check(rect.overlaps(controls)).isFalse();
            for (final other in rects.skip(index + 1)) {
              check(rect.overlaps(other)).isFalse();
            }
          }
          check(tester.takeException()).isNull();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
    );

    testWidgets('action bar exposes controls and toggles mic/camera', (
      tester,
    ) async {
      final state = _buildState(
        keeper: 'user-1',
        currentSpeaker: 'user-1',
        nextSpeaker: 'user-2',
      );

      await pumpSpeakingTurn(tester, sessionState: state, isKeeper: true);

      check(
        tester.widgetList(find.bySemanticsLabel('Microphone off')),
      ).length.equals(1);
      check(
        tester.widgetList(find.bySemanticsLabel('Camera off')),
      ).length.equals(1);
      check(tester.widgetList(find.bySemanticsLabel('Chat'))).length.equals(1);
      check(
        tester.widgetList(find.bySemanticsLabel('Send reaction')),
      ).length.equals(0);

      await tester.tap(find.bySemanticsLabel('Microphone off'));
      await tester.pump();
      check(session.mockLocalMedia.microphoneCommands).deepEquals([true]);

      await tester.tap(find.bySemanticsLabel('Camera off'));
      await tester.pump();
      check(session.mockLocalMedia.cameraCommands).deepEquals([true]);
    });

    testWidgets('disables shortcuts while the prompt field is focused', (
      tester,
    ) async {
      await runOnDesktop(() async {
        final state = _buildState(
          keeper: 'user-1',
          currentSpeaker: 'user-1',
          nextSpeaker: 'user-2',
        );

        await pumpSpeakingTurn(tester, sessionState: state, isKeeper: true);

        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.pump();
        verify(() => devices.turnOn(MediaKind.microphone)).called(1);

        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();

        verifyNever(() => devices.turnOn(MediaKind.camera));
        verifyNever(() => messaging.sendReaction(any()));
      });
    });

    testWidgets(
      'passes the Totem with a trimmed round message',
      (tester) async {
        final state = _buildState(
          keeper: 'user-1',
          currentSpeaker: 'user-1',
          nextSpeaker: 'user-2',
        );
        final cuesService = _TestSessionCuesService();

        when(
          () => keeper.passTotem(customPrompt: 'A round message'),
        ).thenAnswer((_) async {});

        await pumpSpeakingTurn(
          tester,
          sessionState: state,
          isKeeper: true,
          cuesService: cuesService,
        );

        await tester.enterText(find.byType(TextField), '  A round message  ');
        await tester.drag(
          find.byKey(ActionSlider.thumbKey),
          const Offset(800, 0),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The confirmation dialog should now be visible.
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Pass to User Two'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => keeper.passTotem(customPrompt: 'A round message'),
        ).called(1);
        check(cuesService.swipePulseCount).equals(1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
      // auto_size_text's _checkTextFits allocates TextPainters without disposal
      // when the swipe label changes. The Totem-owned slider is unmounted above.
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );

    testWidgets(
      'a participant can pass without Keeper prompt controls',
      (tester) async {
        final state = _buildState(
          keeper: 'keeper-1',
          currentSpeaker: 'user-1',
          nextSpeaker: 'user-2',
        );

        when(() => keeper.passTotem()).thenAnswer((_) async {});
        await pumpSpeakingTurn(tester, sessionState: state, isKeeper: false);

        check(tester.widgetList(find.byType(TextField))).length.equals(0);
        await tester.drag(
          find.byKey(ActionSlider.thumbKey),
          const Offset(800, 0),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        verify(() => keeper.passTotem()).called(1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
      // auto_size_text's _checkTextFits allocates TextPainters without disposal
      // when the swipe label changes. The Totem-owned slider is unmounted above.
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );

    const longPrompt =
        'Think of a moment this week when you felt truly heard by someone, '
        'and share what they did that made the difference for you.';

    for (final (label, size, textScale) in [
      ('portrait phone', const Size(360, 740), 1.0),
      ('short landscape phone', const Size(667, 375), 1.0),
      ('short landscape phone at 1.5x text', const Size(667, 375), 1.5),
    ]) {
      for (final isKeeper in [true, false]) {
        testWidgets(
          'keeps the ${isKeeper ? 'keeper' : 'speaker'} pass slider on a $label',
          (tester) async {
            tester.view
              ..physicalSize = size
              ..devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            tester.platformDispatcher.textScaleFactorTestValue = textScale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final state = _buildState(
              keeper: isKeeper ? 'user-1' : 'keeper-1',
              currentSpeaker: 'user-1',
              nextSpeaker: 'user-2',
            );

            await pumpSpeakingTurn(
              tester,
              sessionState: state,
              isKeeper: isKeeper,
              currentPrompt: longPrompt,
            );

            check(tester.takeException()).isNull();
            final slider = tester.getRect(find.byType(ActionSlider));
            check(slider.top).isGreaterOrEqual(0);
            check(slider.bottom).isLessOrEqual(size.height);
            check(slider.left).isGreaterOrEqual(0);
            check(slider.right).isLessOrEqual(size.width);
            check(
              slider.overlaps(tester.getRect(find.byType(SessionActionBar))),
            ).isFalse();
            check(
              find.byKey(ActionSlider.thumbKey).hitTestable().evaluate(),
            ).isNotEmpty();
          },
        );
      }
    }

    testWidgets('shows the waiting receive card while the totem is passing', (
      tester,
    ) async {
      final state = _buildState(
        keeper: 'user-1',
        currentSpeaker: 'user-1',
        nextSpeaker: 'user-2',
        turnState: TurnState.passing,
      );

      await pumpSpeakingTurn(tester, sessionState: state, isKeeper: true);

      check(
        tester.widgetList(
          find.textContaining('Waiting for the receiver to accept.'),
        ),
      ).length.equals(1);
      check(tester.widgetList(find.byType(TextField))).length.equals(0);
      check(tester.widgetList(find.byType(ActionSlider))).length.equals(0);
    });

    testWidgets(
      'SelfView Settings enables and persists',
      (tester) async {
        final state = _buildState(
          keeper: 'user-1',
          currentSpeaker: 'user-1',
          nextSpeaker: 'user-2',
        );

        await pumpSpeakingTurn(tester, sessionState: state, isKeeper: true);
        await tester.pumpAndSettle();

        check(
          find.bySemanticsLabel('Your self view, draggable').evaluate(),
        ).isEmpty();
        final container = tester.element(find.byType(SpeakingTurnScreen));
        final ref = ProviderScope.containerOf(container);

        ref.read(selfViewSettingsProvider.notifier).setEnabled(true);
        await tester.pumpAndSettle();

        check(
          find
              .bySemanticsLabel('Your self view, draggable')
              .hitTestable()
              .evaluate(),
        ).isNotEmpty();

        final prefs = await SharedPreferences.getInstance();
        check(prefs.getBool(AppConsts.storageSelfViewEnabledKey)).equals(true);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
      experimentalLeakTesting: LeakTesting.settings.withIgnored(
        classes: <String>['TextPainter'],
      ),
    );

    testWidgets('renders SelfView when enabled and handles dragging', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        AppConsts.storageSelfViewEnabledKey: true,
        AppConsts.storageSelfViewPositionKey: 'end',
      });

      final state = _buildState(
        keeper: 'user-1',
        currentSpeaker: 'user-1',
        nextSpeaker: 'user-2',
      );

      await pumpSpeakingTurn(tester, sessionState: state, isKeeper: true);
      await tester.pumpAndSettle();

      check(tester.widgetList(find.byType(SelfView))).length.equals(1);

      final cardFinder = find.bySemanticsLabel('Your self view, draggable');
      final initialOffset = tester.getTopLeft(cardFinder);
      check(initialOffset.dx).isGreaterThan(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
      );

      await tester.drag(cardFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();

      final newOffset = tester.getTopLeft(cardFinder);
      check(newOffset.dx).isLessThan(initialOffset.dx);
      check(newOffset.dx).isGreaterOrEqual(0);

      final prefs = await SharedPreferences.getInstance();
      check(
        prefs.getString(AppConsts.storageSelfViewPositionKey),
      ).equals('start');

      // Drag back past the midpoint
      await tester.drag(cardFinder, const Offset(500, 0));
      await tester.pumpAndSettle();

      final backOffset = tester.getTopLeft(cardFinder);
      check(backOffset.dx).isGreaterThan(newOffset.dx);
      check(tester.getRect(cardFinder).right).isLessOrEqual(
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
      );
      check(
        prefs.getString(AppConsts.storageSelfViewPositionKey),
      ).equals('end');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}

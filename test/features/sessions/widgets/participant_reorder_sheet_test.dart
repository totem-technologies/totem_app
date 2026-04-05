import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_app/features/sessions/widgets/participant_reorder_sheet.dart';

import '../livekit_mocks.dart';

class MockSessionController extends Mock implements SessionController {}

class MockSessionKeeperController extends Mock
    implements SessionKeeperController {}

SessionDetailSchema _createSessionEvent() {
  return SessionDetailSchema(
    slug: 'test-session',
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
      nextEvents: const [],
    ),
    content: '',
    seatsLeft: 10,
    duration: 60,
    start: DateTime(2024, 1, 1, 10),
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

MockRemoteParticipant _mockRemote(String id, String name) {
  final participant = MockRemoteParticipant(id, name);
  when(participant.createListener).thenReturn(MockParticipantEventsListener());
  when(() => participant.getTrackPublicationBySource(any())).thenReturn(null);
  return participant;
}

SessionRoomState _buildState() {
  final participants = [
    _mockRemote('keeper-1', 'Keeper'),
    _mockRemote('user-1', 'User One'),
    _mockRemote('user-2', 'User Two'),
    _mockRemote('user-3', 'User Three'),
  ];

  return SessionRoomState(
    connection: const ConnectionState(
      phase: SessionPhase.connected,
      state: RoomConnectionState.connected,
    ),
    participants: ParticipantsState(participants: participants),
    chat: const ChatState(),
    turn: const SessionTurnState(
      roomState: RoomState(
        keeper: 'keeper-1',
        nextSpeaker: 'user-1',
        currentSpeaker: 'keeper-1',
        status: RoomStatus.active,
        turnState: TurnState.idle,
        sessionSlug: 'test-session',
        statusDetail: RoomStateStatusDetailActive(ActiveDetail()),
        talkingOrder: ['keeper-1', 'user-1', 'user-2', 'user-3'],
        version: 1,
        roundNumber: 1,
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(TrackSource.camera);
    registerFallbackValue(<String>[]);
  });

  testWidgets('save sends reordered identities with keeper first', (
    tester,
  ) async {
    final session = MockSessionController();
    final keeper = MockSessionKeeperController();
    final state = _buildState();
    final event = _createSessionEvent();

    when(() => session.keeper).thenReturn(keeper);
    when(() => keeper.reorder(any())).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ParticipantReorderWidget(
              session: session,
              state: state,
              event: event,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Reorder Participants'), findsOneWidget);

    final handle = find.byType(ReorderableDragStartListener).at(3);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final captured =
        verify(() => keeper.reorder(captureAny())).captured.single
            as List<String>;

    expect(captured.first, 'keeper-1');
    expect(captured.toSet(), {'keeper-1', 'user-1', 'user-2', 'user-3'});
    expect(captured, isNot(equals(['keeper-1', 'user-1', 'user-2', 'user-3'])));
  });
}

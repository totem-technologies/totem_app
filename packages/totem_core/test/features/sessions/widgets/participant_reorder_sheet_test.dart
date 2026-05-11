import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:mocktail/mocktail.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/widgets/participant_reorder_modal.dart';

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
    final event = _createSessionEvent();

    when(() => session.keeper).thenReturn(keeper);
    when(() => keeper.reorder(any())).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ParticipantReorderWidget(event: event),
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

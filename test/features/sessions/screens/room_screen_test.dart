import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/room_screen.dart';

SessionDetailSchema _createSessionEvent({
  required DateTime start,
  required int duration,
  bool ended = false,
}) {
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
    duration: duration,
    start: start,
    attending: true,
    open: true,
    started: true,
    cancelled: false,
    joinable: true,
    ended: ended,
    rsvpUrl: '',
    joinUrl: null,
    subscribeUrl: '',
    calLink: '',
    subscribed: false,
    userTimezone: null,
    meetingProvider: MeetingProviderEnum.livekit,
  );
}

Future<void> _pumpRoomScreen(
  WidgetTester tester, {
  required SessionDetailSchema event,
  required RoomConnectionState connectionState,
  required RoomStatus roomStatus,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentSessionProvider.overrideWith((ref) => null),
        currentSessionEventProvider.overrideWith((ref) => event),
        resolveCurrentScreenProvider.overrideWith((ref) => RoomScreen.loading),
        connectionStateProvider.overrideWith((ref) => connectionState),
        roomStatusProvider.overrideWith((ref) => roomStatus),
        disconnectionReasonProvider.overrideWith((ref) => null),
      ],
      child: const MaterialApp(
        home: VideoRoomScreen(
          sessionSlug: 'test-session',
          loadingScreen: SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('VideoRoomScreen - 5 minute warning', () {
    testWidgets('shows the warning popup when 5 minutes remain', (
      tester,
    ) async {
      final now = DateTime.now();
      final event = _createSessionEvent(
        start: now.subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreen(
        tester,
        event: event,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.active,
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Time Remaining 5 min'), findsOneWidget);
      expect(
        find.text('Thanks for your participation in this session today'),
        findsOneWidget,
      );
    });

    testWidgets('does not show the warning when room is not active', (
      tester,
    ) async {
      final now = DateTime.now();
      final event = _createSessionEvent(
        start: now.subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreen(
        tester,
        event: event,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.waitingRoom,
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Time Remaining 5 min'), findsNothing);
      expect(
        find.text('Thanks for your participation in this session today'),
        findsNothing,
      );
    });

    testWidgets('shows the warning only once for the same session', (
      tester,
    ) async {
      final now = DateTime.now();
      final event = _createSessionEvent(
        start: now.subtract(const Duration(minutes: 5)),
        duration: 10,
      );

      await _pumpRoomScreen(
        tester,
        event: event,
        connectionState: RoomConnectionState.connected,
        roomStatus: RoomStatus.active,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Time Remaining 5 min'), findsOneWidget);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.text('Time Remaining 5 min'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Time Remaining 5 min'), findsNothing);
    });
  });
}

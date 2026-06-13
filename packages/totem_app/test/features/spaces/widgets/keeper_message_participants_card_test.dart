import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/features/spaces/widgets/keeper_message_participants_card.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/shared/router.dart';

SessionDetailSchema _mockSession() => SessionDetailSchema(
  slug: 'test-session',
  title: 'Test Session',
  space: MobileSpaceDetailSchema(
    slug: 'test-space',
    title: 'Test Space',
    imageLink: null,
    shortDescription: '',
    content: '',
    category: null,
    recurring: null,
    author: PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.td,
      dateCreated: DateTime(2024),
      name: 'Keeper',
      slug: 'keeper-slug',
      profileAvatarSeed: 'seed',
    ),
    subscribers: 0,
    price: 0,
    nextEvents: const [],
  ),
  content: '',
  seatsLeft: 5,
  duration: 60,
  start: DateTime(2025, 4, 2, 19),
  attending: false,
  open: true,
  started: false,
  cancelled: false,
  joinable: false,
  ended: false,
  rsvpUrl: '',
  joinUrl: null,
  subscribeUrl: '',
  calLink: '',
  subscribed: null,
  userTimezone: null,
  meetingProvider: MeetingProviderEnum.livekit,
);

void main() {
  Widget wrapCard() {
    final session = _mockSession();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(body: KeeperMessageParticipantsCard(session: session)),
        ),
        GoRoute(
          path: RouteNames.sessionParticipants(':sessionSlug'),
          builder: (_, _) =>
              const Scaffold(body: Text('Session Participants Screen')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  group('KeeperMessageParticipantsCard', () {
    testWidgets('renders badge, title, description and button', (tester) async {
      await tester.pumpWidget(wrapCard());

      expect(find.text('\u{1F512}  Keeper Only'), findsOneWidget);
      expect(find.text('Message All Participants'), findsNWidgets(2));
      expect(
        find.text(
          'Send an individual message to every participant registered '
          'for this session.',
        ),
        findsOneWidget,
      );
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('tapping the button opens the Session Participants screen', (
      tester,
    ) async {
      await tester.pumpWidget(wrapCard());

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Session Participants Screen'), findsOneWidget);
    });
  });
}

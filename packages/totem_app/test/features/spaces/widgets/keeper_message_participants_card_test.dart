import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/features/spaces/widgets/keeper_message_participants_card.dart';
import 'package:totem_core/shared/router.dart';

void main() {
  // Wraps the card in a minimal GoRouter so the "Message All Participants"
  // button has a real route to push to.
  Widget wrapCard() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: KeeperMessageParticipantsCard()),
        ),
        GoRoute(
          path: RouteNames.newMessage,
          builder: (_, _) => const Scaffold(body: Text('New Message Screen')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  group('KeeperMessageParticipantsCard', () {
    testWidgets('renders badge, title, description and button', (
      tester,
    ) async {
      await tester.pumpWidget(wrapCard());

      expect(find.text('\u{1F512}  Keeper Only'), findsOneWidget);
      // Title and button share the same label.
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

    testWidgets('tapping the button opens the New Message screen', (
      tester,
    ) async {
      await tester.pumpWidget(wrapCard());

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('New Message Screen'), findsOneWidget);
    });
  });
}

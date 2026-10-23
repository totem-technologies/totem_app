import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/messages/screens/new_message_screen.dart';
import 'package:totem_core/features/messages/providers/compose_to_participants_provider.dart';
import 'package:totem_core/features/messages/providers/is_current_user_keeper_provider.dart';
import 'package:totem_core/shared/router.dart';

void main() {
  test(
    'compose provider seeds recipients once, toggles selection, and sends',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final provider = composeToParticipantsProvider('session');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final notifier = container.read(provider.notifier);

      notifier.seedRecipients(['one', 'two']);
      notifier.seedRecipients(['ignored']);
      check(container.read(provider).selected).deepEquals({'one', 'two'});

      notifier.toggleRecipient('one');
      check(container.read(provider).selected).deepEquals({'two'});

      final sending = notifier.send('hello');
      check(container.read(provider).isSending).isTrue();
      check(await sending).isTrue();
      check(container.read(provider).isSending).isFalse();
    },
  );

  testWidgets('new message shows the participant variant for keepers', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isCurrentMessagingUserKeeperProvider.overrideWith((ref) => true),
        ],
        child: const MaterialApp(home: NewMessageScreen()),
      ),
    );

    check(tester.widgetList(find.text('Search participants'))).length.equals(1);
    check(
      tester.widgetList(find.text('YOUR SESSION PARTICIPANTS')),
    ).length.equals(1);
    check(tester.widgetList(find.text('OTHER PARTICIPANTS'))).length.equals(1);
    check(tester.widgetList(find.text('Emily'))).length.equals(1);
  });

  testWidgets(
    'tapping a new-message person replaces the picker with its thread',
    (tester) async {
      final router = GoRouter(
        initialLocation: RouteNames.newMessage,
        routes: [
          GoRoute(
            path: RouteNames.newMessage,
            builder: (_, _) => const NewMessageScreen(),
          ),
          GoRoute(
            path: RouteNames.messageThread(':conversationId'),
            builder: (context, state) => Text(
              state.pathParameters['conversationId']!,
              textDirection: TextDirection.ltr,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isCurrentMessagingUserKeeperProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp.router(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.tap(find.text('Vanessa'));
      await tester.pumpAndSettle();

      check(
        router.routeInformationProvider.value.uri.path,
      ).equals(RouteNames.messageThread('conv_1'));
      check(tester.widgetList(find.text('conv_1'))).length.equals(1);
    },
  );
}

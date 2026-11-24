import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem_app/features/auth/services/notifications_service.dart';
import 'package:totem_app/features/spaces/screens/session_deep_link_screen.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';

class _RouterFake extends TotemRouter {
  _RouterFake();

  final key = GlobalKey<NavigatorState>();
  HomeRoutes? homeRoute;

  @override
  GlobalKey<NavigatorState> get navigatorKey => key;

  @override
  Uri get baseUri => Uri.parse('https://test.example');

  @override
  void popOrHome([BuildContext? context]) {}

  @override
  void toHome([HomeRoutes route = HomeRoutes.initialRoute]) =>
      homeRoute = route;

  @override
  Future<void> toKeeperProfile(BuildContext context, String userSlug) async {}

  @override
  Future<void> toSpaceSession(
    BuildContext context,
    String spaceSlug,
    String? sessionSlug, [
    bool replacement = false,
  ]) async {}

  @override
  GoRouter createRouter(WidgetRef ref) => throw UnimplementedError();

  @override
  void setTabCloseConfirmationEnabled(bool enabled) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'background notification payload is persisted for the next app launch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await notificationTapBackground(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          id: 1,
          payload:
              '{"payload":{"type":"session_starting","space_slug":"space","session_slug":"event"},"message_id":"message-1"}',
        ),
      );

      await preferences.reload();
      check(preferences.getString('initial_payload')).equals(
        '{"payload":{"type":"session_starting","space_slug":"space","session_slug":"event"},"message_id":"message-1"}',
      );
      check(
        preferences.getString('initial_payload_identity'),
      ).equals('message:message-1');
      check(preferences.getInt('initial_payload_timestamp')).isNotNull();
    },
  );

  test(
    'background notification with no payload clears stale interaction',
    () async {
      SharedPreferences.setMockInitialValues({
        'initial_payload': 'existing',
        'initial_payload_identity': 'local:1',
        'initial_payload_timestamp': 1,
      });

      await notificationTapBackground(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          id: 1,
        ),
      );

      final preferences = await SharedPreferences.getInstance();
      check(preferences.getString('initial_payload')).isNull();
      check(preferences.getString('initial_payload_identity')).isNull();
      check(preferences.getInt('initial_payload_timestamp')).isNull();
    },
  );

  test('oversized background payload is not persisted', () async {
    SharedPreferences.setMockInitialValues({});

    await notificationTapBackground(
      NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: 1,
        payload: List.filled(8193, 'x').join(),
      ),
    );

    final preferences = await SharedPreferences.getInstance();
    check(preferences.getString('initial_payload')).isNull();
  });

  testWidgets(
    'a malformed session deep link shows an error with home recovery',
    (tester) async {
      final router = _RouterFake();
      TotemRouter.instance = router;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider('missing-session').overrideWith(
              (ref) async => throw StateError('invalid session payload'),
            ),
          ],
          child: const MaterialApp(
            home: SessionDeepLinkScreen(sessionSlug: 'missing-session'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      check(tester.widgetList(find.byType(ErrorScreen))).length.equals(1);
      check(router.homeRoute).isNull();
    },
  );
}

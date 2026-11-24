import 'package:checks/checks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem_app/features/auth/services/notifications_service.dart';
import 'package:totem_app/features/spaces/screens/session_deep_link_screen.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';
import 'package:totem_core/testing/fake_totem_router.dart';

class _RouterFake extends FakeTotemRouter {
  HomeRoutes? homeRoute;

  @override
  void toHome([HomeRoutes route = HomeRoutes.initialRoute]) =>
      homeRoute = route;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'background notification payload is persisted for the next app launch',
    () async {
      SharedPreferences.setMockInitialValues({});

      await notificationTapBackground(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          id: 1,
          payload:
              '{"type":"circle_starting","space_slug":"space","event_slug":"event"}',
        ),
      );

      final preferences = await SharedPreferences.getInstance();
      check(preferences.getString('initial_payload')).equals(
        '{"type":"circle_starting","space_slug":"space","event_slug":"event"}',
      );
    },
  );

  test('background notification with no payload is ignored', () async {
    SharedPreferences.setMockInitialValues({'initial_payload': 'existing'});

    await notificationTapBackground(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        id: 1,
      ),
    );

    final preferences = await SharedPreferences.getInstance();
    check(preferences.getString('initial_payload')).equals('existing');
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

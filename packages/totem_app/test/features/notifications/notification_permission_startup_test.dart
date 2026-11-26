import 'dart:async';

import 'package:checks/checks.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/auth/services/notifications_service.dart';
import 'package:totem_app/main.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/permissions/notification_permissions.dart';
import 'package:totem_core/shared/router.dart';

class _CountingNotificationPermissions implements NotificationPermissions {
  _CountingNotificationPermissions({this.requestCompletion});

  final Completer<void>? requestCompletion;
  int requests = 0;

  @override
  Future<void> request() async {
    requests++;
    if (requestCompletion case final completion?) await completion.future;
  }
}

/// Signed in and onboarded, so the app skips onboarding image precaching.
class _SignedInAuthController extends MobileAuthController {
  @override
  AuthState build() => AuthState.authenticated(
    user: UserSchema(
      slug: const Omittable('user'),
      name: const Omittable('User'),
      profileAvatarType: ProfileAvatarTypeEnum.td,
      circleCount: 0,
      isStaff: false,
      email: 'user@example.com',
      dateCreated: DateTime.utc(2024),
    ),
  );

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isOnboardingCompleted => true;
}

class _BlankRouter extends AppTotemRouter {
  final key = GlobalKey<NavigatorState>();

  @override
  GlobalKey<NavigatorState> get navigatorKey => key;

  @override
  Uri get baseUri => Uri.parse('https://test.example');

  @override
  void popOrHome([BuildContext? context]) {}

  @override
  void toHome([HomeRoutes route = HomeRoutes.initialRoute]) {}

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
  GoRouter createRouter(WidgetRef ref) => GoRouter(
    navigatorKey: key,
    routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink())],
  );

  @override
  void setTabCloseConfirmationEnabled(bool enabled) {}
}

void main() {
  testWidgets('N1: notifications are asked for at app start', (tester) async {
    TotemRouter.instance = _BlankRouter();
    final requestCompletion = Completer<void>();
    final permissions = _CountingNotificationPermissions(
      requestCompletion: requestCompletion,
    );
    var permissionChecks = 0;
    final notificationService = NotificationsService.forTesting(
      permissionReader: () async {
        permissionChecks++;
        return AuthorizationStatus.authorized;
      },
      errorReporter: (_, _, _) {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedInAuthController.new),
          notificationPermissionsProvider.overrideWithValue(permissions),
          notificationsProvider.overrideWithValue(notificationService),
        ],
        child: const TotemApp(),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pump();
    check(permissions.requests).equals(1);
    check(permissionChecks).equals(0);

    requestCompletion.complete();
    await tester.pump();
    check(permissionChecks).equals(1);
  });
}

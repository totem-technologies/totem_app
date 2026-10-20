import 'dart:async';

import 'package:checks/checks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_app/features/auth/controllers/auth_controller.dart';
import 'package:totem_app/main.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/auth/models/auth_state.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/permissions/notification_permissions.dart';
import 'package:totem_core/shared/router.dart';

class _CountingNotificationPermissions implements NotificationPermissions {
  int requests = 0;

  @override
  Future<void> request() async => requests++;
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

class _BlankRouter extends TotemRouter {
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
    final notifications = _CountingNotificationPermissions();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedInAuthController.new),
          notificationPermissionsProvider.overrideWithValue(notifications),
        ],
        child: const TotemApp(),
      ),
    );
    await tester.pump();
    check(notifications.requests).equals(1);
  });
}

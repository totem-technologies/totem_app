import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_permissions.g.dart';

/// The single place notification permission is requested from.
///
/// Notifications never block joining, and the session flow never asks for
/// them (N1, N3 in `specs/permissions.md`). The mobile app overrides
/// [notificationPermissionsProvider] with a Firebase-backed implementation in
/// its `main.dart`. Everything else, web included, uses
/// [NoNotificationPermissions], so `totem_core` and `totem_web` never depend
/// on Firebase: Flutter web registers every web plugin in the dependency
/// graph, so tree shaking couldn't remove it.
// An interface, not a function, so the app can override the provider with
// its Firebase implementation and tests with a fake.
// ignore: one_member_abstracts
abstract interface class NotificationPermissions {
  Future<void> request();
}

class NoNotificationPermissions implements NotificationPermissions {
  const NoNotificationPermissions();

  @override
  Future<void> request() async {}
}

@Riverpod(keepAlive: true)
NotificationPermissions notificationPermissions(Ref ref) =>
    const NoNotificationPermissions();

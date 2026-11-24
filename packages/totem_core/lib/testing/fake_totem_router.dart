import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_core/shared/router.dart';

/// A no-op router for tests; override methods to record navigation as needed.
class FakeTotemRouter extends TotemRouter {
  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Uri get baseUri => Uri.parse('https://test.example.com/');

  @override
  void popOrHome([BuildContext? context]) {}

  @override
  void toHome([HomeRoutes route = HomeRoutes.initialRoute]) {}

  @override
  Future<void> toKeeperProfile(BuildContext context, String userSlug) async {}

  @override
  Future<void> rejoinSession(BuildContext context, String sessionSlug) async {}

  @override
  Future<void> toSpaceSession(
    BuildContext context,
    String spaceSlug,
    String? sessionSlug, [
    bool replacement = false,
  ]) async {}

  @override
  GoRouter createRouter(WidgetRef ref) =>
      throw UnsupportedError('createRouter should not be called in tests');

  @override
  void setTabCloseConfirmationEnabled(bool enabled) {}
}

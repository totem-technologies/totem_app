import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';

class SessionDeepLinkScreen extends ConsumerWidget {
  const SessionDeepLinkScreen({required this.sessionSlug, super.key});
  final String sessionSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider(sessionSlug));

    ref.listen(
      sessionProvider(sessionSlug),
      (previous, next) {
        if (next case AsyncData(:final value)) {
          context.go(RouteNames.spaceSession(value.space.slug, sessionSlug));
        }
      },
      onError: (error, stack) {
        TotemRouter.instance.toHome(HomeRoutes.home);
      },
    );

    return sessionAsync.when(
      data: (_) => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (error, stack) => ErrorScreen(error: error, showHomeButton: true),
    );
  }
}

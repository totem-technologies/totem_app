import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/navigation/route_names.dart';

class EventDeepLinkScreen extends ConsumerWidget {
  const EventDeepLinkScreen({required this.eventSlug, super.key});
  final String eventSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventProvider(eventSlug));

    return eventAsync.when(
      data: (event) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(RouteNames.spaceSession(event.space.slug, eventSlug));
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const Scaffold(
        body: Center(child: Text('Session not found')),
      ),
    );
  }
}

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

    ref.listen(eventProvider(eventSlug), (previous, next) {
      if (next case AsyncData(:final value)) {
        context.go(RouteNames.spaceSession(value.space.slug, eventSlug));
      }
    });

    return eventAsync.when(
      data: (_) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const Scaffold(
        body: Center(child: Text('Session not found')),
      ),
    );
  }
}

import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/extensions.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class OngoingSessionJoinCard extends ConsumerWidget {
  const OngoingSessionJoinCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(spacesSummaryProvider);
    final user = ref.watch(authControllerProvider.select((auth) => auth.user));
    if (summary.hasValue) {
      return summary.when(
        data: (summary) {
          if (summary.upcoming.isNotEmpty) {
            final event = summary.upcoming.firstWhereOrNull(
              (event) => event.canJoinNow(user),
            );
            if (event != null) {
              return Card(
                margin: const EdgeInsetsDirectional.only(
                  start: 20,
                  end: 20,
                  bottom: 10,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    spacing: 10,
                    children: [
                      UserAvatar.fromUserSchema(event.space.author, radius: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ongoing Session',
                              style: theme.textTheme.titleSmall,
                            ),
                            AutoSizeText(
                              event.title,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await context.push(
                            RouteNames.spaceEvent(event.space.slug, event.slug),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: const Size.square(46),
                        ),
                        child: const Text('Join now'),
                      ),
                    ],
                  ),
                ),
              );
            }
          }
          return const SizedBox.shrink();
        },
        error: (error, stackTrace) => const SizedBox.shrink(),
        loading: () => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }
}

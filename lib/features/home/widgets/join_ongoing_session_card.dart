import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/extensions.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

/// Keeps track of shown sheets to avoid showing multiple times in a row.
final _shownSheetFor = <String>{};

class JoinOngoingSessionCard extends ConsumerWidget {
  const JoinOngoingSessionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider.select((auth) => auth.user));
    final ongoingEventProvider = spacesSummaryProvider.select((summaryAsync) {
      if (summaryAsync.hasValue) {
        final summary = summaryAsync.value!;
        if (summary.upcoming.isNotEmpty) {
          final event = summary.upcoming.firstWhereOrNull(
            (event) => event.canJoinNow(user),
          );
          if (event != null) {
            return event;
          }
        }
      }
    });
    final ongoingEvent = ref.watch(ongoingEventProvider);

    ref.listen(
      ongoingEventProvider,
      (previous, next) async {
        if (previous != next && next != null) {
          if (_shownSheetFor.contains(next.slug)) return;
          final navigator = Navigator.of(context);
          if (navigator.mounted && !navigator.canPop()) {
            _shownSheetFor.add(next.slug);
            if (_shownSheetFor.length > 10) {
              _shownSheetFor.remove(_shownSheetFor.first);
            }
            return showOngoingSessionSheet(context, next);
          }
        }
      },
    );

    if (ongoingEvent != null) {
      return GestureDetector(
        onTap: () async {
          return showOngoingSessionSheet(context, ongoingEvent);
        },
        child: Card(
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
                UserAvatar.fromUserSchema(
                  ongoingEvent.space.author,
                  radius: 24,
                ),
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
                        ongoingEvent.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await context.push(
                      RouteNames.spaceEvent(
                        ongoingEvent.space.slug,
                        ongoingEvent.slug,
                      ),
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
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

Future<void> showOngoingSessionSheet(
  BuildContext context,
  EventDetailSchema event,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (context) => OngoingSessionSheet(event: event),
  );
}

class OngoingSessionSheet extends StatelessWidget {
  const OngoingSessionSheet({required this.event, super.key});

  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 20,
          end: 20,
          bottom: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 20,
          children: [
            Text(
              'Happening now!',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            Text(
              'Your space "${event.title}" with ${event.space.author.name} is happening now!',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            FractionallySizedBox(
              widthFactor: 0.9,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: SpaceCard.fromEventDetailSchema(event),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await context.push(
                  RouteNames.spaceEvent(event.space.slug, event.slug),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Enter now'),
            ),
          ],
        ),
      ),
    );
  }
}

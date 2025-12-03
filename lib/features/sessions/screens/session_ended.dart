import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/features/sessions/screens/session_feedback_widget.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/extensions.dart';

class SessionEndedScreen extends ConsumerWidget {
  const SessionEndedScreen({required this.event, super.key});

  final EventDetailSchema event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recommended = ref.watch(getRecommendedSessionsProvider());

    final nextEvents = event.space.nextEvents
        .where((e) => e.slug != event.slug)
        .take(2)
        .toList();

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text(
                  'Session Ended',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'Thank you for joining! We hope you found '
                  'the session enjoyable.',
                  textAlign: TextAlign.center,
                ),
                // Session Feedback Widget
                SessionFeedbackWidget(
                  onThumbUpPressed: () {
                    // TODO(bdlukaa): Implement thumb up logic
                  },
                  onThumbDownPressed: () {
                    // TODO(bdlukaa): Implement thumb down logic
                  },
                ),

                if (nextEvents.isNotEmpty) ...[
                  Text(
                    'Next Session',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.start,
                  ),
                  for (final nextEvent in nextEvents)
                    Flexible(
                      child: SmallSpaceCard(
                        space: MobileSpaceDetailSchemaExtension.copyWith(
                          event.space,
                          nextEvents: [nextEvent],
                        ),
                        onTap: () => context.pushReplacement(
                          RouteNames.spaceEvent(
                            event.space.slug,
                            nextEvent.slug,
                          ),
                        ),
                      ),
                    ),
                ] else
                  ...recommended.when(
                    data: (data) sync* {
                      if (data.isNotEmpty) {
                        yield Text(
                          'You may enjoy these spaces',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.start,
                        );
                        for (final event in data.take(2)) {
                          yield Flexible(
                            child: SmallSpaceCard.fromEventDetailSchema(event),
                          );
                        }
                      }
                    },
                    error: (error, _) => [],
                    loading: () => [],
                  ),
                // Explore More
                ElevatedButton(
                  onPressed: () => toHome(HomeRoutes.initialRoute),
                  child: const Text('Explore More'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

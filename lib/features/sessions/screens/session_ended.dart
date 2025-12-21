import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/features/profile/screens/user_feedback.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/extensions.dart';
import 'package:totem_app/shared/totem_icons.dart';

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
                // TODO(bdlukaa): Tell user their feedback was recorded
                _SessionFeedbackWidget(
                  onThumbUpPressed: () async {
                    await ref.read(
                      sessionFeedbackProvider(
                        event.slug,
                        SessionFeedbackOptions.up,
                      ).future,
                    );
                    await _incrementSessionLikedCount();
                  },
                  onThumbDownPressed: () async {
                    await showUserFeedbackDialog(
                      context,
                      onFeedbackSubmitted: (message) {
                        return ref.read(
                          sessionFeedbackProvider(
                            event.slug,
                            SessionFeedbackOptions.down,
                            message,
                          ).future,
                        );
                      },
                    );
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

  static const _reviewRequestedKey = 'session_review_requested';
  static const _sessionLikedCountKey = 'session_liked_count';
  Future<void> _incrementSessionLikedCount() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested = prefs.getBool(_reviewRequestedKey) ?? false;
    if (alreadyRequested) return;

    final count = (prefs.getInt(_sessionLikedCountKey) ?? 0) + 1;
    await prefs.setInt(_sessionLikedCountKey, count);
    if (count >= 5) {
      final inAppReview = InAppReview.instance;
      try {
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
          await prefs.setBool(_reviewRequestedKey, true);
        }
      } catch (_) {
        // Fine if fail
      }
    }
  }
}

class _SessionFeedbackWidget extends StatelessWidget {
  const _SessionFeedbackWidget({
    required this.onThumbUpPressed,
    required this.onThumbDownPressed,
  });

  final VoidCallback onThumbUpPressed;
  final VoidCallback onThumbDownPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Flexible(
            child: AutoSizeText(
              'How was your experience?',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 10,
              children: [
                _SessionFeedbackButton(
                  icon: const TotemIcon(
                    TotemIcons.thumbUp,
                    color: Colors.white,
                  ),
                  onPressed: onThumbUpPressed,
                ),
                _SessionFeedbackButton(
                  icon: const TotemIcon(
                    TotemIcons.thumbDown,
                    color: Colors.white,
                  ),
                  onPressed: onThumbDownPressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionFeedbackButton extends StatelessWidget {
  const _SessionFeedbackButton({
    required this.icon,
    required this.onPressed,
  });

  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsetsDirectional.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: icon,
      ),
    );
  }
}

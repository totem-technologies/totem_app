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
import 'package:totem_app/shared/widgets/sheet_drag_handle.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Keeps track of shown sheets to avoid showing multiple times in a row.
final _shownSheetFor = <String>{};

class JoinOngoingSessionCard extends ConsumerWidget {
  const JoinOngoingSessionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider.select((auth) => auth.user));
    final ongoingSessionProvider = spacesSummaryProvider.select((summaryAsync) {
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
    final ongoingSession = ref.watch(ongoingSessionProvider);

    ref.listen(
      ongoingSessionProvider,
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

    if (ongoingSession != null) {
      return GestureDetector(
        onTap: () async {
          return showOngoingSessionSheet(context, ongoingSession);
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
                  ongoingSession.space.author,
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
                        ongoingSession.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    context.launchSession(ongoingSession);
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
  SessionDetailSchema session,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    useRootNavigator: true,
    builder: (context) => OngoingSessionSheet(session: session),
  );
}

class OngoingSessionSheet extends StatelessWidget {
  const OngoingSessionSheet({required this.session, super.key});

  final SessionDetailSchema session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          top: 20,
          start: 20,
          end: 20,
          bottom: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 20,
          children: [
            const SheetDragHandle(margin: EdgeInsetsDirectional.zero),
            Text(
              'Happening now!',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            Text(
              'Your space "${session.title}" with ${session.space.author.name} is happening now!',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            FractionallySizedBox(
              widthFactor: 0.9,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: IgnorePointer(
                  child: SpaceCard.fromEventDetailSchema(session),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.launchSession(session);
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

extension on BuildContext {
  void launchSession(SessionDetailSchema session) {
    switch (session.meetingProvider) {
      case MeetingProviderEnum.livekit:
        pushNamed(
          RouteNames.videoSessionPrejoin,
          extra: session.slug,
        );
      case MeetingProviderEnum.googleMeet:
        launchUrl(
          Uri.parse(session.calLink),
          mode: LaunchMode.externalApplication,
        );
      default:
    }
  }
}

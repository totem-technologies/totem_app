import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/messages/providers/conversations_provider.dart';
import 'package:totem_core/features/messages/repositories/messages_repository.dart';
import 'package:totem_core/shared/router.dart';

class SessionParticipantsScreen extends ConsumerWidget {
  const SessionParticipantsScreen({required this.session, super.key});

  final SessionDetailSchema session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(
      sessionMessageParticipantsProvider(session.slug),
    );
    final date = DateFormat(
      'EEEE, MMM d · h:mm a',
    ).format(session.start.toLocal());

    return Scaffold(
      backgroundColor: AppTheme.surfaceCard,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                  Text(
                    'Session participants',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textHeading,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(date, style: const TextStyle(color: AppTheme.textMuted)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push(
                  RouteNames.composeToParticipants(session.slug),
                  extra: session,
                ),
                child: const Text('Message All Participants'),
              ),
            ),
          ),
          Expanded(
            child: participants.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(
                    sessionMessageParticipantsProvider(session.slug),
                  ),
                  child: const Text('Could not load participants. Try again.'),
                ),
              ),
              data: (state) {
                if (state.participants.isEmpty) {
                  return const Center(
                    child: Text('No participants are available to message.'),
                  );
                }
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 240) {
                      ref
                          .read(
                            sessionMessageParticipantsProvider(
                              session.slug,
                            ).notifier,
                          )
                          .loadMore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      8,
                      16,
                      32,
                    ),
                    itemCount:
                        state.participants.length +
                        (state.isLoadingMore || state.loadMoreError != null
                            ? 1
                            : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == state.participants.length) {
                        if (state.loadMoreError != null) {
                          return TextButton(
                            onPressed: () => ref
                                .read(
                                  sessionMessageParticipantsProvider(
                                    session.slug,
                                  ).notifier,
                                )
                                .loadMore(),
                            child: const Text('Retry loading more'),
                          );
                        }
                        return const Center(
                          child: CircularProgressIndicator.adaptive(),
                        );
                      }
                      return _ParticipantCard(
                        participant: state.participants[index],
                        onTap: () => _showParticipantProfile(
                          context,
                          ref,
                          state.participants[index],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showParticipantProfile(
    BuildContext context,
    WidgetRef ref,
    SessionParticipantSchema participant,
  ) => showDialog<void>(
    context: context,
    builder: (dialogContext) => _ParticipantProfileDialog(
      participant: participant,
      onSendMessage: () async {
        try {
          final conversation = await ref
              .read(messagesRepositoryProvider)
              .openConversation(participant.profile.slug);
          ref.read(conversationsProvider.notifier).upsert(conversation);
          if (!dialogContext.mounted) return;
          Navigator.of(dialogContext).pop();
          if (context.mounted) {
            context.push(RouteNames.messageThread(conversation.id));
          }
        } catch (_) {
          if (dialogContext.mounted) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(content: Text('This participant is unavailable.')),
            );
          }
        }
      },
    ),
  );
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.participant, required this.onTap});

  final SessionParticipantSchema participant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = participant.profile;
    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 72,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              CircleAvatar(child: Text(profile.name.characters.first)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textHeading,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${participant.sessionsCount} sessions',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.chevron),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantProfileDialog extends StatelessWidget {
  const _ParticipantProfileDialog({
    required this.participant,
    required this.onSendMessage,
  });

  final SessionParticipantSchema participant;
  final Future<void> Function() onSendMessage;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(participant.profile.name),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${participant.sessionsCount} sessions attended'),
        if (participant.reviewsCount case final reviews?)
          Text('$reviews reviews'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
      FilledButton(onPressed: onSendMessage, child: const Text('Send message')),
    ],
  );
}

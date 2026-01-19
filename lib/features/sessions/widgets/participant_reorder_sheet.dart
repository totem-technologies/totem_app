import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' show Participant;
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

Future<void> showParticipantReorderWidget(
  BuildContext context,
  Session session,
  SessionRoomState state,
  EventDetailSchema event,
) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF3F1E9),
    isScrollControlled: true,
    builder: (context) => ParticipantReorderWidget(
      session: session,
      state: state,
      event: event,
    ),
  );
}

class ParticipantReorderWidget extends ConsumerStatefulWidget {
  const ParticipantReorderWidget({
    required this.session,
    required this.state,
    required this.event,
    super.key,
  });

  final Session session;
  final SessionRoomState state;
  final EventDetailSchema event;

  @override
  ConsumerState<ParticipantReorderWidget> createState() =>
      _ParticipantReorderWidgetState();
}

class _ParticipantReorderWidgetState
    extends ConsumerState<ParticipantReorderWidget> {
  late List<String> _localOrder;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    final roomParticipants = widget.session.room.participants
        .map((p) => p.identity)
        .toSet();
    _localOrder = Set<String>.from(
      widget.state.sessionState.speakingOrder.where(roomParticipants.contains),
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final participants = _localOrder;

    if (participants.isEmpty) {
      return const Center(
        child: Text('No participants to reorder'),
      );
    }

    return PopScope(
      canPop: !_loading,
      child: CustomScrollView(
        shrinkWrap: true,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 20,
                end: 20,
                bottom: 6,
              ),
              child: Text(
                'Reorder Participants',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 20,
                end: 20,
                bottom: 20,
              ),
              child: Text(
                'Drag to set participant order',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverReorderableList(
              itemCount: participants.length,
              onReorder: (oldIndex, newIndex) {
                _handleReorder(context, ref, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final participantIdentity = participants[index];

                final participant = widget.session.room.participants
                    .firstWhereOrNull(
                      (p) => p.identity == participantIdentity,
                    );

                return _ParticipantReorderItem(
                  key: ValueKey(participantIdentity),
                  participantIdentity: participantIdentity,
                  participant: participant,
                  index: index,
                  isSpeakingNow:
                      participantIdentity ==
                      widget.state.sessionState.speakingNow,
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                spacing: 16,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_loading) return;
                        setState(() => _loading = true);
                        await _updateParticipantOrder(
                          context,
                          ref,
                          _localOrder,
                        );
                        if (mounted && context.mounted) {
                          setState(() => _loading = false);
                          Navigator.of(context).pop();
                        }
                      },
                      child: _loading
                          ? const LoadingIndicator(
                              color: Colors.white,
                              size: 24,
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleReorder(
    BuildContext context,
    WidgetRef ref,
    int oldIndex,
    int newIndex,
  ) {
    final adjustedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    final item = _localOrder.removeAt(oldIndex);
    _localOrder.insert(adjustedNewIndex, item);

    setState(() {});
  }

  Future<void> _updateParticipantOrder(
    BuildContext context,
    WidgetRef ref,
    List<String> newOrder,
  ) async {
    try {
      await ref.read(
        reorderParticipantsProvider(
          widget.session.options.eventSlug,
          newOrder,
        ).future,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Participant order updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update participant order: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ParticipantReorderItem extends ConsumerWidget {
  const _ParticipantReorderItem({
    required this.participantIdentity,
    required this.participant,
    required this.index,
    required this.isSpeakingNow,
    super.key,
  });

  final String participantIdentity;
  final Participant? participant;
  final int index;
  final bool isSpeakingNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(userProfileProvider(participantIdentity));

    final foregroundColor = isSpeakingNow
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSpeakingNow
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.primaryFixedDim,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 32,
          height: 32,
          child: AnimatedSwitcher(
            duration: kThemeChangeDuration,
            child: user.when(
              data: (userData) => UserAvatar.fromUserSchema(
                userData,
                borderRadius: BorderRadius.circular(20),
                borderWidth: 0,
              ),
              error: (error, stackTrace) => const CircleAvatar(
                backgroundColor: Colors.grey,
                child: TotemIcon(
                  TotemIcons.person,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              loading: () => const SizedBox.shrink(),
            ),
          ),
        ),
        title: user.when(
          data: (userData) => Text(
            userData.name ?? participantIdentity,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
          ),
          error: (error, stackTrace) => Text(
            participantIdentity,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
          ),
          loading: () => Text(
            participant?.name ?? participantIdentity,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
          ),
        ),
        trailing: ReorderableDragStartListener(
          index: index,
          child: TotemIcon(
            TotemIcons.dragHandle,
            size: 24,
            color: foregroundColor,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

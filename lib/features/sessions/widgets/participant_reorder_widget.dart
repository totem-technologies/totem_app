//
// ignore_for_file: parameter_assignments

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/sessions/services/livekit_service.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

Future<void> showParticipantReorderWidget(
  BuildContext context,
  LiveKitService session,
  LiveKitState state,
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

  final LiveKitService session;
  final LiveKitState state;
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
    _localOrder = List<String>.from(
      widget.state.sessionState.speakingOrder ?? [],
    );
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

    return CustomScrollView(
      shrinkWrap: true,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              bottom: 16,
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
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverReorderableList(
            itemCount: participants.length,
            onReorder: (oldIndex, newIndex) {
              _handleReorder(context, ref, oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final participantIdentity = participants[index];

              return _ParticipantReorderItem(
                key: ValueKey(participantIdentity),
                participantIdentity: participantIdentity,
                index: index,
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
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
                      if (mounted) setState(() => _loading = false);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: _loading
                        ? const LoadingIndicator(color: Colors.white, size: 24)
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    required this.index,
    super.key,
  });

  final String participantIdentity;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(userProfileProvider(participantIdentity));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 32,
          height: 32,
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
            loading: () => const CircleAvatar(
              backgroundColor: Colors.grey,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
        ),
        title: user.when(
          data: (userData) => Text(
            userData.name ?? participantIdentity,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          error: (error, stackTrace) => Text(
            participantIdentity,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          loading: () => Text(
            'Loading...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: TotemIcon(
          TotemIcons.dragHandle,
          size: 24,
          color: theme.colorScheme.onPrimary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

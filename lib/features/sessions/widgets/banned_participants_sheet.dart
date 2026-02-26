import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/sheet_drag_handle.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

Future<void> showBannedParticipantsSheet(
  BuildContext context,
  Session session,
  SessionRoomState state,
) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: false,
    backgroundColor: const Color(0xFFF3F1E9),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => BannedParticipantsSheet(
      session: session,
      state: state,
    ),
  );
}

class BannedParticipantsSheet extends ConsumerWidget {
  const BannedParticipantsSheet({
    required this.session,
    required this.state,
    super.key,
  });

  final Session session;
  final SessionRoomState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bannedParticipants = state.roomState.bannedParticipants;

    return Column(
      children: [
        const SheetDragHandle(),
        Expanded(
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
                    'Banned Participants',
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
                    bannedParticipants.isEmpty
                        ? 'No participants have been banned'
                        : 'Tap Unban to allow a participant to rejoin',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (bannedParticipants.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: bannedParticipants.length,
                    itemBuilder: (context, index) {
                      final participantSlug = bannedParticipants[index];
                      return _BannedParticipantItem(
                        key: ValueKey(participantSlug),
                        participantSlug: participantSlug,
                        session: session,
                      );
                    },
                  ),
                ),
              const SliverSafeArea(
                top: false,
                bottom: true,
                sliver: SliverToBoxAdapter(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BannedParticipantItem extends ConsumerStatefulWidget {
  const _BannedParticipantItem({
    required this.participantSlug,
    required this.session,
    super.key,
  });

  final String participantSlug;
  final Session session;

  @override
  ConsumerState<_BannedParticipantItem> createState() =>
      _BannedParticipantItemState();
}

class _BannedParticipantItemState
    extends ConsumerState<_BannedParticipantItem> {
  var _loading = false;

  Future<void> _onUnban() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.session.unbanParticipant(widget.participantSlug);
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Participant unbanned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unban participant: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(userProfileProvider(widget.participantSlug));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryFixedDim,
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
            userData.name ?? widget.participantSlug,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          error: (error, stackTrace) => Text(
            widget.participantSlug,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          loading: () => Text(
            widget.participantSlug,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        trailing: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: _onUnban,
                child: const Text('Unban'),
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/sheet_drag_handle.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

Future<void> showBannedParticipantsModal(
  BuildContext context,
  SessionController session,
  SessionRoomState state,
) {
  return showResponsiveModal<void>(
    context: context,
    useRootNavigator: false,
    showDragHandle: false,
    bottomSheetBackgroundColor: const Color(0xFFF3F1E9),
    dialogBackgroundColor: const Color(0xFFF3F1E9),
    bottomSheetBuilder: (context) => BannedParticipants(
      session: session,
      state: state,
    ),
    largeScreenBuilder: (context) => SizedBox(
      width: 400,
      child: BannedParticipants(session: session, state: state),
    ),
  );
}

class BannedParticipants extends ConsumerStatefulWidget {
  const BannedParticipants({
    required this.session,
    required this.state,
    super.key,
  });

  final SessionController session;
  final SessionRoomState state;

  @override
  ConsumerState<BannedParticipants> createState() => _BannedParticipantsState();
}

class _BannedParticipantsState extends ConsumerState<BannedParticipants> {
  final _unbannedSlugs = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bannedParticipants = widget.state.roomState.bannedParticipants
        .where((slug) => !_unbannedSlugs.contains(slug))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetDragHandle(),
        Flexible(
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
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                  ),
                  sliver: SliverList.builder(
                    itemCount: bannedParticipants.length,
                    itemBuilder: (context, index) {
                      final participantSlug = bannedParticipants[index];
                      return _BannedParticipantItem(
                        key: ValueKey(participantSlug),
                        participantSlug: participantSlug,
                        session: widget.session,
                        onUnbanned: () {
                          setState(() {
                            _unbannedSlugs.add(participantSlug);
                          });
                        },
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
    required this.onUnbanned,
    super.key,
  });

  final String participantSlug;
  final SessionController session;
  final VoidCallback onUnbanned;

  @override
  ConsumerState<_BannedParticipantItem> createState() =>
      _BannedParticipantItemState();
}

class _BannedParticipantItemState
    extends ConsumerState<_BannedParticipantItem> {
  var _loading = false;

  Future<void> _onUnban(String? name) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.session.keeper.unbanParticipant(widget.participantSlug);
      widget.onUnbanned();
    } catch (error) {
      if (mounted && context.mounted) {
        showErrorDialog(
          context,
          'Failed to unban ${name ?? widget.participantSlug}',
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
      margin: const EdgeInsetsDirectional.only(bottom: 8),
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
        trailing: SizedBox(
          width: 100,
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                )
              : Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                  child: OutlinedButton(
                    style: const ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(Colors.white),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: Colors.white),
                      ),
                    ),
                    onPressed: () {
                      final name = user.value?.name;
                      _onUnban(name);
                    },
                    child: const Text(
                      'Unban',
                      style: TextStyle(decoration: TextDecoration.none),
                    ),
                  ),
                ),
        ),
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      ),
    );
  }
}

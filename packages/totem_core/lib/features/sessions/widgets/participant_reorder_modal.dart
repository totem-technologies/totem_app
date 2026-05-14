import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart' show Participant;
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/sheet_drag_handle.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

Future<void> showParticipantReorderModals(
  BuildContext context,
) {
  return showResponsiveModal<void>(
    context: context,
    useRootNavigator: false,
    bottomSheetBackgroundColor: const Color(0xFFF3F1E9),
    dialogBackgroundColor: const Color(0xFFF3F1E9),
    smallScreenBuilder: (context) => const ParticipantReorderWidget(),
    largeScreenBuilder: (context) => const SizedBox(
      width: 600,
      child: ParticipantReorderWidget(),
    ),
  );
}

class ParticipantReorderWidget extends ConsumerStatefulWidget {
  const ParticipantReorderWidget({
    super.key,
  });

  @override
  ConsumerState<ParticipantReorderWidget> createState() =>
      _ParticipantReorderWidgetState();
}

class _ParticipantReorderWidgetState
    extends ConsumerState<ParticipantReorderWidget> {
  String? _selectedIdentity;

  bool _initialized = false;
  late List<String> _localOrder;
  var _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(currentSessionProvider)!;
    final sessionState = ref.watch(currentSessionStateProvider)!;

    if (!_initialized) {
      final roomParticipants = sessionState.participantsList
          .map((p) => p.identity)
          .toSet();
      _localOrder = sessionState.roomState.talkingOrder.isEmpty
          ? {sessionState.roomState.keeper, ...roomParticipants}.toList()
          : Set<String>.from(
              sessionState.roomState.talkingOrder.where(
                roomParticipants.contains,
              ),
            ).toList();
      _initialized = true;
    }

    final participants = _localOrder;

    if (participants.isEmpty) {
      return const Center(
        child: Text('No participants to reorder'),
      );
    }

    return PopScope(
      canPop: !_loading,
      child: Material(
        type: MaterialType.transparency,
        child: ViewportResolver(
          builder: (context, viewportKind) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  flex: 2,
                  child: Column(
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
                                  'Reorder Participants',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
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
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 20,
                              ),
                              sliver: SliverReorderableList(
                                itemCount: participants.length,
                                onReorder: (oldIndex, newIndex) {
                                  _handleReorder(
                                    context,
                                    sessionState.roomState.keeper,
                                    oldIndex,
                                    newIndex,
                                  );
                                },
                                itemBuilder: (context, index) {
                                  final participantIdentity =
                                      participants[index];

                                  final participant = sessionState
                                      .participantsList
                                      .firstWhereOrNull(
                                        (p) =>
                                            p.identity == participantIdentity,
                                      );

                                  return _ParticipantReorderItem(
                                    key: ValueKey(participantIdentity),
                                    participantIdentity: participantIdentity,
                                    participant: participant,
                                    index: index,
                                    isSpeakingNow:
                                        participantIdentity ==
                                        sessionState.speakingNow,
                                    onTap: () {
                                      switch (viewportKind) {
                                        case ViewportKind.mediumPlus:
                                          setState(() {
                                            if (_selectedIdentity ==
                                                participantIdentity) {
                                              _selectedIdentity = null;
                                            } else {
                                              _selectedIdentity =
                                                  participantIdentity;
                                            }
                                          });

                                        default:
                                          showResponsiveModal<void>(
                                            context: context,
                                            useRootNavigator: false,
                                            showDragHandle: true,
                                            smallScreenBuilder: (context) =>
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _ParticipantInfo(
                                                        participant:
                                                            participantIdentity,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            largeScreenBuilder: (context) =>
                                                _ParticipantInfo(
                                                  participant:
                                                      participantIdentity,
                                                ),
                                          );
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  vertical: 20,
                                  horizontal: 40,
                                ),
                                child: Row(
                                  spacing: 16,
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _loading
                                            ? null
                                            : () {
                                                _updateParticipantOrder(
                                                  session,
                                                  _localOrder,
                                                );
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
                            const SliverSafeArea(
                              top: false,
                              bottom: true,
                              sliver: SliverToBoxAdapter(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedIdentity != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _ParticipantInfo(participant: _selectedIdentity!),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleReorder(
    BuildContext context,
    String keeperSlug,
    int oldIndex,
    int newIndex,
  ) {
    final adjustedNewIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    final item = _localOrder.removeAt(oldIndex);
    _localOrder.insert(adjustedNewIndex, item);

    // ensure keeper is first always
    _localOrder = {
      keeperSlug,
      ..._localOrder,
    }.toList();

    setState(() {});
  }

  Future<void> _updateParticipantOrder(
    SessionController session,
    List<String> newOrder,
  ) async {
    try {
      setState(() => _loading = true);
      await session.keeper.reorder(newOrder);
    } catch (error) {
      if (mounted) {
        await ErrorHandler.showErrorDialog(
          context,
          title: 'Error Reordering Participants',
          message: 'An error occurred while reordering participants',
        );
      }
    } finally {
      _loading = false;
      if (mounted) {
        setState(() {});
        Navigator.of(context).pop();
      }
    }
  }
}

class _ParticipantInfo extends ConsumerWidget {
  const _ParticipantInfo({required this.participant});

  final String participant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final participant = ref.watch(
      userProfileProvider(this.participant),
    );
    return DefaultTextStyle.merge(
      style: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.black,
      ),
      child: IntrinsicWidth(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: participant.when(
              data: (user) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: UserAvatar.fromUserSchema(
                      user,
                      radius: 42,
                      borderWidth: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name ?? user.slug ?? 'Participant',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${user.circleCount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Text(
                    'Sessions joined',
                    style: TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    DateFormat(
                      'MMM, yyyy',
                    ).format(user.dateCreated),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const Text(
                    'Member Since',
                    style: TextStyle(color: Colors.black),
                  ),
                ],
              ),
              error: (error, stackTrace) =>
                  const Text('Error loading user info'),
              loading: () => const LoadingIndicator(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantReorderItem extends ConsumerWidget {
  const _ParticipantReorderItem({
    required this.participantIdentity,
    required this.participant,
    required this.index,
    required this.isSpeakingNow,
    required this.onTap,
    super.key,
  });

  final String participantIdentity;
  final Participant? participant;
  final int index;
  final bool isSpeakingNow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(userProfileProvider(participantIdentity));

    final foregroundColor = !isSpeakingNow
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Material(
        type: MaterialType.card,
        color: !isSpeakingNow
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.primaryFixedDim,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
          contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          onTap: onTap,
        ),
      ),
    );
  }
}

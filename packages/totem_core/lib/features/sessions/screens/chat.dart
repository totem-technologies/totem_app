import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/keeper/screens/keeper_profile_screen.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/chat/message_bubble.dart';
import 'package:totem_core/shared/widgets/chat/message_input_bar.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/sheet_drag_handle.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

/// Width of the Figma desktop chat column.
const double sessionChatPanelWidth = 412;

/// Video plus 412px sidebar needs at least this much horizontal room.
const double sessionChatDockMinWidth = 1100;

/// Dock the panel on wide tablet/desktop. Phones and narrow tablets use a modal.
bool shouldDockSessionChat(BuildContext context) {
  final kind = ViewportResolver.getViewportKind(context);
  final isTabletOrDesktop =
      kind == ViewportKind.mediumSmall || kind == ViewportKind.mediumPlus;
  return isTabletOrDesktop &&
      MediaQuery.sizeOf(context).width >= sessionChatDockMinWidth;
}

Future<void> showSessionChat(BuildContext context) {
  return showResponsiveModal<void>(
    context: context,
    useRootNavigator: false,
    showDragHandle: false,
    useSafeArea: false,
    bottomSheetBackgroundColor: AppTheme.cream,
    dialogBackgroundColor: AppTheme.cream,
    dialogAlignment: AlignmentDirectional.centerEnd,
    dialogInsetPadding: const EdgeInsetsDirectional.only(end: 24, top: 16),
    dialogShape: const RoundedRectangleBorder(
      borderRadius: BorderRadiusDirectional.horizontal(
        start: Radius.circular(20),
      ),
    ),
    dialogBarrierColor: Colors.black26,
    bottomSheetBuilder: (context) {
      return DraggableScrollableSheet(
        maxChildSize: 0.9,
        initialChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SessionChatPanel(
            scrollController: scrollController,
            showDragHandle: true,
          );
        },
      );
    },
    largeScreenBuilder: (context) {
      final height = MediaQuery.sizeOf(context).height;
      return SizedBox(
        width: sessionChatPanelWidth,
        height: height - 32,
        child: const SessionChatPanel(),
      );
    },
  );
}

/// In-call chat panel used as a phone sheet, tablet dialog, or docked sidebar.
class SessionChatPanel extends ConsumerStatefulWidget {
  const SessionChatPanel({
    super.key,
    this.scrollController,
    this.embedded = false,
    this.showDragHandle = false,
  });

  final ScrollController? scrollController;

  /// True when the panel is the docked desktop sidebar (close toggles provider).
  final bool embedded;

  final bool showDragHandle;

  @override
  ConsumerState<SessionChatPanel> createState() => _SessionChatPanelState();
}

/// Tests and older call sites still look up this name.
typedef SessionChatMessages = SessionChatPanel;

class _SessionChatPanelState extends ConsumerState<SessionChatPanel>
    with SingleTickerProviderStateMixin {
  ScrollController? _localController;
  ScrollController get scrollController =>
      widget.scrollController ?? (_localController ??= ScrollController());

  int _previousMessageCount = 0;
  var _dropdownOpen = false;

  /// Critically damped spring so the recipient menu can be grabbed mid-flight.
  late final AnimationController _dropdownController;

  @override
  void initState() {
    super.initState();
    _dropdownController = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _dropdownController.dispose();
    _localController?.dispose();
    super.dispose();
  }

  Future<void> _scrollToBottom() async {
    Future<void> jumpToBottom() async {
      if (!scrollController.hasClients) return;
      final position = scrollController.position;
      if (!position.hasContentDimensions) return;
      scrollController.jumpTo(position.maxScrollExtent);
    }

    await SchedulerBinding.instance.endOfFrame;
    await jumpToBottom();
    await SchedulerBinding.instance.endOfFrame;
    await jumpToBottom();
  }

  void _setDropdownOpen(bool open) {
    if (_dropdownOpen == open) return;
    setState(() => _dropdownOpen = open);

    // Damping 2√k gives a critically damped settle (~0.3s response).
    const spring = SpringDescription(mass: 1, stiffness: 400, damping: 40);
    final simulation = SpringSimulation(
      spring,
      _dropdownController.value,
      open ? 1 : 0,
      _dropdownController.velocity,
    );
    _dropdownController.animateWith(simulation);
  }

  void _closePanel() {
    _setDropdownOpen(false);
    if (widget.embedded) {
      ref.read(sessionChatOpenProvider.notifier).setOpen(false);
      return;
    }
    Navigator.of(context).maybePop();
  }

  String? _localIdentity() {
    final roomIdentity = ref
        .read(currentSessionProvider)
        ?.room
        ?.localParticipant
        ?.identity;
    if (roomIdentity != null && roomIdentity.isNotEmpty) {
      return roomIdentity;
    }
    final user = ref.read(authControllerProvider).user;
    return user?.slug ?? user?.email;
  }

  @override
  Widget build(BuildContext context) {
    final isKeeper = ref.watch(isCurrentUserKeeperProvider);
    final threadTarget = ref.watch(sessionChatThreadTargetProvider);
    final allMessages = ref.watch(sessionMessagesProvider);
    final participants = ref.watch(sessionParticipantsProvider);
    final sessionState = ref.watch(currentSessionStateProvider);
    final user = ref.watch(authControllerProvider.select((auth) => auth.user));

    final localIdentity =
        ref.watch(currentSessionProvider)?.room?.localParticipant?.identity ??
        user?.slug ??
        user?.email;
    final keeperIdentity = sessionState?.roomState.keeper;

    final threadMessages = allMessages
        .where(
          (message) => message.belongsToThread(
            localIdentity: localIdentity,
            threadTarget: threadTarget,
          ),
        )
        .toList();

    if (threadMessages.length != _previousMessageCount) {
      _previousMessageCount = threadMessages.length;
      if (threadMessages.isNotEmpty) {
        _scrollToBottom();
      }
    }

    final isPrivateThread = threadTarget != null;
    final canCompose = isKeeper || isPrivateThread;
    final hintText = _pinnedHint(
      isKeeper: isKeeper,
      isPrivateThread: isPrivateThread,
    );

    void send(String text) {
      ref
          .read(currentSessionProvider)
          ?.messaging
          .sendMessage(text, recipientIdentity: threadTarget);
      _scrollToBottom();
    }

    return Material(
      color: AppTheme.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showDragHandle) const SheetDragHandle(),
          _SessionChatHeader(
            isKeeper: isKeeper,
            threadTarget: threadTarget,
            keeperIdentity: keeperIdentity,
            participants: participants,
            dropdownOpen: _dropdownOpen,
            onClose: _closePanel,
            onToggleDropdown: () => _setDropdownOpen(!_dropdownOpen),
          ),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        16,
                        20,
                        0,
                      ),
                      child: _PinnedHintPill(text: hintText),
                    ),
                    Expanded(
                      child: threadMessages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet',
                                style: TextStyle(color: AppTheme.gray),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                20,
                                14,
                                20,
                                16,
                              ),
                              itemCount: threadMessages.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final message = threadMessages[index];
                                final isOwn =
                                    message.sender ||
                                    (localIdentity != null &&
                                        message.participant?.identity ==
                                            localIdentity);
                                return MessageBubble(
                                  text: message.message,
                                  timestamp: DateFormat.jm().format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      message.timestamp,
                                    ).toLocal(),
                                  ),
                                  isOwn: isOwn,
                                );
                              },
                            ),
                    ),
                    if (!isKeeper)
                      _ParticipantThreadChip(
                        isPrivateThread: isPrivateThread,
                        onMessageKeeper: () {
                          final keeper = keeperIdentity;
                          if (keeper == null || keeper.isEmpty) return;
                          _setDropdownOpen(false);
                          ref
                              .read(sessionChatThreadTargetProvider.notifier)
                              .selectParticipant(keeper);
                        },
                        onViewGroup: () {
                          _setDropdownOpen(false);
                          ref
                              .read(sessionChatThreadTargetProvider.notifier)
                              .selectEveryone();
                        },
                      ),
                    if (canCompose)
                      MessageInputBar(
                        hintText: _composerHint(
                          isPrivateThread: isPrivateThread,
                          threadTarget: threadTarget,
                          participants: participants,
                          keeperIdentity: keeperIdentity,
                        ),
                        autofocus: switch (defaultTargetPlatform) {
                          TargetPlatform.android ||
                          TargetPlatform.iOS ||
                          TargetPlatform.fuchsia => false,
                          _ => true,
                        },
                        onSend: send,
                      )
                    else
                      const MessageInputBar(
                        hintText: 'Message everyone',
                        enabled: false,
                      ),
                  ],
                ),
                if (_dropdownOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _setDropdownOpen(false),
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),
                _RecipientDropdownOverlay(
                  animation: _dropdownController,
                  isKeeper: isKeeper,
                  threadTarget: threadTarget,
                  keeperIdentity: keeperIdentity,
                  localIdentity: _localIdentity(),
                  participants: participants,
                  onSelectEveryone: () {
                    ref
                        .read(sessionChatThreadTargetProvider.notifier)
                        .selectEveryone();
                    _setDropdownOpen(false);
                  },
                  onSelectParticipant: (identity) {
                    ref
                        .read(sessionChatThreadTargetProvider.notifier)
                        .selectParticipant(identity);
                    _setDropdownOpen(false);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _pinnedHint({
  required bool isKeeper,
  required bool isPrivateThread,
}) {
  if (isPrivateThread) {
    return 'Only the keeper can see these messages';
  }
  if (isKeeper) {
    return 'Only you can post messages here';
  }
  return 'Only the Keeper can post messages here';
}

String _composerHint({
  required bool isPrivateThread,
  required String? threadTarget,
  required List<Participant> participants,
  required String? keeperIdentity,
}) {
  if (!isPrivateThread) {
    return 'Message everyone';
  }
  final match = participants.cast<Participant?>().firstWhere(
    (participant) => participant?.identity == threadTarget,
    orElse: () => null,
  );
  final name = match?.name;
  if (name != null && name.isNotEmpty) {
    return 'Message $name';
  }
  if (threadTarget == keeperIdentity) {
    return 'Message Keeper';
  }
  return 'Type a message...';
}

class _SessionChatHeader extends StatelessWidget {
  const _SessionChatHeader({
    required this.isKeeper,
    required this.threadTarget,
    required this.keeperIdentity,
    required this.participants,
    required this.dropdownOpen,
    required this.onClose,
    required this.onToggleDropdown,
  });

  final bool isKeeper;
  final String? threadTarget;
  final String? keeperIdentity;
  final List<Participant> participants;
  final bool dropdownOpen;
  final VoidCallback onClose;
  final VoidCallback onToggleDropdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Close chat',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              onPressed: onClose,
              icon: const TotemIcon(
                TotemIcons.closeRounded,
                size: 20,
                color: AppTheme.slate,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onToggleDropdown,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 44,
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppTheme.gray),
                  ),
                ),
                padding: const EdgeInsetsDirectional.only(start: 10),
                child: Row(
                  children: [
                    _HeaderAvatar(threadTarget: threadTarget),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HeaderTitle(
                        threadTarget: threadTarget,
                        keeperIdentity: keeperIdentity,
                        isKeeper: isKeeper,
                        participants: participants,
                      ),
                    ),
                    AnimatedRotation(
                      turns: dropdownOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: const TotemIcon(
                        TotemIcons.chevronDown,
                        size: 14,
                        color: AppTheme.gray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({
    required this.threadTarget,
  });

  final String? threadTarget;

  @override
  Widget build(BuildContext context) {
    if (threadTarget == null) {
      return const _EveryoneAvatar();
    }
    return _ParticipantAvatar(identity: threadTarget!);
  }
}

class _EveryoneAvatar extends StatelessWidget {
  const _EveryoneAvatar();

  static const double size = 32;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.mauve,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const TotemIcon(
        TotemIcons.chat,
        size: 18,
        color: AppTheme.white,
      ),
    );
  }
}

class _ParticipantAvatar extends ConsumerWidget {
  const _ParticipantAvatar({
    required this.identity,
  });

  final String identity;
  static const double radius = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(identity));
    return profile.when(
      data: (user) => UserAvatar.fromUserSchema(
        user,
        radius: radius,
        borderWidth: 0,
      ),
      loading: () => UserAvatar.custom(
        seed: identity,
        radius: radius,
        borderWidth: 0,
      ),
      error: (_, _) => UserAvatar.custom(
        seed: identity,
        radius: radius,
        borderWidth: 0,
      ),
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({
    required this.threadTarget,
    required this.keeperIdentity,
    required this.isKeeper,
    required this.participants,
  });

  final String? threadTarget;
  final String? keeperIdentity;
  final bool isKeeper;
  final List<Participant> participants;

  @override
  Widget build(BuildContext context) {
    if (threadTarget == null) {
      return const Text(
        'Everyone',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppTheme.textHeading,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final match = participants.cast<Participant?>().firstWhere(
      (participant) => participant?.identity == threadTarget,
      orElse: () => null,
    );
    final name = (match?.name != null && match!.name.isNotEmpty)
        ? match.name
        : threadTarget!;
    final showKeeperSubtitle = !isKeeper && threadTarget == keeperIdentity;

    if (!showKeeperSubtitle) {
      return Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.textHeading,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textHeading,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Text(
          'Keeper',
          style: TextStyle(
            color: AppTheme.gray,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _PinnedHintPill extends StatelessWidget {
  const _PinnedHintPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: AppTheme.messageDaySeparatorBg,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.gray,
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ParticipantThreadChip extends StatelessWidget {
  const _ParticipantThreadChip({
    required this.isPrivateThread,
    required this.onMessageKeeper,
    required this.onViewGroup,
  });

  final bool isPrivateThread;
  final VoidCallback onMessageKeeper;
  final VoidCallback onViewGroup;

  @override
  Widget build(BuildContext context) {
    final label = isPrivateThread ? 'View Group Messages' : 'Message Keeper';
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
        child: Material(
          color: AppTheme.messagePurpleLight,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: isPrivateThread ? onViewGroup : onMessageKeeper,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 15,
                vertical: 13,
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.messageChipText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientDropdownOverlay extends StatelessWidget {
  const _RecipientDropdownOverlay({
    required this.animation,
    required this.isKeeper,
    required this.threadTarget,
    required this.keeperIdentity,
    required this.localIdentity,
    required this.participants,
    required this.onSelectEveryone,
    required this.onSelectParticipant,
  });

  final Animation<double> animation;
  final bool isKeeper;
  final String? threadTarget;
  final String? keeperIdentity;
  final String? localIdentity;
  final List<Participant> participants;
  final VoidCallback onSelectEveryone;
  final ValueChanged<String> onSelectParticipant;

  @override
  Widget build(BuildContext context) {
    final rows = <Participant>[];
    if (isKeeper) {
      for (final participant in participants) {
        if (participant.identity == localIdentity) continue;
        rows.add(participant);
      }
    } else if (keeperIdentity != null) {
      final keeper = participants.cast<Participant?>().firstWhere(
        (participant) => participant?.identity == keeperIdentity,
        orElse: () => null,
      );
      if (keeper != null) {
        rows.add(keeper);
      }
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        if (t <= 0) {
          return const SizedBox.shrink();
        }
        return PositionedDirectional(
          top: 10,
          start: 38,
          end: 13,
          child: IgnorePointer(
            ignoring: t < 0.5,
            child: Opacity(
              opacity: t,
              child: Transform.scale(
                alignment: Alignment.topCenter,
                scale: 0.96 + (0.04 * t),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Material(
        color: AppTheme.white,
        elevation: 0,
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RecipientRow(
                selected: threadTarget == null,
                title: 'Everyone',
                subtitle: isKeeper
                    ? '${participants.length} participants · only you can post'
                    : '${participants.length} participants · only the Keeper can post',
                leading: const _EveryoneAvatar(),
                onTap: onSelectEveryone,
              ),
              for (final participant in rows) ...[
                const Divider(height: 1, color: AppTheme.divider),
                _RecipientRow(
                  selected: threadTarget == participant.identity,
                  title: participant.name.isNotEmpty
                      ? participant.name
                      : participant.identity,
                  leading: _ParticipantAvatar(identity: participant.identity),
                  onTap: () => onSelectParticipant(participant.identity),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.selected,
    required this.title,
    required this.leading,
    required this.onTap,
    this.subtitle,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ColoredBox(
        color: selected ? AppTheme.cream : AppTheme.white,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.slate,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppTheme.gray,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const TotemIcon(
                  TotemIcons.checkmark,
                  size: 18,
                  color: AppTheme.mauve,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showKeeperProfileSheet(
  BuildContext context,
  String slug,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    builder: (context) {
      return KeeperProfileSheet(slug: slug);
    },
  );
}

class KeeperProfileSheet extends StatelessWidget {
  const KeeperProfileSheet({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      maxChildSize: 0.8,
      initialChildSize: 0.8,
      expand: false,
      builder: (context, controller) {
        return PrimaryScrollController(
          controller: controller,
          child: KeeperProfileScreen(
            slug: slug,
            showAppBar: false,
          ),
        );
      },
    );
  }
}

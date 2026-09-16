import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:material_ui/material_ui.dart';
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

/// Tap-to-open drawer timing. Ease-out cubic over ~0.3s approximates a
/// critically damped spring (no bounce — this isn't a flicked sheet).
const Duration sessionChatDrawerDuration = Duration(milliseconds: 320);

/// Slightly snappier on the way out so dismiss feels decisive.
const Duration sessionChatDrawerReverseDuration = Duration(milliseconds: 260);

const Curve sessionChatDrawerCurve = Curves.easeOutCubic;

/// Dock the panel on wide tablet/desktop. Phones and narrow tablets use a modal.
bool shouldDockSessionChat(BuildContext context) {
  final kind = ViewportResolver.getViewportKind(context);
  final isTabletOrDesktop =
      kind == ViewportKind.mediumSmall || kind == ViewportKind.mediumPlus;
  return isTabletOrDesktop &&
      MediaQuery.sizeOf(context).width >= sessionChatDockMinWidth;
}

Future<void> showSessionChat(BuildContext context) {
  switch (ViewportResolver.getViewportKind(context)) {
    case ViewportKind.smallPortrait:
    case ViewportKind.smallLandscape:
      // Phones already get the platform sheet slide; leave that path alone.
      return showResponsiveModal<void>(
        context: context,
        useRootNavigator: false,
        showDragHandle: false,
        useSafeArea: false,
        bottomSheetBackgroundColor: AppTheme.cream,
        dialogBackgroundColor: AppTheme.cream,
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
        largeScreenBuilder: (_) => const SizedBox.shrink(),
      );
    case ViewportKind.mediumSmall:
    case ViewportKind.mediumPlus:
      // Overlay drawer on the room navigator so it sits above the circle,
      // not the app shell, and dismisses with the room back gesture.
      return Navigator.of(context, rootNavigator: false).push<void>(
        _SessionChatDrawerRoute(
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
        ),
      );
  }
}

/// Trailing-edge overlay: the panel slides in from `Offset(1, 0)`, which
/// [SlideTransition] flips in RTL so it always arrives from the end edge.
///
/// The route's default fade is stripped — a drawer should materialize by
/// moving, not by dissolving. The barrier still fades with [animation].
class _SessionChatDrawerRoute extends RawDialogRoute<void> {
  _SessionChatDrawerRoute({required String barrierLabel})
    : super(
        barrierLabel: barrierLabel,
        barrierDismissible: true,
        barrierColor: Colors.black26,
        transitionDuration: sessionChatDrawerDuration,
        transitionBuilder: _holdChild,
        pageBuilder: _buildPage,
      );

  /// Identity transition so [RawDialogRoute] doesn't fade the page on top
  /// of the slide we apply in [_buildPage].
  static Widget _holdChild(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }

  static Widget _buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final panel = Material(
      color: AppTheme.cream,
      elevation: 6,
      shadowColor: const Color.fromRGBO(0, 0, 0, 0.16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: sessionChatPanelWidth,
        height: MediaQuery.sizeOf(context).height,
        child: const SessionChatPanel(),
      ),
    );

    // Slide the 412px panel, not a full-screen Dialog: Offset(1, 0) is then
    // one panel-width, so the drawer tucks in from the window edge.
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: _slideFromTrailing(
        context: context,
        animation: animation,
        child: panel,
      ),
    );
  }

  @override
  Duration get reverseTransitionDuration => sessionChatDrawerReverseDuration;
}

/// Shared drive: ease-out on the way in, and the same curve played backward
/// on dismiss so the path out mirrors the path in.
Widget _slideFromTrailing({
  required BuildContext context,
  required Animation<double> animation,
  required Widget child,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return SlideTransition(
    position: animation.drive(
      Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: sessionChatDrawerCurve)),
    ),
    child: child,
  );
}

/// Wide-window rail that grows from the trailing edge so the video yields
/// space instead of the drawer covering it. Stays mounted at width 0 while
/// closed so the close animation can play.
class DockedSessionChatRail extends ConsumerStatefulWidget {
  const DockedSessionChatRail({super.key});

  @override
  ConsumerState<DockedSessionChatRail> createState() =>
      _DockedSessionChatRailState();
}

class _DockedSessionChatRailState extends ConsumerState<DockedSessionChatRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final open = ref.read(sessionChatOpenProvider);
    _controller = AnimationController(
      vsync: this,
      duration: sessionChatDrawerDuration,
      reverseDuration: sessionChatDrawerReverseDuration,
      value: open ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(bool open) {
    // Reduce Motion: skip the slide and snap, matching Apple's cross-fade
    // guidance for vestibular safety.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = open ? 1 : 0;
      return;
    }
    if (open) {
      _controller.forward();
      return;
    }
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(sessionChatOpenProvider, (previous, next) {
      _animateTo(next);
    });

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Drop the panel once the close finishes so the composer isn't
        // sitting in an invisible 0-width rail.
        if (_controller.value == 0 && !_controller.isAnimating) {
          return const SizedBox.shrink();
        }

        // widthFactor + trailing alignment clips from the leading edge, so
        // the rail appears to slide in from the window's end while the Row
        // actually shrinks the video.
        final t = sessionChatDrawerCurve.transform(_controller.value);
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            widthFactor: t,
            child: const SizedBox(
              width: sessionChatPanelWidth,
              child: SessionChatPanel(embedded: true),
            ),
          ),
        );
      },
    );
  }
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

class _SessionChatPanelState extends ConsumerState<SessionChatPanel>
    with SingleTickerProviderStateMixin {
  ScrollController? _localController;
  ScrollController get scrollController =>
      widget.scrollController ?? (_localController ??= ScrollController());

  var _dropdownOpen = false;

  /// Critically damped spring so the recipient menu can be grabbed mid-flight.
  late final AnimationController _dropdownController;

  @override
  void initState() {
    super.initState();
    _dropdownController = AnimationController.unbounded(vsync: this);
    // Open on the most recent message; [ref.listen] only covers later arrivals.
    unawaited(_scrollToBottom());
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
    if (!mounted) return;
    await jumpToBottom();
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return;
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

  /// LiveKit identity when the room is attached, else the account fallback the
  /// rest of the panel uses. Shared by [build] and the message listener so
  /// there is only one fallback chain.
  static String? _resolveLocalIdentity(String? roomIdentity, String? fallback) {
    if (roomIdentity != null && roomIdentity.isNotEmpty) return roomIdentity;
    return fallback;
  }

  String? _localIdentity() {
    final user = ref.read(authControllerProvider).user;
    return _resolveLocalIdentity(
      ref.read(currentSessionProvider)?.room?.localParticipant?.identity,
      user?.slug ?? user?.email,
    );
  }

  void _closePanel() {
    _setDropdownOpen(false);
    if (widget.embedded) {
      ref.read(sessionChatOpenProvider.notifier).open = false;
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    // Scroll on arrival rather than on a length change during build: a thread
    // switch no longer counts as an arrival, and two threads of equal length
    // no longer mask one.
    ref.listen(sessionMessagesProvider, (previous, next) {
      if (next.length <= (previous?.length ?? 0)) return;
      final message = next.last;
      final belongs = message.belongsToThread(
        localIdentity: _localIdentity(),
        threadTarget: ref.read(sessionChatThreadTargetProvider),
      );
      if (belongs) unawaited(_scrollToBottom());
    });

    // A newly selected thread should open at its most recent message.
    ref.listen(sessionChatThreadTargetProvider, (previous, next) {
      unawaited(_scrollToBottom());
    });

    final isKeeper = ref.watch(isCurrentUserKeeperProvider);
    final threadTarget = ref.watch(sessionChatThreadTargetProvider);
    final allMessages = ref.watch(sessionMessagesProvider);
    final participants = ref.watch(sessionParticipantsProvider);
    final sessionState = ref.watch(currentSessionStateProvider);
    final user = ref.watch(authControllerProvider.select((auth) => auth.user));

    final roomIdentity = ref
        .watch(currentSessionProvider)
        ?.room
        ?.localParticipant
        ?.identity;
    final localIdentity = _resolveLocalIdentity(
      roomIdentity,
      user?.slug ?? user?.email,
    );
    final keeperIdentity = _resolveKeeperIdentity(
      roomKeeper: sessionState?.roomState.keeper,
      spaceAuthor: ref.watch(currentSessionEventProvider)?.space.author.slug,
    );

    final threadMessages = allMessages
        .where(
          (message) => message.belongsToThread(
            localIdentity: localIdentity,
            threadTarget: threadTarget,
          ),
        )
        .toList();

    final isPrivateThread = threadTarget != null;
    final canCompose = isKeeper || isPrivateThread;
    final hintText = _pinnedHint(
      isKeeper: isKeeper,
      isPrivateThread: isPrivateThread,
    );

    Future<bool> send(String text) async {
      final messaging = ref.read(currentSessionProvider)?.messaging;
      if (messaging == null) return false;
      final accepted = await messaging.sendMessage(
        text,
        recipientIdentity: threadTarget,
      );
      if (accepted) unawaited(_scrollToBottom());
      return accepted;
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
              // Let the popover shadow paint past the stack bounds.
              clipBehavior: Clip.none,
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
                  interactive: _dropdownOpen,
                  isKeeper: isKeeper,
                  threadTarget: threadTarget,
                  keeperIdentity: keeperIdentity,
                  localIdentity: localIdentity,
                  participants: participants,
                  onSelectEveryone: () {
                    ref.read(sessionChatThreadTargetProvider.notifier).target =
                        null;
                    _setDropdownOpen(false);
                  },
                  onSelectParticipant: (identity) {
                    ref.read(sessionChatThreadTargetProvider.notifier).target =
                        identity;
                    _setDropdownOpen(false);
                  },
                ),
              ],
            ),
          ),
          if (!isKeeper)
            _ParticipantThreadChip(
              isPrivateThread: isPrivateThread,
              onMessageKeeper: () {
                final keeper = keeperIdentity;
                if (keeper == null || keeper.isEmpty) return;
                _setDropdownOpen(false);
                ref.read(sessionChatThreadTargetProvider.notifier).target =
                    keeper;
              },
              onViewGroup: () {
                _setDropdownOpen(false);
                ref.read(sessionChatThreadTargetProvider.notifier).target =
                    null;
              },
            ),
          if (canCompose)
            MessageInputBar(
              // A fresh State per thread, so a private draft can
              // never be sent to Everyone after a thread switch.
              key: ValueKey(threadTarget),
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
            const MessageInputBar(hintText: 'Message everyone', enabled: false),
        ],
      ),
    );
  }
}

String? _resolveKeeperIdentity({
  required String? roomKeeper,
  required String? spaceAuthor,
}) {
  if (roomKeeper != null && roomKeeper.isNotEmpty) return roomKeeper;
  if (spaceAuthor != null && spaceAuthor.isNotEmpty) return spaceAuthor;
  return null;
}

String _pinnedHint({required bool isKeeper, required bool isPrivateThread}) {
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
                  border: Border(left: BorderSide(color: AppTheme.gray)),
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
  const _HeaderAvatar({required this.threadTarget});

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
      child: const TotemIcon(TotemIcons.chat, size: 18, color: AppTheme.white),
    );
  }
}

class _ParticipantAvatar extends ConsumerWidget {
  const _ParticipantAvatar({required this.identity});

  final String identity;
  static const double radius = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(identity));
    return profile.when(
      data: (user) =>
          UserAvatar.fromUserSchema(user, radius: radius, borderWidth: 0),
      loading: () =>
          UserAvatar.custom(seed: identity, radius: radius, borderWidth: 0),
      error: (_, _) =>
          UserAvatar.custom(seed: identity, radius: radius, borderWidth: 0),
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
    const radius = 33.0;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 16, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.25),
                offset: Offset(2, 2),
                blurRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: AppTheme.mauve,
            borderRadius: BorderRadius.circular(radius),
            child: InkWell(
              onTap: isPrivateThread ? onViewGroup : onMessageKeeper,
              borderRadius: BorderRadius.circular(radius),
              splashColor: AppTheme.white.withValues(alpha: 0.22),
              highlightColor: AppTheme.white.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
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
    required this.interactive,
    required this.isKeeper,
    required this.threadTarget,
    required this.keeperIdentity,
    required this.localIdentity,
    required this.participants,
    required this.onSelectEveryone,
    required this.onSelectParticipant,
  });

  final Animation<double> animation;
  final bool interactive;
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

    final count = participants.length;
    final countLabel = '$count ${count == 1 ? 'participant' : 'participants'}';

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        if (t <= 0) {
          return const SizedBox.shrink();
        }
        // Line the popover up with the header's recipient control: its rows
        // carry 16px padding, so starting 16px before the header avatar
        // (20 close-button inset + 32 button + 8 gap + 1 rule + 10 pad = 71)
        // puts popover and header avatars on the same vertical axis, and the
        // trailing edge matches the header's 20px padding.
        return PositionedDirectional(
          top: 10,
          start: 71 - 16,
          end: 20,
          child: IgnorePointer(
            ignoring: !interactive || t < 0.5,
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
      // Figma 3518:10039 — white popover, 20px radius, 12% black shadow.
      // Shadow lives outside the clip so cream selected rows don't square off.
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.12),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: AppTheme.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _RecipientHairline(),
                _RecipientRow(
                  selected: threadTarget == null,
                  title: 'Everyone',
                  subtitle: isKeeper
                      ? '$countLabel · only you can post'
                      : '$countLabel · only the Keeper can post',
                  leading: const _EveryoneAvatar(),
                  onTap: onSelectEveryone,
                ),
                for (final participant in rows) ...[
                  const _RecipientHairline(),
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
      ),
    );
  }
}

/// 1px #E8E5E0 rule from the Figma recipient menu — not a Material hairline.
class _RecipientHairline extends StatelessWidget {
  const _RecipientHairline();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.divider,
      child: SizedBox(width: double.infinity, height: 1),
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
    // Highlight on press-down so the row feels grabbed, not "clicked".
    return InkWell(
      onTap: onTap,
      splashColor: AppTheme.cream.withValues(alpha: 0.45),
      highlightColor: AppTheme.cream.withValues(alpha: 0.35),
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
                  spacing: 4,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.slate,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppTheme.gray,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
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

Future<void> showKeeperProfileSheet(BuildContext context, String slug) {
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
          child: KeeperProfileScreen(slug: slug, showAppBar: false),
        );
      },
    );
  }
}

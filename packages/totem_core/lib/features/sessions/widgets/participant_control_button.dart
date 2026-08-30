import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/participant_overlay_metrics.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

class ParticipantControlButton extends ConsumerStatefulWidget {
  const ParticipantControlButton({
    required this.participant,
    required this.overlayPadding,
    this.backgroundColor = Colors.black54,
    super.key,
  });

  final Participant participant;
  final double overlayPadding;

  final Color backgroundColor;

  static const _menuTextStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  @override
  ConsumerState<ParticipantControlButton> createState() =>
      _ParticipantControlButtonState();
}

class _ParticipantControlButtonState
    extends ConsumerState<ParticipantControlButton>
    with WidgetsBindingObserver {
  final _menuController = MenuController();

  static final ButtonStyle _menuItemStyle = MenuItemButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    disabledForegroundColor: Colors.white54,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    textStyle: ParticipantControlButton._menuTextStyle,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _menuController.close();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _menuController.close();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ParticipantOverlayMetrics.of(context);

    return MenuAnchor(
      controller: _menuController,
      clipBehavior: Clip.hardEdge,
      alignmentOffset: Offset(0, widget.overlayPadding),
      menuChildren: _buildMenuItems(context),
      animated: true,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.8),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsetsDirectional.zero),
        minimumSize: const WidgetStatePropertyAll(Size(170, 0)),
      ),
      builder: (context, controller, child) {
        return GestureDetector(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: child,
        );
      },
      child: Container(
        width: metrics.badgeSize,
        height: metrics.badgeSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.backgroundColor,
        ),
        padding: EdgeInsetsDirectional.all(metrics.badgePadding),
        alignment: AlignmentDirectional.center,
        child: TotemIcon(
          TotemIcons.moreVertical,
          size: metrics.iconSize,
          color: Colors.white,
        ),
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    return [
      if (widget.participant.hasAudio)
        MenuItemButton(
          style: _menuItemStyle,
          onPressed: widget.participant.isMuted
              ? null
              : () => _onMuteParticipant(context),
          leadingIcon: const TotemIcon(
            TotemIcons.microphoneOff,
            size: 18,
            color: Colors.white,
          ),
          child: Text(
            widget.participant.isMuted ? 'Muted' : 'Mute',
            style: ParticipantControlButton._menuTextStyle,
          ),
        ),
      if (widget.participant.hasVideo)
        () {
          final isVideoOn =
              !(widget.participant.videoTrackPublications.firstOrNull?.muted ??
                  false);
          return MenuItemButton(
            style: _menuItemStyle,
            onPressed: isVideoOn
                ? () => _onDisableParticipantCamera(context)
                : null,
            leadingIcon: const TotemIcon(
              TotemIcons.cameraOff,
              size: 18,
              color: Colors.white,
            ),
            child: Text(
              !isVideoOn ? 'Camera Disabled' : 'Disable camera',
              style: ParticipantControlButton._menuTextStyle,
            ),
          );
        }(),
      MenuItemButton(
        style: _menuItemStyle,
        onPressed: () => _onRemoveParticipant(context),
        leadingIcon: const TotemIcon(
          TotemIcons.x,
          size: 18,
          color: Colors.white,
        ),
        child: const Text(
          'Remove',
          style: ParticipantControlButton._menuTextStyle,
        ),
      ),
      MenuItemButton(
        style: _menuItemStyle,
        onPressed: () => _onBanParticipant(context),
        leadingIcon: const TotemIcon(
          TotemIcons.banned,
          size: 18,
          color: Colors.white,
        ),
        child: const Text(
          'Ban',
          style: ParticipantControlButton._menuTextStyle,
        ),
      ),
    ];
  }

  Future<void> _onMuteParticipant(BuildContext context) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final user = ref.watch(
              userProfileProvider(widget.participant.identity),
            );
            final currentSession = ref.watch(currentSessionProvider);
            return ConfirmationDialog(
              iconWidget: user
                  .whenData(
                    (user) => UserAvatar.fromUserSchema(user, radius: 40),
                  )
                  .value,
              confirmButtonText: 'Mute',
              title: 'Mute ${widget.participant.name}',
              content: 'They can unmute themselves anytime.',
              onConfirm: () async {
                try {
                  await currentSession?.keeper.muteParticipant(
                    widget.participant.identity,
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  await ErrorHandler.handleApiError(context, error);
                } finally {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              type: ConfirmationDialogType.standard,
            );
          },
        );
      },
    );
  }

  Future<void> _onDisableParticipantCamera(BuildContext context) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final user = ref.watch(
              userProfileProvider(widget.participant.identity),
            );
            final currentSession = ref.watch(currentSessionProvider);
            return ConfirmationDialog(
              iconWidget: user
                  .whenData(
                    (user) => UserAvatar.fromUserSchema(user, radius: 40),
                  )
                  .value,
              confirmButtonText: 'Disable Camera',
              title: "Disable ${widget.participant.name}'s camera?",
              content: 'They can enable their camera anytime.',
              onConfirm: () async {
                try {
                  await currentSession?.keeper.disableParticipantCamera(
                    widget.participant.identity,
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  await ErrorHandler.handleApiError(context, error);
                } finally {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              type: ConfirmationDialogType.standard,
            );
          },
        );
      },
    );
  }

  Future<void> _onRemoveParticipant(BuildContext context) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final user = ref.watch(
              userProfileProvider(widget.participant.identity),
            );
            final currentSession = ref.watch(currentSessionProvider);
            return ConfirmationDialog(
              iconWidget: user
                  .whenData(
                    (user) => UserAvatar.fromUserSchema(user, radius: 40),
                  )
                  .value,
              confirmButtonText: 'Remove',
              content:
                  'Are you sure you want to remove '
                  '${widget.participant.name}?',
              onConfirm: () async {
                try {
                  await currentSession?.keeper.removeParticipant(
                    widget.participant.identity,
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  await ErrorHandler.handleApiError(context, error);
                } finally {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _onBanParticipant(BuildContext context) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final user = ref.watch(
              userProfileProvider(widget.participant.identity),
            );
            final currentSession = ref.watch(currentSessionProvider);
            return ConfirmationDialog(
              iconWidget: user
                  .whenData(
                    (user) => UserAvatar.fromUserSchema(user, radius: 40),
                  )
                  .value,
              confirmButtonText: 'Ban',
              content:
                  'Are you sure you want to ban '
                  '${widget.participant.name}? They will not be able to rejoin the session.',
              onConfirm: () async {
                try {
                  await currentSession?.keeper.banParticipant(
                    widget.participant.identity,
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  await ErrorHandler.handleApiError(context, error);
                } finally {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
            );
          },
        );
      },
    );
  }
}

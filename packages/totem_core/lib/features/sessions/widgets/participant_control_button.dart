import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
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
    required this.menuVerticalOffset,
    required this.metrics,
    this.backgroundColor = Colors.black54,
    super.key,
  });

  final Participant participant;

  /// Dy passed to [MenuAnchor.alignmentOffset].
  ///
  /// Positive opens the menu below the badge (grid tiles). Negative opens
  /// it above — used on the featured row, where a downward menu would cover
  /// the speaker name.
  final double menuVerticalOffset;

  final Color backgroundColor;

  /// Chrome sizes, resolved by the card from its own size.
  final ParticipantOverlayMetrics metrics;

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
  EventsListener<ParticipantEvent>? _participantListener;

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
    _bindParticipantListener();
  }

  @override
  void didUpdateWidget(covariant ParticipantControlButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.participant, widget.participant)) {
      _bindParticipantListener();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _participantListener?.dispose();
    _menuController.close();
    super.dispose();
  }

  void _bindParticipantListener() {
    _participantListener?.dispose();
    _participantListener = widget.participant.createListener()
      ..on<TrackPublishedEvent>((_) => _onParticipantMediaChanged())
      ..on<TrackUnpublishedEvent>((_) => _onParticipantMediaChanged())
      ..on<TrackMutedEvent>((_) => _onParticipantMediaChanged())
      ..on<TrackUnmutedEvent>((_) => _onParticipantMediaChanged());
  }

  void _onParticipantMediaChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeMetrics() {
    _menuController.close();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;

    return MenuAnchor(
      controller: _menuController,
      clipBehavior: Clip.hardEdge,
      alignmentOffset: Offset(0, widget.menuVerticalOffset),
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
          boxShadow: kElevationToShadow[6],
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
          final publication =
              widget.participant.videoTrackPublications.firstOrNull;
          final track = publication?.track;
          final isVideoOn =
              (track?.isActive ?? true) &&
              !(track?.muted ?? publication?.muted ?? false);
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
                  await ref
                      .read(currentSessionProvider)
                      ?.keeper
                      .muteParticipant(widget.participant.identity);
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
                  await ref
                      .read(currentSessionProvider)
                      ?.keeper
                      .disableParticipantCamera(widget.participant.identity);
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
                  await ref
                      .read(currentSessionProvider)
                      ?.keeper
                      .removeParticipant(widget.participant.identity);
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
                  await ref
                      .read(currentSessionProvider)
                      ?.keeper
                      .banParticipant(widget.participant.identity);
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

import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart'
    as mobile_api
    show RoomStatus, SessionDetailSchema, TurnState;
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/media_devices_provider.dart';
import 'package:totem_core/features/sessions/media/media_platform.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/banned_participants_modal.dart';
import 'package:totem_core/features/sessions/widgets/participant_reorder_modal.dart';
import 'package:totem_core/features/sessions/widgets/session_prompts_modal.dart';
import 'package:totem_core/shared/extensions.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/sheet_drag_handle.dart';

Future<void> showOptionsSheet(
  BuildContext context,
  SessionRoomState state,
  mobile_api.SessionDetailSchema session,
) {
  final renderBox =
      SessionActionBar.actionBarKey.currentContext?.findRenderObject()
          as RenderBox?;
  final offset = renderBox?.localToGlobal(Offset.zero);
  final bottomInset = offset != null
      ? MediaQuery.heightOf(context) - offset.dy + 12
      : 120.0;

  return showResponsiveModal<void>(
    context: context,
    showDragHandle: false,
    useRootNavigator: false,
    bottomSheetBackgroundColor: const Color(0xFFF3F1E9),
    dialogBarrierColor: Colors.black12,
    dialogBackgroundColor: const Color(0xFFF3F1E9),
    dialogAlignment: Alignment.bottomCenter,
    dialogInsetPadding: EdgeInsets.only(
      bottom: bottomInset,
      top: 24,
      left: 24,
      right: 24,
    ),
    isScrollControlled: true,
    bottomSheetBuilder: (context) {
      return SafeArea(child: MoreOptions(session: session, isDialog: false));
    },
    largeScreenBuilder: (context) {
      return SizedBox(
        width: 400,
        child: SafeArea(child: MoreOptions(session: session, isDialog: true)),
      );
    },
  );
}

class MoreOptions extends ConsumerWidget {
  const MoreOptions({required this.session, this.isDialog = false, super.key});

  final mobile_api.SessionDetailSchema session;
  final bool isDialog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentSession = ref.watch(currentSessionProvider)!;
    final state = ref.watch(
      currentSessionStateProvider.select(
        (state) => state == null
            ? null
            : (
                roomState: state.roomState,
                participants: state.participantsList,
              ),
      ),
    )!;
    final deviceState = ref.watch(
      sessionDeviceControllerProvider(currentSession),
    );
    final isSelfViewEnabled = ref.watch(
      selfViewSettingsProvider.select((s) => s.enabled),
    );

    final isKeeper = currentSession.isCurrentUserKeeper();

    Widget buildContent([ScrollController? scrollController]) {
      final cameraTile = MoreOptionsTile.camera(deviceState.cameraFacing, () {
        currentSession.devices.switchCameraPosition();
        Navigator.of(context).pop();
      });

      final outputTile = MoreOptionsTile.output(
        speakerOn: deviceState.isSpeakerphoneEnabled,
        selectedDeviceId: deviceState.selectedAudioOutputDeviceId,
        onSpeakerChanged: currentSession.devices.setSpeakerphone,
        onDeviceSelect: currentSession.devices.selectAudioOutputDevice,
      );

      final content = SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsetsDirectional.only(
          start: 20,
          end: 20,
          bottom: isDialog ? 20 : 36,
          top: isDialog ? 24 : 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ?cameraTile,
            ?outputTile,
            MoreOptionsTile<void>(
              title: 'Self-view',
              icon: TotemIcons.selfView,
              trailing: IgnorePointer(
                child: Switch.adaptive(
                  value: isSelfViewEnabled,
                  onChanged: (value) {},
                ),
              ),
              onTap: () {
                ref
                    .read(selfViewSettingsProvider.notifier)
                    .setEnabled(!isSelfViewEnabled);
              },
            ),
            MoreOptionsTile<void>(
              title: 'Leave session',
              icon: TotemIcons.leaveCall,
              type: MoreOptionsTileType.destructive,
              onTap: () async {
                final navigator = Navigator.of(context)..pop();
                final shouldLeave = await showLeaveDialog(context) ?? false;
                if (shouldLeave && navigator.mounted) {
                  TotemRouter.instance.popOrHome(navigator.context);
                  currentSession.leave();
                }
              },
            ),

            if (isKeeper) ...[
              Text(
                'Keeper Options',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              MoreOptionsTile<void>(
                title: 'Reorder Participants',
                icon: TotemIcons.reorder,
                onTap: () {
                  Navigator.of(context).pop();
                  showParticipantReorderModals(context);
                },
              ),
              MoreOptionsTile<void>(
                title:
                    'Banned Participants'
                    '${state.roomState.bannedParticipantsOrDefault.isNotEmpty ? ' (${state.roomState.bannedParticipantsOrDefault.length})' : ''}',
                icon: TotemIcons.removePerson,
                onTap: () {
                  Navigator.of(context).pop();
                  final sessionState = ref.read(currentSessionStateProvider);
                  if (sessionState != null) {
                    showBannedParticipantsModal(
                      context,
                      currentSession,
                      sessionState,
                    );
                  }
                },
              ),
              if (state.roomState.status != mobile_api.RoomStatus.ended)
                MoreOptionsTile<void>(
                  title: 'Manage Prompts',
                  icon: TotemIcons.edit,
                  onTap: () {
                    Navigator.of(context).pop();
                    showSessionPromptsModal(context, sessionSlug: session.slug);
                  },
                ),
              MoreOptionsTile<void>(
                title: 'Mute everyone',
                icon: TotemIcons.microphoneOff,
                type: MoreOptionsTileType.destructive,
                onTap: () {
                  Navigator.of(context).pop();
                  _onMuteEveryone(currentSession);
                },
              ),
              if (state.roomState.status == mobile_api.RoomStatus.active)
                Builder(
                  builder: (context) {
                    final next = state.roomState
                        .nextParticipantForcePassIdentity(
                          participants: state.participants,
                        );
                    final nextParticipantName = next != null
                        ? state.participants
                              .firstWhereOrNull((p) => p.identity == next)
                              ?.name
                        : null;
                    return MoreOptionsTile<void>(
                      title:
                          'Force pass to ${nextParticipantName ?? 'the next'}',
                      icon: TotemIcons.passToNext,
                      type: MoreOptionsTileType.destructive,
                      onTap:
                          state.roomState.turnState != mobile_api.TurnState.idle
                          ? () {
                              Navigator.of(context).pop();
                              final sessionState = ref.read(
                                currentSessionStateProvider,
                              );
                              if (sessionState != null) {
                                onForcePass(
                                  context,
                                  nextParticipantName,
                                  currentSession,
                                  sessionState,
                                );
                              }
                            }
                          : null,
                    );
                  },
                ),
              if (state.roomState.status == mobile_api.RoomStatus.waitingRoom)
                MoreOptionsTile<void>(
                  title: 'Start session',
                  icon: TotemIcons.arrowForward,
                  type: MoreOptionsTileType.destructive,
                  onTap: () {
                    Navigator.of(context).pop();
                    _onStartSession(context, currentSession);
                  },
                )
              else if (state.roomState.status != mobile_api.RoomStatus.ended)
                MoreOptionsTile<void>(
                  title: 'End session',
                  icon: TotemIcons.cameraOff,
                  type: MoreOptionsTileType.destructive,
                  onTap: state.roomState.status == mobile_api.RoomStatus.active
                      ? () {
                          Navigator.of(context).pop();
                          _onEndSession(context, currentSession);
                        }
                      : null,
                ),
              Text(
                'Session State',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              MoreOptionsTile<void>(
                title: switch (state.roomState.status) {
                  mobile_api.RoomStatus.waitingRoom =>
                    'Session Status: Waiting Room',
                  mobile_api.RoomStatus.active => 'Session Status: Active',
                  mobile_api.RoomStatus.ended => 'Session Status: Ended',
                  _ => 'Session Status: Unknown',
                },
                icon: TotemIcons.checkboxOutlined,
              ),
              MoreOptionsTile<void>(
                title:
                    'Totem Status: '
                    '${state.roomState.turnState.value.uppercaseFirst()}',
                icon: TotemIcons.feedback,
              ),
              Builder(
                builder: (context) {
                  final currentSpeaker = state.roomState.currentSpeaker.value;
                  final String? userName = currentSpeaker != null
                      ? state.participants
                            .firstWhereOrNull(
                              (p) => p.identity == currentSpeaker,
                            )
                            ?.name
                      : null;
                  return MoreOptionsTile<void>(
                    title:
                        'Speaking now: '
                        '${userName ?? 'None'}',
                    icon: TotemIcons.community,
                  );
                },
              ),
            ],
          ].expand((child) => [const SizedBox(height: 10), child]).skip(1).toList(),
        ),
      );

      if (isDialog) return content;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredBox(
            color: theme.colorScheme.surface,
            child: const SheetDragHandle(),
          ),
          Flexible(child: content),
        ],
      );
    }

    if (isDialog || !isKeeper) {
      return buildContent();
    } else {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.95,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return buildContent(scrollController);
        },
      );
    }
  }

  static Future<bool?> showLeaveDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final isKeeper = ref.watch(isCurrentUserKeeperProvider);
            final isEnded = ref.watch(
              currentSessionStateProvider.select(
                (s) => s?.roomState.status == mobile_api.RoomStatus.ended,
              ),
            );
            return ConfirmationDialog(
              content: 'Are you sure you want to leave the session?',
              confirmButtonText: 'Leave session',
              onConfirm: () async {
                TotemRouter.instance.setTabCloseConfirmationEnabled(false);
                Navigator.of(context).pop(true);
              },
              extraButtons: [
                if (isKeeper && !isEnded)
                  ConfirmationDialogButton.outlined(
                    onConfirm: () async {
                      final currentSession = ref.read(currentSessionProvider);
                      if (currentSession == null) return;
                      await _endSession(context, currentSession);
                      TotemRouter.instance.setTabCloseConfirmationEnabled(
                        false,
                      );
                      if (context.mounted) Navigator.of(context).pop(true);
                    },
                    type: ConfirmationDialogType.destructive,
                    child: const Text('End session and Leave'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onMuteEveryone(SessionController session) =>
      session.keeper.muteEveryone();

  @visibleForTesting
  Future<void> onForcePass(
    BuildContext context,
    String? nextParticipantName,
    SessionController session,
    SessionRoomState state,
  ) async {
    if (state.roomState.nextSpeaker.value == null) return;

    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        final theme = Theme.of(context);

        return Consumer(
          builder: (context, ref, child) {
            return ConfirmationDialog(
              title: 'Are you sure?',
              confirmButtonText: 'Force pass',
              content:
                  "This will end the current speaker's turn and give the totem to ${nextParticipantName ?? 'the next participant'}.",
              contentStyle: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              type: ConfirmationDialogType.standard,
              onConfirm: () async {
                try {
                  await session.keeper.forcePassTotem();
                } catch (error) {
                  if (context.mounted) {
                    ErrorHandler.showErrorSnackBar(
                      context,
                      'Failed to perform next totem action',
                    );
                  }
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

  Future<void> _onStartSession(
    BuildContext context,
    SessionController session,
  ) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => ConfirmationDialog(
        title: 'Start session',
        content: 'Are you sure you want to start the session?',
        confirmButtonText: 'Start session',
        type: ConfirmationDialogType.standard,
        onConfirm: () async {
          final success = await session.keeper.startSession();
          if (success && context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  static Future<void> _onEndSession(
    BuildContext context,
    SessionController session,
  ) {
    return showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) {
        return ConfirmationDialog(
          title: 'End session',
          content: 'Are you sure you want to end the session?',
          confirmButtonText: 'End session',
          onConfirm: () async {
            await _endSession(context, session);
            if (context.mounted) Navigator.of(context).pop();
          },
        );
      },
    );
  }

  static Future<void> _endSession(
    BuildContext context,
    SessionController session,
  ) async {
    try {
      await session.keeper.endSession();
    } catch (error) {
      if (!context.mounted) return;
      await ErrorHandler.handleApiError(
        context,
        error,
        onRetry: () async {
          try {
            await session.keeper.endSession();
          } catch (e) {
            // Error already handled by handleApiError
          }
        },
      );
    }
  }
}

enum MoreOptionsTileType { destructive, normal }

class MoreOptionsTile<T> extends StatelessWidget {
  MoreOptionsTile({
    required this.title,
    required this.icon,
    this.onTap,
    this.type = MoreOptionsTileType.normal,
    this.selectedOption,
    this.options,
    this.onOptionChanged,
    this.optionToString,
    this.trailing,
    super.key,
  }) : assert(
         (options != null &&
                 onOptionChanged != null &&
                 optionToString != null) ||
             (options == null &&
                 onOptionChanged == null &&
                 optionToString == null),
         'If options are provided, onOptionChanged and optionToString must also be provided, and vice versa.',
       ),
       assert(
         (options == null && selectedOption == null) || (options != null),
         'If selectedOption is provided, options must also be provided.',
       ),
       assert(
         options == null ||
             selectedOption == null ||
             options.contains(selectedOption),
         'selectedOption must be one of the options provided.',
       );

  final String title;
  final TotemIconData icon;
  final VoidCallback? onTap;
  final MoreOptionsTileType type;

  final T? selectedOption;
  final Iterable<T>? options;
  final ValueChanged<T?>? onOptionChanged;
  final String Function(T)? optionToString;

  final Widget? trailing;

  /// A tile to switch the camera position.
  ///
  /// On desktop platforms, the user can choose the camera device on the action bar
  /// See [SessionActionBar]
  static Widget? camera(CameraFacing? facing, VoidCallback onSwitch) {
    if (isNativeMobile) {
      return MoreOptionsTile<MediaDeviceInfo>(
        title: switch (facing) {
          CameraFacing.front => 'Front',
          CameraFacing.back => 'Back',
          null => 'Camera disabled',
        },
        icon: facing == null ? TotemIcons.cameraOff : TotemIcons.cameraOn,
        trailing: facing != null
            ? IgnorePointer(
                child: IconButton(
                  icon: const Icon(Icons.switch_camera_outlined),
                  onPressed: () {},
                ),
              )
            : null,
        onTap: facing == null ? null : onSwitch,
      );
    }
    return null;
  }

  static Widget? output({
    required bool speakerOn,
    required String? selectedDeviceId,
    required ValueChanged<bool> onSpeakerChanged,
    required ValueChanged<MediaDeviceInfo> onDeviceSelect,
  }) {
    if (isNativeMobile) {
      return MoreOptionsTile<MediaDeviceInfo>(
        title: 'Speaker',
        icon: TotemIcons.speakerOn,
        trailing: IgnorePointer(
          child: Switch.adaptive(value: speakerOn, onChanged: (enabled) {}),
        ),
        onTap: () => onSpeakerChanged(!speakerOn),
      );
    } else {
      return _DesktopAudioOutputTile(
        selectedDeviceId: selectedDeviceId,
        onDeviceSelect: onDeviceSelect,
      );
    }
  }

  static Widget fromMediaDevice({
    required MediaDeviceInfo? device,
    required Iterable<MediaDeviceInfo> options,
    required ValueChanged<MediaDeviceInfo?> onOptionChanged,
    required TotemIconData icon,
  }) {
    return MoreOptionsTile<MediaDeviceInfo>(
      title:
          device?.displayLabel ??
          (options.isEmpty ? 'No Connected Device' : 'Default Device'),
      icon: icon,
      options: options,
      optionToString: (option) => option.displayLabel,
      selectedOption: device,
      onOptionChanged: onOptionChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (options != null && options!.isNotEmpty && options!.length > 1) {
      return ButtonTheme(
        alignedDropdown: true,
        child: DropdownButtonHideUnderline(
          child: Material(
            color: type == MoreOptionsTileType.destructive
                ? theme.colorScheme.errorContainer
                : Colors.white,
            borderRadius: BorderRadius.circular(30),
            child: DropdownButton<T>(
              padding: const EdgeInsetsDirectional.only(start: 0, end: 30),
              isExpanded: true,
              value: selectedOption,
              items: options!
                  .map(
                    (e) => DropdownMenuItem<T>(
                      value: e,
                      child: AutoSizeText(
                        optionToString?.call(e) ?? e.toString(),
                        maxLines: 1,
                      ),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (context) {
                return options!.map((e) {
                  return Row(
                    spacing: 12,
                    children: [
                      SizedBox.square(
                        dimension: 24,
                        child: TotemIcon(icon, size: 24),
                      ),
                      Flexible(
                        child: AutoSizeText(
                          optionToString?.call(e) ?? e.toString(),
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
              onChanged: onOptionChanged,
              borderRadius: BorderRadius.circular(30),
              style: const TextStyle(fontSize: 16, color: Colors.black),
              iconEnabledColor: type == MoreOptionsTileType.destructive
                  ? theme.colorScheme.onErrorContainer
                  : null,
              dropdownColor: Colors.white,
              icon: const SizedBox.square(
                dimension: 16,
                child: TotemIcon(
                  TotemIcons.chevronDown,
                  size: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ListTile(
      leading: SizedBox.square(dimension: 24, child: TotemIcon(icon, size: 24)),
      title: AutoSizeText(
        options?.length == 1
            ? optionToString?.call(options!.first) ?? options!.first.toString()
            : title,
        style: const TextStyle(fontSize: 16),
        maxLines: 1,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      tileColor: type == MoreOptionsTileType.destructive
          ? theme.colorScheme.errorContainer
          : Colors.white,
      textColor: type == MoreOptionsTileType.destructive
          ? theme.colorScheme.onErrorContainer
          : null,
      iconColor: type == MoreOptionsTileType.destructive
          ? theme.colorScheme.onErrorContainer
          : null,
      trailing:
          trailing ??
          (onTap != null ? Icon(Icons.adaptive.arrow_forward) : null),
    );
  }
}

class _DesktopAudioOutputTile extends ConsumerWidget {
  const _DesktopAudioOutputTile({
    required this.selectedDeviceId,
    required this.onDeviceSelect,
  });

  final String? selectedDeviceId;
  final ValueChanged<MediaDeviceInfo> onDeviceSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioOutputs = ref.watch(
      mediaDevicesProvider.select(
        (devices) => (devices.value ?? const <MediaDeviceInfo>[])
            .where(
              (device) =>
                  device.kind == MediaDeviceKind.audioOutput &&
                  device.label.isNotEmpty &&
                  device.label != 'Earpiece',
            )
            .toList(),
      ),
    );
    final selected =
        audioOutputs.firstWhereOrNull(
          (device) => device.id == selectedDeviceId,
        ) ??
        audioOutputs.firstOrNull;

    return MoreOptionsTile.fromMediaDevice(
      device: selected,
      options: audioOutputs,
      onOptionChanged: (value) {
        if (value != null) {
          onDeviceSelect(value);
        }
      },
      icon: TotemIcons.speakerOn,
    );
  }
}

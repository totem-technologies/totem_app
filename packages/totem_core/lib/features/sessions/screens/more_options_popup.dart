import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;
import 'package:totem_core/core/api/api_client/api_client.dart'
    as mobile_api
    show RoomStatus, SessionDetailSchema, TurnState;
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/banned_participants_modal.dart';
import 'package:totem_core/features/sessions/widgets/participant_reorder_modal.dart';
import 'package:totem_core/shared/extensions.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/sheet_drag_handle.dart';

Future<bool?> showLeaveDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return ConfirmationDialog(
        content: 'Are you sure you want to leave the session?',
        confirmButtonText: 'Yes',
        onConfirm: () async {
          TotemRouter.instance.setTabCloseConfirmationEnabled(false);
          Navigator.of(context).pop(true);
        },
      );
    },
  );
}

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
      return SafeArea(
        child: MoreOptions(session: session, isDialog: false),
      );
    },
    largeScreenBuilder: (context) {
      return SizedBox(
        width: 400,
        child: SafeArea(
          child: MoreOptions(session: session, isDialog: true),
        ),
      );
    },
  );
}

class MoreOptions extends ConsumerWidget {
  const MoreOptions({
    required this.session,
    this.isDialog = false,
    super.key,
  });

  final mobile_api.SessionDetailSchema session;
  final bool isDialog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentSession = ref.watch(currentSessionProvider)!;
    final state = ref.watch(currentSessionStateProvider)!;
    final deviceState = ref.watch(
      sessionDeviceControllerProvider(currentSession),
    );

    final isKeeper = currentSession.isCurrentUserKeeper();

    Widget buildContent([ScrollController? scrollController]) {
      final cameraTile = MoreOptionsTile.camera(
        currentSession.devices.localVideoTrack?.currentOptions
            as CameraCaptureOptions?,
        () {
          currentSession.devices.switchCameraPosition();
          Navigator.of(context).pop();
        },
      );

      final outputTile = MoreOptionsTile.output(
        AudioOutputOptions(
          speakerOn: deviceState.isSpeakerphoneEnabled,
          deviceId: deviceState.selectedAudioOutputDeviceId,
        ),
        (options) {
          if (options.speakerOn != null) {
            currentSession.devices.setSpeakerphone(
              options.speakerOn ?? false,
            );
          }
        },
        currentSession.devices.selectAudioOutputDevice,
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
              title: 'Leave Session',
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
                icon: TotemIcons.reorderParticipants,
                onTap: () {
                  Navigator.of(context).pop();
                  showParticipantReorderModals(context);
                },
              ),
              MoreOptionsTile<void>(
                title:
                    'Banned Participants'
                    '${state.roomState.bannedParticipants.isNotEmpty ? ' (${state.roomState.bannedParticipants.length})' : ''}',
                icon: TotemIcons.removePerson,
                onTap: () {
                  Navigator.of(context).pop();
                  showBannedParticipantsModal(
                    context,
                    currentSession,
                    state,
                  );
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
                          participants: state.participantsList,
                        );
                    final nextParticipantName = next != null
                        ? state.participantsList
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
                              onForcePass(
                                context,
                                nextParticipantName,
                                currentSession,
                                state,
                              );
                            }
                          : null,
                    );
                  },
                ),
              if (state.roomState.status == mobile_api.RoomStatus.waitingRoom)
                MoreOptionsTile<void>(
                  title: 'Start Session',
                  icon: TotemIcons.arrowForward,
                  type: MoreOptionsTileType.destructive,
                  onTap: () {
                    Navigator.of(context).pop();
                    _onStartSession(context, currentSession);
                  },
                )
              else if (state.roomState.status != mobile_api.RoomStatus.ended)
                MoreOptionsTile<void>(
                  title: 'End Session',
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
                  final String? userName =
                      state.roomState.currentSpeaker != null
                      ? state.participantsList
                            .firstWhereOrNull(
                              (p) =>
                                  p.identity == state.roomState.currentSpeaker,
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

  Future<void> _onMuteEveryone(SessionController session) =>
      session.keeper.muteEveryone();

  @visibleForTesting
  Future<void> onForcePass(
    BuildContext context,
    String? nextParticipantName,
    SessionController session,
    SessionRoomState state,
  ) async {
    if (state.roomState.nextParticipantIdentity == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return Consumer(
          builder: (context, ref, child) {
            return ConfirmationDialog(
              title: 'Are you sure?',
              confirmButtonText: 'Force pass',
              content:
                  'This will end ${state.roomState.currentSpeaker != null ? "the current speaker's turn" : 'the current turn'} '
                  'and give the totem to ${nextParticipantName ?? 'the next participant'}.',
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
    try {
      await session.keeper.startSession();
    } catch (error) {
      if (!context.mounted) return;
      await ErrorHandler.handleApiError(
        context,
        error,
        onRetry: () async {
          try {
            await session.keeper.startSession();
          } catch (e) {
            // Error already handled by handleApiError
          }
        },
      );
    }
  }

  Future<void> _onEndSession(
    BuildContext context,
    SessionController session,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return ConfirmationDialog(
          title: 'End Session',
          content: 'Are you sure you want to end the session?',
          confirmButtonText: 'End Session',
          onConfirm: () async {
            try {
              await session.keeper.endSession();
              if (!context.mounted) return;
              Navigator.of(context).pop();
            } catch (error) {
              if (!context.mounted) return;
              Navigator.of(context).pop();
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
          },
        );
      },
    );
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
  static Widget? camera(CameraCaptureOptions? options, VoidCallback onSwitch) {
    if (lkPlatformIsMobile()) {
      return MoreOptionsTile<MediaDevice>(
        title: switch (options?.cameraPosition) {
          CameraPosition.front => 'Front',
          CameraPosition.back => 'Back',
          null => 'Camera disabled',
        },
        icon: options == null ? TotemIcons.cameraOff : TotemIcons.cameraOn,
        trailing: options != null
            ? IgnorePointer(
                child: IconButton(
                  icon: const Icon(Icons.switch_camera_outlined),
                  onPressed: () {},
                ),
              )
            : null,
        onTap: switch (options?.cameraPosition) {
          null => null,
          _ => onSwitch,
        },
      );
    }
    return null;
  }

  static Widget? output(
    AudioOutputOptions options,
    ValueChanged<AudioOutputOptions> onSwitch,
    ValueChanged<MediaDevice> onDeviceSelect,
  ) {
    if (lkPlatformIsMobile()) {
      return MoreOptionsTile<MediaDevice>(
        title: 'Speaker',
        icon: TotemIcons.speakerOn,
        trailing: IgnorePointer(
          child: Switch.adaptive(
            value: options.speakerOn ?? false,
            onChanged: (enabled) {},
          ),
        ),
        onTap: () {
          onSwitch(
            options.copyWith(speakerOn: !(options.speakerOn ?? false)),
          );
        },
      );
    } else {
      return _DesktopAudioOutputTile(
        options: options,
        onDeviceSelect: onDeviceSelect,
      );
    }
  }

  static Widget fromMediaDevice({
    required MediaDevice? device,
    required Iterable<MediaDevice> options,
    required ValueChanged<MediaDevice?> onOptionChanged,
    required TotemIconData icon,
  }) {
    return MoreOptionsTile<MediaDevice>(
      title:
          device?.humanReadableLabel ??
          (options.isEmpty ? 'No Connected Device' : 'Default Device'),
      icon: icon,
      options: options,
      optionToString: (option) => option.humanReadableLabel,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
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

class _DesktopAudioOutputTile extends StatefulWidget {
  const _DesktopAudioOutputTile({
    required this.options,
    required this.onDeviceSelect,
  });

  final AudioOutputOptions options;
  final ValueChanged<MediaDevice> onDeviceSelect;

  @override
  State<_DesktopAudioOutputTile> createState() =>
      _DesktopAudioOutputTileState();
}

class _DesktopAudioOutputTileState extends State<_DesktopAudioOutputTile> {
  List<MediaDevice> _audioOutputs = const [];
  StreamSubscription<List<MediaDevice>>? _audioOutputsSubscription;

  @override
  void initState() {
    super.initState();
    _listenToAudioOutputs();
  }

  @override
  void dispose() {
    _audioOutputsSubscription?.cancel();
    super.dispose();
  }

  void _listenToAudioOutputs() {
    _audioOutputsSubscription = Hardware.instance.onDeviceChange.stream.listen(
      _onDeviceChange,
    );

    Hardware.instance.audioOutputs().then((devices) {
      if (!mounted) return;
      setState(() {
        _audioOutputs = _filterAudioOutputs(devices);
      });
    });
  }

  void _onDeviceChange(List<MediaDevice> devices) {
    if (!mounted) return;
    setState(() {
      _audioOutputs = _filterAudioOutputs(devices);
    });
  }

  List<MediaDevice> _filterAudioOutputs(List<MediaDevice> devices) {
    return devices.where((device) {
      return device.kind == 'audiooutput' &&
          device.label.isNotEmpty &&
          device.label != 'Earpiece';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        _audioOutputs.firstWhereOrNull(
          (device) => device.deviceId == widget.options.deviceId,
        ) ??
        _audioOutputs.firstOrNull;

    return MoreOptionsTile.fromMediaDevice(
      device: selected,
      options: _audioOutputs,
      onOptionChanged: (value) {
        if (value != null) {
          widget.onDeviceSelect(value);
        }
      },
      icon: TotemIcons.speakerOn,
    );
  }
}

extension on MediaDevice {
  String get humanReadableLabel {
    if (label.isNotEmpty) {
      return label;
    }
    switch (kind) {
      case 'audioinput':
        return 'Microphone';
      case 'audiooutput':
        return 'Speaker';
      case 'videoinput':
        return 'Camera';
      default:
        return 'Unknown Device';
    }
  }
}

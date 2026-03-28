import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart'
    as mobile_api
    show RoomStatus, SessionDetailSchema, TurnState;
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/widgets/banned_participants_sheet.dart';
import 'package:totem_app/features/sessions/widgets/participant_reorder_sheet.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/extensions.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';
import 'package:totem_app/shared/widgets/sheet_drag_handle.dart';

Future<bool?> showLeaveDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return ConfirmationDialog(
        content: 'Are you sure you want to leave the session?',
        confirmButtonText: 'Yes',
        onConfirm: () async {
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
  return showModalBottomSheet(
    context: context,
    showDragHandle: false,
    backgroundColor: const Color(0xFFF3F1E9),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return SafeArea(
        child: OptionsSheet(session: session),
      );
    },
  );
}

class OptionsSheet extends ConsumerWidget {
  const OptionsSheet({required this.session, super.key});

  final mobile_api.SessionDetailSchema session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentSession = ref.watch(currentSessionProvider)!;
    final state = ref.watch(currentSessionStateProvider)!;
    final deviceState = ref.watch(
      sessionDeviceControllerProvider(currentSession),
    );

    final isKeeper = currentSession.isCurrentUserKeeper();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetDragHandle(),
        Flexible(
          child: ListView(
            padding: const EdgeInsetsDirectional.only(
              start: 20,
              end: 20,
              bottom: 36,
            ),
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            children: <Widget>[
              OptionsSheetTile.camera(
                currentSession.devices.localVideoTrack?.currentOptions
                    as CameraCaptureOptions?,
                () {
                  currentSession.devices.switchCameraPosition();
                  Navigator.of(context).pop();
                },
              ),
              // if (lkPlatformIsDesktop())
              //   MediaDeviceSelectButton(
              //     builder: (context, roomCtx, deviceCtx) {
              //       final audioInputs = deviceCtx.audioInputs;
              //       final selected =
              //           deviceCtx.audioInputs?.firstWhereOrNull(
              //             (e) {
              //               return e.deviceId ==
              //                       (roomCtx
              //                               .localAudioTrack
              //                               ?.currentOptions
              //                               .deviceId ??
              //                           currentSession.selectedAudioDeviceId) &&
              //                   e.label.isNotEmpty;
              //             },
              //           ) ??
              //           deviceCtx.audioInputs?.firstOrNull;
              //       return OptionsSheetTile.fromMediaDevice(
              //         device: selected,
              //         options: audioInputs ?? [],
              //         onOptionChanged: (value) {
              //           if (value != null) {
              //             currentSession.selectAudioDevice(value);
              //           }
              //         },
              //         icon: TotemIcons.microphoneOn,
              //       );
              //     },
              //   ),
              OptionsSheetTile.output(
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
              ),
              OptionsSheetTile<void>(
                title: 'Leave Session',
                icon: TotemIcons.leaveCall,
                type: OptionsSheetTileType.destructive,
                onTap: () async {
                  final navigator = Navigator.of(context)..pop();
                  final shouldLeave = await showLeaveDialog(context) ?? false;
                  if (shouldLeave && navigator.mounted) {
                    currentSession.leave();
                    popOrHome(navigator.context);
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
                if (state.roomState.status == mobile_api.RoomStatus.waitingRoom)
                  OptionsSheetTile<void>(
                    title: 'Start session',
                    icon: TotemIcons.feedback,
                    onTap: () {
                      Navigator.of(context).pop();
                      _onStartSession(context, currentSession);
                    },
                  ),
                OptionsSheetTile<void>(
                  title: 'Reorder Participants',
                  icon: TotemIcons.reorderParticipants,
                  onTap: () {
                    Navigator.of(context).pop();
                    showParticipantReorderWidget(
                      context,
                      currentSession,
                      state,
                      session,
                    );
                  },
                ),
                OptionsSheetTile<void>(
                  title:
                      'Banned Participants'
                      '${state.roomState.bannedParticipants.isNotEmpty ? ' (${state.roomState.bannedParticipants.length})' : ''}',
                  icon: TotemIcons.removePerson,
                  onTap: () {
                    Navigator.of(context).pop();
                    showBannedParticipantsSheet(context, currentSession, state);
                  },
                ),
                OptionsSheetTile<void>(
                  title: 'Mute everyone',
                  icon: TotemIcons.microphoneOff,
                  type: OptionsSheetTileType.destructive,
                  onTap: () {
                    Navigator.of(context).pop();
                    _onMuteEveryone(currentSession);
                  },
                ),
                if (state.roomState.status == mobile_api.RoomStatus.active)
                  Builder(
                    builder: (context) {
                      final next =
                          state.roomState.nextParticipantForcePassIdentity;
                      final nextParticipantName = next != null
                          ? state.participantsList
                                .firstWhereOrNull((p) => p.identity == next)
                                ?.name
                          : null;
                      return OptionsSheetTile<void>(
                        title:
                            'Force pass to ${nextParticipantName ?? 'the next'}',
                        icon: TotemIcons.passToNext,
                        type: OptionsSheetTileType.destructive,
                        onTap:
                            state.roomState.turnState !=
                                mobile_api.TurnState.idle
                            ? () {
                                Navigator.of(context).pop();
                                _onNextTotemAction(
                                  context,
                                  currentSession,
                                  state,
                                );
                              }
                            : null,
                      );
                    },
                  ),
                if (state.roomState.status != mobile_api.RoomStatus.ended)
                  OptionsSheetTile<void>(
                    title: 'End Session',
                    icon: TotemIcons.cameraOff,
                    type: OptionsSheetTileType.destructive,
                    onTap:
                        state.roomState.status == mobile_api.RoomStatus.active
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
                OptionsSheetTile<void>(
                  title: switch (state.roomState.status) {
                    mobile_api.RoomStatus.waitingRoom =>
                      'Session Status: Waiting Room',
                    mobile_api.RoomStatus.active => 'Session Status: Active',
                    mobile_api.RoomStatus.ended => 'Session Status: Ended',
                    _ => 'Session Status: Unknown',
                  },
                  icon: TotemIcons.checkboxOutlined,
                ),
                OptionsSheetTile<void>(
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
                                    p.identity ==
                                    state.roomState.currentSpeaker,
                              )
                              ?.name
                        : null;
                    return OptionsSheetTile<void>(
                      title:
                          'Speaking now: '
                          '${userName ?? 'None'}',
                      icon: TotemIcons.community,
                    );
                  },
                ),
              ],
            ].expand((child) => [child, const SizedBox(height: 10)]).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _onMuteEveryone(SessionController session) =>
      session.keeper.muteEveryone();

  Future<void> _onNextTotemAction(
    BuildContext context,
    SessionController session,
    SessionRoomState state,
  ) async {
    if (state.roomState.nextParticipantIdentity == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final nextParticipantIdentity =
            state.roomState.nextParticipantIdentity!;

        return Consumer(
          builder: (context, ref, child) {
            final nextParticipantName =
                state.participantsList
                    .firstWhereOrNull(
                      (p) => p.identity == nextParticipantIdentity,
                    )
                    ?.name ??
                ref
                    .watch(userProfileProvider(nextParticipantIdentity))
                    .whenData((user) => user.name)
                    .value;
            return ConfirmationDialog(
              title: null,
              confirmButtonText: 'Force pass',
              content:
                  'Are you sure you want to force pass the totem? '
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
    return showDialog<void>(
      context: context,
      builder: (context) {
        return ConfirmationDialog(
          title: 'Start Session',
          content: 'Are you sure you want to start the session?',
          confirmButtonText: 'Start Session',
          type: ConfirmationDialogType.standard,
          onConfirm: () async {
            try {
              await session.keeper.startSession();
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
                    await session.keeper.startSession();
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

enum OptionsSheetTileType { destructive, normal }

class OptionsSheetTile<T> extends StatelessWidget {
  OptionsSheetTile({
    required this.title,
    required this.icon,
    this.onTap,
    this.type = OptionsSheetTileType.normal,
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
         (options != null &&
                 selectedOption != null &&
                 options.contains(selectedOption)) ||
             (options == null),
         'selectedOption must be one of the options provided.',
       );

  final String title;
  final TotemIconData icon;
  final VoidCallback? onTap;
  final OptionsSheetTileType type;

  final T? selectedOption;
  final Iterable<T>? options;
  final ValueChanged<T?>? onOptionChanged;
  final String Function(T)? optionToString;

  final Widget? trailing;

  static Widget camera(CameraCaptureOptions? options, VoidCallback onSwitch) {
    return OptionsSheetTile<MediaDevice>(
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

  static Widget output(
    AudioOutputOptions options,
    ValueChanged<AudioOutputOptions> onSwitch,
    ValueChanged<MediaDevice> onDeviceSelect,
  ) {
    if (lkPlatformIsMobile()) {
      return OptionsSheetTile<MediaDevice>(
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
      // TODO(bdlukaa): Implement audio output selection for desktop platforms.
      return const SizedBox.shrink();
      // return MediaDeviceSelectButton(
      //   builder: (context, roomCtx, deviceCtx) {
      //     final audioOutputs = deviceCtx.audioOutputs?.where((
      //       device,
      //     ) {
      //       return device.label.isNotEmpty && device.label != 'Earpiece';
      //     });
      //     final selected =
      //         deviceCtx.audioOutputs?.firstWhereOrNull(
      //           (e) {
      //             return e.deviceId == options.deviceId && e.label.isNotEmpty;
      //           },
      //         ) ??
      //         deviceCtx.audioOutputs?.firstOrNull;
      //     return OptionsSheetTile.fromMediaDevice(
      //       device: selected,
      //       options: audioOutputs ?? [],
      //       onOptionChanged: (value) {
      //         if (value != null) {
      //           onDeviceSelect(value);
      //         }
      //       },
      //       icon: TotemIcons.speaker,
      //     );
      //   },
      // );
    }
  }

  static Widget fromMediaDevice({
    required MediaDevice? device,
    required Iterable<MediaDevice> options,
    required ValueChanged<MediaDevice?> onOptionChanged,
    required TotemIconData icon,
  }) {
    return OptionsSheetTile<MediaDevice>(
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
      return Material(
        color: type == OptionsSheetTileType.destructive
            ? theme.colorScheme.errorContainer
            : Colors.white,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: TotemIcon(icon, size: 24),
              ),
              Expanded(
                child: DropdownButton<T>(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12,
                  ),
                  isExpanded: true,
                  value: selectedOption,
                  items: options
                      ?.map(
                        (e) => DropdownMenuItem<T>(
                          value: e,
                          child: AutoSizeText(
                            optionToString?.call(e) ?? e.toString(),
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onOptionChanged,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(30),
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                  iconEnabledColor: type == OptionsSheetTileType.destructive
                      ? theme.colorScheme.onErrorContainer
                      : null,
                  dropdownColor: Colors.white,
                  icon: const SizedBox.square(
                    dimension: 16,
                    child: TotemIcon(TotemIcons.chevronDown, size: 16),
                  ),
                ),
              ),
            ],
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
      tileColor: type == OptionsSheetTileType.destructive
          ? theme.colorScheme.errorContainer
          : Colors.white,
      textColor: type == OptionsSheetTileType.destructive
          ? theme.colorScheme.onErrorContainer
          : null,
      iconColor: type == OptionsSheetTileType.destructive
          ? theme.colorScheme.onErrorContainer
          : null,
      trailing:
          trailing ??
          (onTap != null ? Icon(Icons.adaptive.arrow_forward) : null),
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

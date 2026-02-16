import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/services/session_service.dart';
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
  SessionDetailSchema session,
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

  final SessionDetailSchema session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentSession = ref.watch(currentSessionProvider)!;
    final state = ref.watch(currentSessionStateProvider)!;

    final isKeeper = currentSession.isKeeper();

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
            children: [
              OptionsSheetTile.camera(
                currentSession.localVideoTrack?.currentOptions
                    as CameraCaptureOptions?,
                () {
                  currentSession.switchCameraPosition();
                  Navigator.of(context).pop();
                },
              ),
              if (lkPlatformIsDesktop())
                MediaDeviceSelectButton(
                  builder: (context, roomCtx, deviceCtx) {
                    final audioInputs = deviceCtx.audioInputs;
                    final selected =
                        deviceCtx.audioInputs?.firstWhereOrNull(
                          (e) {
                            return e.deviceId ==
                                    (roomCtx
                                            .localAudioTrack
                                            ?.currentOptions
                                            .deviceId ??
                                        currentSession.selectedAudioDeviceId) &&
                                e.label.isNotEmpty;
                          },
                        ) ??
                        deviceCtx.audioInputs?.firstOrNull;
                    return OptionsSheetTile.fromMediaDevice(
                      device: selected,
                      options: audioInputs ?? [],
                      onOptionChanged: (value) {
                        if (value != null) {
                          currentSession.selectAudioDevice(value);
                        }
                      },
                      icon: TotemIcons.microphoneOn,
                    );
                  },
                ),
              OptionsSheetTile.output(
                AudioOutputOptions(
                  speakerOn: currentSession.isSpeakerphoneEnabled,
                  deviceId: currentSession.selectedAudioOutputDeviceId,
                ),
                (options) {
                  if (options.speakerOn != null) {
                    currentSession.setSpeakerphone(options.speakerOn ?? false);
                  }
                },
                currentSession.selectAudioOutputDevice,
              ),
              OptionsSheetTile<void>(
                title: 'Leave Session',
                icon: TotemIcons.leaveCall,
                type: OptionsSheetTileType.destructive,
                onTap: () async {
                  final navigator = Navigator.of(context)..pop();
                  final shouldLeave = await showLeaveDialog(context) ?? false;
                  if (shouldLeave && navigator.mounted) {
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
                if (state.sessionState.status == SessionStatus.waiting)
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
                  title: 'Mute everyone',
                  icon: TotemIcons.microphoneOff,
                  type: OptionsSheetTileType.destructive,
                  onTap: () {
                    Navigator.of(context).pop();
                    _onMuteEveryone(currentSession);
                  },
                ),
                if (state.sessionState.status == SessionStatus.started)
                  Builder(
                    builder: (context) {
                      final next = state.sessionState.nextParticipantIdentity;
                      final nextParticipantName = next != null
                          ? state.participants
                                .firstWhereOrNull((p) => p.identity == next)
                                ?.name
                          : null;
                      return OptionsSheetTile<void>(
                        title: switch (state.sessionState.totemStatus) {
                          TotemStatus.passing =>
                            'Accept Totem for ${nextParticipantName ?? 'Next'}',
                          TotemStatus.accepted =>
                            'Pass Totem to ${nextParticipantName ?? 'Next'}',
                          _ => 'Next Totem Action',
                        },
                        icon: TotemIcons.passToNext,
                        type: OptionsSheetTileType.destructive,
                        onTap:
                            state.sessionState.status ==
                                    SessionStatus.started &&
                                state.sessionState.totemStatus !=
                                    TotemStatus.none
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
                if (state.sessionState.status != SessionStatus.ended)
                  OptionsSheetTile<void>(
                    title: 'End Session',
                    icon: TotemIcons.cameraOff,
                    type: OptionsSheetTileType.destructive,
                    onTap: state.sessionState.status == SessionStatus.started
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
                  title:
                      'Session Status: '
                      '${state.sessionState.status.name.uppercaseFirst()}',
                  icon: TotemIcons.checkboxOutlined,
                ),
                OptionsSheetTile<void>(
                  title:
                      'Totem Status: '
                      '${state.sessionState.totemStatus.name.uppercaseFirst()}',
                  icon: TotemIcons.feedback,
                ),
                Builder(
                  builder: (context) {
                    final String? userName =
                        state.sessionState.speakingNow != null
                        ? state.participants
                              .firstWhereOrNull(
                                (p) =>
                                    p.identity ==
                                    state.sessionState.speakingNow,
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

  Future<void> _onMuteEveryone(Session session) => session.muteEveryone();

  Future<void> _onNextTotemAction(
    BuildContext context,
    Session session,
    SessionRoomState state,
  ) async {
    if (state.sessionState.nextParticipantIdentity == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final nextParticipantIdentity =
            state.sessionState.nextParticipantIdentity!;

        return Consumer(
          builder: (context, ref, child) {
            final nextParticipantName =
                state.participants
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
              confirmButtonText: switch (state.sessionState.totemStatus) {
                TotemStatus.passing => 'Accept Totem',
                TotemStatus.accepted => 'Pass Totem',
                _ => 'Proceed',
              },
              content: switch (state.sessionState.totemStatus) {
                TotemStatus.passing =>
                  'Accept the totem on behalf of '
                      '${nextParticipantName ?? 'the next participant'}?',
                TotemStatus.accepted =>
                  'Pass the totem to '
                      '${nextParticipantName ?? 'the next participant'}?',
                _ =>
                  'Proceed with the next totem action for '
                      '${nextParticipantName ?? 'the next participant'}?',
              },
              contentStyle: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              type: ConfirmationDialogType.standard,
              onConfirm: () async {
                try {
                  if (state.sessionState.totemStatus == TotemStatus.passing) {
                    await session.acceptTotem();
                    return;
                  } else if (state.sessionState.totemStatus ==
                      TotemStatus.accepted) {
                    await session.passTotem();
                    return;
                  }
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

  Future<void> _onStartSession(BuildContext context, Session session) async {
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
              await session.startSession();
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
                    await session.startSession();
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

  Future<void> _onEndSession(BuildContext context, Session session) async {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return ConfirmationDialog(
          title: 'End Session',
          content: 'Are you sure you want to end the session?',
          confirmButtonText: 'End Session',
          onConfirm: () async {
            try {
              await session.endSession();
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
                    await session.endSession();
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

Future<void> showPrejoinOptionsSheet(
  BuildContext context, {
  required CameraCaptureOptions? cameraOptions,
  required AudioCaptureOptions audioOptions,
  required AudioOutputOptions audioOutputOptions,
  required ValueChanged<CameraCaptureOptions> onCameraChanged,
  required ValueChanged<AudioCaptureOptions> onAudioChanged,
  required ValueChanged<AudioOutputOptions> onAudioOutputChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    builder: (context) {
      return PrejoinOptionsSheet(
        onCameraChanged: onCameraChanged,
        onAudioChanged: onAudioChanged,
        onAudioOutputChanged: onAudioOutputChanged,
        cameraOptions: cameraOptions,
        audioOptions: audioOptions,
        audioOutputOptions: audioOutputOptions,
      );
    },
  );
}

class PrejoinOptionsSheet extends StatelessWidget {
  const PrejoinOptionsSheet({
    required this.cameraOptions,
    required this.audioOptions,
    required this.audioOutputOptions,
    required this.onCameraChanged,
    required this.onAudioChanged,
    required this.onAudioOutputChanged,
    super.key,
  });

  final CameraCaptureOptions? cameraOptions;
  final AudioCaptureOptions audioOptions;
  final AudioOutputOptions audioOutputOptions;

  final ValueChanged<CameraCaptureOptions> onCameraChanged;
  final ValueChanged<AudioCaptureOptions> onAudioChanged;
  final ValueChanged<AudioOutputOptions> onAudioOutputChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.only(
        start: 20,
        end: 20,
        bottom: 36,
      ),
      children: [
        const SheetDragHandle(),
        OptionsSheetTile.camera(
          cameraOptions,
          () {
            onCameraChanged(
              cameraOptions?.copyWith(
                    cameraPosition: cameraOptions?.cameraPosition.switched(),
                  ) ??
                  Session.defaultCameraOptions,
            );
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 14),
        OptionsSheetTile.output(
          audioOutputOptions,
          (options) {
            onAudioOutputChanged(options);
            Navigator.of(context).pop();
          },
          (device) {
            onAudioOutputChanged(
              audioOutputOptions.copyWith(deviceId: device.deviceId),
            );
            Navigator.of(context).pop();
          },
        ),
      ],
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
          ? IconButton(
              icon: const Icon(Icons.switch_camera_outlined),
              onPressed: onSwitch,
            )
          : null,
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
        icon: TotemIcons.speaker,
        trailing: Switch.adaptive(
          value: options.speakerOn ?? false,
          onChanged: (enabled) {
            onSwitch(
              options.copyWith(speakerOn: enabled),
            );
          },
        ),
      );
    } else {
      return MediaDeviceSelectButton(
        builder: (context, roomCtx, deviceCtx) {
          final audioOutputs = deviceCtx.audioOutputs?.where((
            device,
          ) {
            return device.label.isNotEmpty && device.label != 'Earpiece';
          });
          final selected =
              deviceCtx.audioOutputs?.firstWhereOrNull(
                (e) {
                  return e.deviceId == options.deviceId && e.label.isNotEmpty;
                },
              ) ??
              deviceCtx.audioOutputs?.firstOrNull;
          return OptionsSheetTile.fromMediaDevice(
            device: selected,
            options: audioOutputs ?? [],
            onOptionChanged: (value) {
              if (value != null) {
                onDeviceSelect(value);
              }
            },
            icon: TotemIcons.speaker,
          );
        },
      );
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
      trailing: onTap != null ? const Icon(Icons.arrow_forward_ios) : trailing,
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

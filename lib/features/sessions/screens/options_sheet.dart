import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';

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
  VoidCallback? onStartSession,
) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF3F1E9),
    builder: (context) {
      return OptionsSheet(
        onStartSession: onStartSession,
      );
    },
  );
}

class OptionsSheet extends StatelessWidget {
  const OptionsSheet({required this.onStartSession, super.key});

  final VoidCallback? onStartSession;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 20,
        end: 20,
        top: 10,
        bottom: 36,
      ),
      child: Column(
        spacing: 10,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MediaDeviceSelectButton(
            builder: (context, roomCtx, deviceCtx) {
              final videoInputs = deviceCtx.videoInputs;
              final selected =
                  deviceCtx.videoInputs?.firstWhereOrNull(
                    (e) {
                      return e.deviceId ==
                              deviceCtx.selectedVideoInputDeviceId &&
                          e.label.isNotEmpty;
                    },
                  ) ??
                  deviceCtx.videoInputs?.firstOrNull;
              return OptionsSheetTile<MediaDevice>(
                title: selected?.humanReadableLabel ?? 'Default Camera',
                icon: TotemIcons.cameraOn,
                options: videoInputs?.toList(),
                optionToString: (option) => option.humanReadableLabel,
                selectedOption: selected,
                onOptionChanged: (value) {
                  if (value != null) {
                    // TODO(bdlukaa): Revisit this in the future
                    // https://github.com/livekit/client-sdk-flutter/issues/863
                    final userTrack = roomCtx.room.localParticipant
                        ?.getTrackPublications()
                        .firstWhereOrNull(
                          (track) => track.kind == TrackType.VIDEO,
                        )
                        ?.track;
                    userTrack?.restartTrack(
                      CameraCaptureOptions(
                        deviceId: value.deviceId,
                      ),
                    );
                    deviceCtx.selectVideoInput(value);
                  }
                },
              );
            },
          ),
          MediaDeviceSelectButton(
            builder: (context, roomCtx, deviceCtx) {
              final audioInputs = deviceCtx.audioInputs;
              final selected =
                  deviceCtx.audioInputs?.firstWhereOrNull(
                    (e) {
                      return e.deviceId ==
                              deviceCtx.selectedAudioInputDeviceId &&
                          e.label.isNotEmpty;
                    },
                  ) ??
                  deviceCtx.audioInputs?.firstOrNull;
              return OptionsSheetTile<MediaDevice>(
                title: selected?.label ?? 'Default Microphone',
                options: audioInputs?.toList(),
                optionToString: (option) => option.humanReadableLabel,
                selectedOption: selected,
                onOptionChanged: (value) {
                  if (value != null) {
                    deviceCtx.selectAudioInput(value);
                  }
                },
                icon: TotemIcons.microphoneOn,
              );
            },
          ),
          MediaDeviceSelectButton(
            builder: (context, roomCtx, deviceCtx) {
              final audioOutputs = deviceCtx.audioOutputs;
              final selected =
                  deviceCtx.audioOutputs?.firstWhereOrNull(
                    (e) {
                      return e.deviceId ==
                              deviceCtx.selectedAudioOutputDeviceId &&
                          e.label.isNotEmpty;
                    },
                  ) ??
                  deviceCtx.audioOutputs?.firstOrNull;
              return OptionsSheetTile<MediaDevice>(
                title: selected?.label ?? 'Default Speaker',
                options: audioOutputs?.toList(),
                optionToString: (option) => option.humanReadableLabel,
                selectedOption: selected,
                onOptionChanged: (value) {
                  if (value != null) {
                    deviceCtx.selectAudioOutput(value);
                  }
                },
                icon: TotemIcons.speaker,
              );
            },
          ),
          if (onStartSession != null)
            OptionsSheetTile<void>(
              title: 'Start session',
              icon: TotemIcons.arrowForward,
              onTap: () async {
                onStartSession!();
              },
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
        ],
      ),
    );
  }
}

enum OptionsSheetTileType {
  destructive,
  normal,
}

class OptionsSheetTile<T> extends StatelessWidget {
  const OptionsSheetTile({
    required this.title,
    required this.icon,
    this.onTap,
    this.type = OptionsSheetTileType.normal,
    this.selectedOption,
    this.options,
    this.onOptionChanged,
    this.optionToString,
    super.key,
  });

  final String title;
  final TotemIconData icon;
  final VoidCallback? onTap;
  final OptionsSheetTileType type;

  final T? selectedOption;
  final List<T>? options;
  final ValueChanged<T?>? onOptionChanged;
  final String Function(T)? optionToString;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (options != null && options!.isNotEmpty && options!.length > 1) {
      return Container(
        decoration: BoxDecoration(
          color: type == OptionsSheetTileType.destructive
              ? theme.colorScheme.errorContainer
              : Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 24,
              child: TotemIcon(icon, size: 24),
            ),
            Expanded(
              child: DropdownButton<T>(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
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
      );
    }
    return ListTile(
      leading: SizedBox.square(dimension: 24, child: TotemIcon(icon, size: 24)),
      title: AutoSizeText(
        options?.length == 1 ? options!.first.toString() : title,
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

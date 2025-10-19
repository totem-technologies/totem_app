import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
//
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
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
  MediaDeviceContext deviceContext,
  RoomContext roomContext,
) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF3F1E9),
    builder: (context) {
      return ChangeNotifierProvider.value(
        value: deviceContext,
        child: ChangeNotifierProvider.value(
          value: roomContext,
          child: const OptionsSheet(),
        ),
      );
    },
  );
}

class OptionsSheet extends StatelessWidget {
  const OptionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaDevice = MediaDeviceContext.of(context)!;
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
          Builder(
            builder: (context) {
              final videoInputs = mediaDevice.videoInputs;
              final selected = mediaDevice.videoInputs?.firstWhereOrNull((e) {
                return e.deviceId == mediaDevice.selectedVideoInputDeviceId;
              });
              return OptionsSheetTile<MediaDevice>(
                title: selected?.label ?? 'Default Camera',
                icon: TotemIcons.cameraOn,
                options: videoInputs?.toList(),
                selectedOption: selected,
                onOptionChanged: (value) {
                  if (value != null) {
                    mediaDevice.selectVideoInput(value);
                  }
                },
              );
            },
          ),
          Builder(
            builder: (context) {
              final audioInputs = mediaDevice.audioInputs;
              final selected = mediaDevice.audioInputs?.firstWhereOrNull((e) {
                return e.deviceId == mediaDevice.selectedAudioInputDeviceId;
              });
              return OptionsSheetTile<MediaDevice>(
                title: selected?.label ?? 'Default Microphone',
                options: audioInputs?.toList(),
                selectedOption: selected,
                onOptionChanged: (value) {
                  if (value != null) {
                    mediaDevice.selectAudioInput(value);
                  }
                },
                icon: TotemIcons.microphoneOn,
              );
            },
          ),
          Builder(
            builder: (context) {
              final audioOutputs = mediaDevice.audioOutputs;
              final selected = mediaDevice.audioOutputs?.firstWhereOrNull((e) {
                return e.deviceId == mediaDevice.selectedAudioOutputDeviceId;
              });
              return OptionsSheetTile<MediaDevice>(
                title: selected?.label ?? 'Default Speaker',
                options: audioOutputs?.toList(),
                selectedOption: selected,
                onOptionChanged: (value) {
                  if (value != null) {
                    mediaDevice.selectAudioOutput(value);
                  }
                },
                icon: TotemIcons.speaker,
              );
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
    super.key,
  });

  final String title;
  final TotemIconData icon;
  final VoidCallback? onTap;
  final OptionsSheetTileType type;

  final T? selectedOption;
  final List<T>? options;
  final ValueChanged<T?>? onOptionChanged;

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
                        child: AutoSizeText(e.toString(), maxLines: 1),
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

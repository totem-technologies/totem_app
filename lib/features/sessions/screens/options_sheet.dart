import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/features/profile/repositories/user_repository.dart';
import 'package:totem_app/features/sessions/models/session_state.dart';
import 'package:totem_app/features/sessions/services/livekit_service.dart';
import 'package:totem_app/features/sessions/widgets/participant_reorder_widget.dart';
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
  LiveKitState state,
  LiveKitService session,
  EventDetailSchema event,
) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF3F1E9),
    isScrollControlled: true,
    builder: (context) {
      return OptionsSheet(session: session, state: state, event: event);
    },
  );
}

class OptionsSheet extends StatelessWidget {
  const OptionsSheet({
    required this.state,
    required this.session,
    required this.event,
    super.key,
  });

  final LiveKitState state;
  final LiveKitService session;
  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.only(
        start: 20,
        end: 20,
        top: 10,
        bottom: 36,
      ),
      children: [
        MediaDeviceSelectButton(
          builder: (context, roomCtx, deviceCtx) {
            final videoInputs = deviceCtx.videoInputs;
            final selected =
                deviceCtx.videoInputs?.firstWhereOrNull(
                  (e) {
                    return e.deviceId == deviceCtx.selectedVideoInputDeviceId &&
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
              onOptionChanged: (value) async {
                if (value != null) {
                  // TODO(bdlukaa): Revisit this in the future
                  // https://github.com/livekit/client-sdk-flutter/issues/863
                  final userTrack = roomCtx.room.localParticipant
                      ?.getTrackPublications()
                      .firstWhereOrNull(
                        (track) => track.kind == TrackType.VIDEO,
                      )
                      ?.track;
                  if (userTrack != null) {
                    unawaited(
                      userTrack.restartTrack(
                        CameraCaptureOptions(
                          deviceId: value.deviceId,
                        ),
                      ),
                    );
                  } else {
                    await roomCtx.room.localParticipant?.publishVideoTrack(
                      await LocalVideoTrack.createCameraTrack(),
                    );
                  }
                  await deviceCtx.selectVideoInput(value);
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
                    return e.deviceId == deviceCtx.selectedAudioInputDeviceId &&
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

        if (session.isKeeper()) ...[
          Text(
            'Keeper Settings',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (state.sessionState.status == SessionStatus.waiting)
            OptionsSheetTile<void>(
              title: 'Start session',
              icon: TotemIcons.arrowForward,
              onTap: session.startSession,
            ),
          OptionsSheetTile<void>(
            title: 'Reorder Participants',
            icon: TotemIcons.reorderParticipants,
            onTap: () async {
              Navigator.of(context).pop();
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: const Color(0xFFF3F1E9),
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: ParticipantReorderWidget(
                    session: session,
                    state: state,
                    event: event,
                  ),
                ),
              );
            },
          ),
          OptionsSheetTile<void>(
            title: 'Pass to Next',
            icon: TotemIcons.passToNext,
            type: OptionsSheetTileType.destructive,
            onTap: state.sessionState.status == SessionStatus.started
                ? () => _onPassToNext(context)
                : null,
          ),
          OptionsSheetTile<void>(
            title: 'End Session',
            icon: TotemIcons.cameraOff,
            type: OptionsSheetTileType.destructive,
            onTap: state.sessionState.status == SessionStatus.started
                ? () => _onEndSession(context)
                : null,
          ),
        ],
      ].expand((x) => [x, const SizedBox(height: 10)]).toList(),
    );
  }

  Future<void> _onPassToNext(BuildContext context) async {
    if (state.sessionState.nextParticipantIdentity == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final nextParticipantIdentity =
            state.sessionState.nextParticipantIdentity!;
        return Consumer(
          builder: (context, ref, child) {
            final user = ref.watch(
              userProfileProvider(nextParticipantIdentity),
            );
            return ConfirmationDialog(
              title: null,
              confirmButtonText: 'Pass',
              content:
                  'Pass totem to '
                  // Need to ignore because text is too long. Will be fixed
                  // when we add localizations.
                  // ignore: lines_longer_than_80_chars
                  '${user.whenData((user) => user.name).value ?? 'the next participant'}?',
              contentStyle: theme.textTheme.titleMedium,
              type: ConfirmationDialogType.standard,
              onConfirm: session.passTotem,
            );
          },
        );
      },
    );
  }

  Future<void> _onEndSession(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return ConfirmationDialog(
          title: 'End Session',
          content: 'Are you sure you want to end the session?',
          confirmButtonText: 'End Session',
          onConfirm: () async {
            await session.endSession();
            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
        );
      },
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
      trailing: onTap != null ? const Icon(Icons.arrow_forward_ios) : null,
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

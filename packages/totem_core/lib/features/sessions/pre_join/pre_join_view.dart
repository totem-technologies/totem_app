import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/media/livekit_local_media.dart';
import 'package:totem_core/features/sessions/media/livekit_microphone_level.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_preview_card.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/session_keyboard_shortcuts.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_view.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/circle_icon_button.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

class PreJoinView extends StatelessWidget {
  const PreJoinView({
    required this.mediaState,
    required this.locked,
    required this.onToggleCamera,
    required this.onToggleMicrophone,
    required this.onToggleSpeaker,
    required this.onCameraFacingChanged,
    required this.onCameraDeviceSelected,
    required this.joinCard,
    required this.previewKey,
    required this.controlsKey,
    this.waiting = false,
    this.onLeave,
    super.key,
  });

  final PreJoinMediaState mediaState;
  final bool locked;
  final Widget joinCard;
  final GlobalKey previewKey;
  final GlobalKey controlsKey;
  final bool waiting;
  final VoidCallback? onLeave;
  final AsyncCallback onToggleCamera;
  final AsyncCallback onToggleMicrophone;
  final VoidCallback onToggleSpeaker;
  final ValueChanged<CameraFacing> onCameraFacingChanged;
  final ValueChanged<MediaDeviceInfo> onCameraDeviceSelected;

  @override
  Widget build(BuildContext context) {
    final preferences = mediaState.preferences;
    final previewAudioTrack = mediaState.microphone.track;
    final cameraPreview = KeyedSubtree(
      key: previewKey,
      child: Container(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 40),
        alignment: AlignmentDirectional.center,
        child: Semantics(
          label:
              'Your video preview, camera ${preferences.isCameraOn ? 'on' : 'off'}',
          image: true,
          child: LocalParticipantCard(
            isCameraOn: preferences.isCameraOn,
            videoTrack: mediaState.camera.track,
          ),
        ),
      ),
    );
    final actionBar = KeyedSubtree(
      key: controlsKey,
      child: SessionKeyboardShortcuts(
        enableChatShortcut: false,
        onToggleMicrophone: locked ? null : onToggleMicrophone,
        onToggleCamera: locked ? null : onToggleCamera,
        child: PrejoinActionBar(
          locked: locked,
          microphoneLevel: previewAudioTrack == null
              ? null
              : (color, iconSize, barCount) => LiveKitMicrophoneLevel.preview(
                  previewAudioTrack,
                  color: color,
                  iconSize: iconSize,
                  barCount: barCount,
                ),
          isMicOn: preferences.isMicOn,
          onToggleMic: onToggleMicrophone,
          isSpeakerOn: preferences.isSpeakerOn,
          onToggleSpeaker: onToggleSpeaker,
          isCameraOn: preferences.isCameraOn,
          onToggleCamera: onToggleCamera,
          cameraFacing: preferences.cameraOptions.cameraPosition.toFacing(),
          selectedCameraDeviceId: preferences.cameraOptions.deviceId,
          onCameraFacingChanged: onCameraFacingChanged,
          onCameraDeviceSelected: onCameraDeviceSelected,
        ),
      ),
    );
    if (waiting) {
      return SafeArea(
        child: SessionWaitingView(
          preview: cameraPreview,
          controls: actionBar,
          card: joinCard,
          onLeave: onLeave,
        ),
      );
    }
    return RoomBackground(
      overlayStyle: SystemUiOverlayStyle.dark,
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: CircleIconButton(
              margin: const EdgeInsetsDirectional.only(start: 20, top: 20),
              icon: TotemIcons.arrowBack,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => TotemRouter.instance.popOrHome(context),
            ),
          ),
          extendBodyBehindAppBar: false,
          body: Padding(
            padding: const EdgeInsetsDirectional.all(20),
            child: ViewportResolver(
              builder: (context, viewportKind) {
                return switch (viewportKind) {
                  ViewportKind.smallLandscape => Row(
                    spacing: 18,
                    children: [
                      Expanded(child: cameraPreview),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 18,
                            children: [joinCard, actionBar],
                          ),
                        ),
                      ),
                    ],
                  ),

                  _ => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 18,
                    children: [
                      Expanded(child: cameraPreview),
                      joinCard,
                      actionBar,
                    ],
                  ),
                };
              },
            ),
          ),
        ),
      ),
    );
  }
}

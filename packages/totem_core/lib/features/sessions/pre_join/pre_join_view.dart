import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/participant_card.dart';
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
    required this.onCameraPositionChanged,
    required this.onCameraDeviceSelected,
    required this.joinCard,
    super.key,
  });

  final PreJoinMediaState mediaState;
  final bool locked;
  final Widget joinCard;
  final AsyncCallback onToggleCamera;
  final AsyncCallback onToggleMicrophone;
  final VoidCallback onToggleSpeaker;
  final ValueChanged<CameraPosition> onCameraPositionChanged;
  final ValueChanged<MediaDevice> onCameraDeviceSelected;

  @override
  Widget build(BuildContext context) {
    final preferences = mediaState.preferences;
    final cameraPreview = Container(
      margin: const EdgeInsetsDirectional.symmetric(
        horizontal: 40,
      ),
      alignment: AlignmentDirectional.center,
      child: Semantics(
        label:
            'Your video preview, camera ${preferences.isCameraOn ? 'on' : 'off'}',
        image: true,
        child: LocalParticipantCard(
          isCameraOn: preferences.isCameraOn,
          audioTrack: mediaState.microphone.track,
          videoTrack: mediaState.camera.track,
        ),
      ),
    );
    final actionBar = PrejoinActionBar(
      locked: locked,
      previewAudioTrack: mediaState.microphone.track,
      onToggleMic: onToggleMicrophone,
      isSpeakerOn: preferences.isSpeakerOn,
      onToggleSpeaker: onToggleSpeaker,
      isCameraOn: preferences.isCameraOn,
      onToggleCamera: onToggleCamera,
      cameraPosition: preferences.cameraOptions.cameraPosition,
      selectedCameraDeviceId: preferences.cameraOptions.deviceId,
      onCameraPositionChanged: onCameraPositionChanged,
      onCameraDeviceSelected: onCameraDeviceSelected,
    );
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
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 18,
                        children: [joinCard, actionBar],
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

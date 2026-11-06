import 'package:flutter/widgets.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_preview_card.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_state.dart';
import 'package:totem_core/features/sessions/pre_join/pre_join_view.dart';
import 'package:totem_core/features/sessions/widgets/action_bar/action_bar.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';
import 'package:totem_widgetbook/viewports.dart';
import 'package:widgetbook/widgetbook.dart';

part 'session_entry.stories.g.dart';

const component = ComponentMeta(path: 'Screens/session/:slug');
const meta = Meta(PreJoinView.new, argsType: PreJoinStoryInput.new);

class PreJoinStoryInput {
  const PreJoinStoryInput({
    this.slug = 'session',
    this.waiting = false,
    this.cameraOn = false,
    this.microphoneOn = false,
  });

  final String slug;
  final bool waiting;
  final bool cameraOn;
  final bool microphoneOn;
}

final defaults = _Defaults(
  setup: (context, child, args) =>
      Story.defaultSetup(context, SizedBox.expand(child: child), args),
  builder: (context, args) {
    Future<void> toggleCamera() async =>
        args.cameraOnArg.update(context, !args.cameraOn);
    Future<void> toggleMicrophone() async =>
        args.microphoneOnArg.update(context, !args.microphoneOn);
    void leaveWaiting() => args.waitingArg.update(context, false);

    return PreJoinView(
      mediaState: PreJoinMediaState(
        preferences: PreJoinMediaPreferences(
          isCameraOn: args.cameraOn,
          isMicOn: args.microphoneOn,
        ),
      ),
      locked: false,
      previewKey: GlobalKey(),
      controlsKey: GlobalKey(),
      onLeave: leaveWaiting,
      onToggleCamera: toggleCamera,
      onToggleMicrophone: toggleMicrophone,
      onToggleSpeaker: () {},
      onCameraFacingChanged: (_) {},
      onCameraDeviceSelected: (_) {},
      preview: LocalParticipantCardView(
        name: 'Alex',
        isCameraOn: args.cameraOn,
        avatar: Image.asset(
          'assets/design/participant_card/preview.jpg',
          fit: BoxFit.cover,
        ),
      ),
      controls: PrejoinActionBarView(
        locked: false,
        microphoneLevel: null,
        microphoneNeedsAttention: false,
        cameraNeedsAttention: false,
        isMicOn: args.microphoneOn,
        onToggleMic: toggleMicrophone,
        isSpeakerOn: true,
        onToggleSpeaker: () {},
        isCameraOn: args.cameraOn,
        onToggleCamera: toggleCamera,
        cameraFacing: CameraFacing.front,
        availableCameraDevices: const [],
        selectedCameraDeviceId: null,
        onCameraFacingChanged: (_) {},
        onCameraDeviceSelected: (_) {},
      ),
      joinCard: JoinTransitionCard(
        margin: const EdgeInsetsDirectional.symmetric(horizontal: 10),
        keepActionLoadingOnSuccess: true,
        waiting: args.waiting,
        onLeaveWaiting: leaveWaiting,
        onActionPressed: () async {
          args.waitingArg.update(context, true);
          return true;
        },
      ),
    );
  },
);

List<PreJoinViewScenario> _scenarios() => [
  for (final viewport in [
    TotemViewports.phone,
    TotemViewports.phoneLandscape,
    TotemViewports.tablet,
    TotemViewports.desktop,
  ])
    _Scenario(name: viewport.name, modes: [ViewportMode(viewport)]),
];

/// The real pre-join screen, with local preview data and no device capture.
final $Default = _Story(
  modes: [ViewportMode(TotemViewports.phone)],
  scenarios: _scenarios(),
);

/// A participant is waiting for the Keeper's decision.
final $Waiting = _Story(
  args: _Args(waiting: BoolArg(true)),
  modes: [ViewportMode(TotemViewports.phone)],
  scenarios: _scenarios(),
);

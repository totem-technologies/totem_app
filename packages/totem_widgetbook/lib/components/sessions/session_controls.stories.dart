import 'package:flutter/widgets.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:widgetbook/widgetbook.dart';

part 'session_controls.stories.g.dart';

const component = ComponentMeta(path: 'Components/Sessions');

/// Custom args so every button writes back to its knob: the bar stays
/// live in every story instead of pinning no-op callbacks.
const meta = Meta(SessionControls.new, argsType: SessionControlsInput.new);

class SessionControlsInput {
  const SessionControlsInput({
    this.micOn = true,
    this.cameraOn = true,
    this.showSessionActions = true,
    this.reactionsOpen = false,
    this.moreExpanded = false,
    this.tone = SessionControlsTone.glass,
  });

  final bool micOn;
  final bool cameraOn;
  final bool showSessionActions;
  final bool reactionsOpen;
  final bool moreExpanded;
  final SessionControlsTone tone;
}

final defaults = _Defaults(
  // Built for dark video: slate behind glass, cream behind solid.
  setup: (context, child, args) => Container(
    margin: const EdgeInsets.all(Spacing.s24),
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    decoration: BoxDecoration(
      color: args.tone == SessionControlsTone.solid
          ? TotemColors.coreCream
          : TotemColors.coreSlate,
      borderRadius: BorderRadius.circular(Radii.lg),
    ),
    child: child,
  ),
  builder: (context, args) => SessionControls(
    micOn: args.micOn,
    cameraOn: args.cameraOn,
    showSessionActions: args.showSessionActions,
    reactionsOpen: args.reactionsOpen,
    moreExpanded: args.moreExpanded,
    tone: args.tone,
    onMic: () => args.micOnArg.update(context, !args.micOn),
    onCamera: () => args.cameraOnArg.update(context, !args.cameraOn),
    onReactions: () =>
        args.reactionsOpenArg.update(context, !args.reactionsOpen),
    onMore: () => args.moreExpandedArg.update(context, !args.moreExpanded),
  ),
);

/// Admitted, everything on.
final $InTheCircle = _Story(name: 'In the circle');

final $Muted = _Story(args: _Args(micOn: BoolArg(false)));

final $CameraOff = _Story(
  name: 'Camera off',
  args: _Args(cameraOn: BoolArg(false)),
);

final $ReactionsOpen = _Story(
  name: 'Reactions open',
  args: _Args(reactionsOpen: BoolArg(true)),
);

/// Waiting room and Keeper prep: no reactions or chat yet.
final $BeforeAdmission = _Story(
  name: 'Before admission',
  args: _Args(showSessionActions: BoolArg(false)),
);

/// The solid tone keeps the bar readable on cream screens.
final $OnCream = _Story(
  name: 'On cream',
  args: _Args(
    tone: EnumArg(
      SessionControlsTone.solid,
      values: SessionControlsTone.values,
    ),
    showSessionActions: BoolArg(false),
  ),
);

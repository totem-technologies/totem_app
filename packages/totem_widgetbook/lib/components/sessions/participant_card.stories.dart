import 'package:flutter/widgets.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:totem_widgetbook/figma.dart';
import 'package:widgetbook/widgetbook.dart';

part 'participant_card.stories.g.dart';

const meta = Meta(ParticipantCard.new);

const component = ComponentMeta(path: 'Components/Sessions');

const _assets = 'assets/design/participant_card';
const _photo = AssetImage('$_assets/participant-photo.jpg');
const _preview = AssetImage('$_assets/preview.jpg');

/// The card fills its slot, and type, radius, and inset scale with it.
/// Each story sets the slot it lives in.
SetupBuilder<ParticipantCard, ParticipantCardArgs> _slot(
  double width,
  double height,
) {
  return (context, child, args) => Padding(
    padding: const EdgeInsets.all(Spacing.s24),
    child: SizedBox(width: width, height: height, child: child),
  );
}

/// A gallery tile in the circle, Figma's 180 × 220 card.
final $InTheCircle = _Story(
  name: 'In the circle',
  setup: _slot(180, 220),
  args: _Args(name: StringArg('Liam'), photo: Arg.fixed(_photo)),
  scenarios: [
    _Scenario(name: 'Default'),
    _Scenario(
      name: 'Long name',
      args: _Args.fixed(name: 'Maximiliana Oyelaran-Thompson', photo: _photo),
    ),
  ],
);

/// No picture: the red → blue wash keeps the name readable.
final $CameraOff = _Story(
  name: 'Camera off',
  setup: _slot(180, 220),
  args: _Args(name: StringArg('Oliver')),
);

final $TalkingPiece = _Story(
  name: 'Holding the talking piece',
  setup: _slot(180, 220),
  args: _Args(
    name: StringArg('Liam'),
    photo: Arg.fixed(_photo),
    showTalkingPiece: BoolArg(true),
  ),
);

/// Your own camera before admission. No per-person menu.
final $WaitingRoom = _Story(
  name: 'Waiting room preview',
  setup: _slot(234, 281),
  args: _Args(
    name: StringArg('Alex'),
    photo: Arg.fixed(_preview),
    showTalkingPiece: BoolArg(true),
    showMore: BoolArg(false),
  ),
);

final $Speaker = _Story(
  designLink: figma('3800:10538'),
  setup: _slot(391, 461),
  args: _Args(
    name: StringArg('Mason'),
    photo: Arg.fixed(_photo),
    feature: BoolArg(true),
    showTalkingPiece: BoolArg(true),
  ),
);

/// A crowded phone gallery squeezes tiles short and wide.
final $SmallTile = _Story(
  name: 'Small tile',
  setup: _slot(120, 96),
  args: _Args(name: StringArg('Maya'), photo: Arg.fixed(_photo)),
);

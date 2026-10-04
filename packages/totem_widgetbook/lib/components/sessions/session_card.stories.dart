import 'package:flutter/widgets.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:totem_widgetbook/figma.dart';
import 'package:widgetbook/widgetbook.dart';

part 'session_card.stories.g.dart';

const meta = Meta(SessionCard.new);

const component = ComponentMeta(path: 'Components/Sessions');

const _assets = 'assets/design/session_card';
const _photo = AssetImage('$_assets/photo.jpg');
const _keeper = AssetImage('$_assets/keeper.png');

final defaults = _Defaults(
  // Figma frame width. Height follows the 362 / 253 ratio.
  setup: (context, child, args) => Padding(
    padding: const EdgeInsets.all(Spacing.s24),
    child: SizedBox(width: 362, child: child),
  ),
);

_Args _upcoming({
  ImageProvider? keeperPhoto = _keeper,
  VoidCallback? onSelect,
}) => _Args(
  photo: Arg.fixed(_photo),
  spaceName: StringArg('Thriving in Motherhood'),
  sessionName: StringArg('The Weight of Expectations'),
  keeperName: StringArg('Maria'),
  keeperPhoto: Arg.fixed(keeperPhoto),
  time: StringArg('4:00'),
  meridiem: StringArg('PM'),
  seatsLeft: IntArg(4),
  onSelect: Arg.fixed(onSelect),
);

final $Upcoming = _Story(
  designLink: figma('3734:10290'),
  args: _upcoming(),
  scenarios: [
    _Scenario(name: 'Default'),
    _Scenario(
      name: 'Long title, last seat',
      args: _Args.fixed(
        photo: _photo,
        spaceName: 'Shame & Self-Worth and Everything That Comes With It',
        sessionName: 'What We Carry When Nobody Is Looking Anymore',
        keeperName: 'Maximiliana Oyelaran-Thompson',
        keeperPhoto: _keeper,
        time: '6:30',
        meridiem: 'PM',
        seatsLeft: 1,
      ),
    ),
  ],
);

/// The whole card is one control in a list.
final $Tappable = _Story(args: _upcoming(onSelect: () {}));

/// The Keeper's initial stands in for a missing photo.
final $NoKeeperPhoto = _Story(
  name: 'No Keeper photo',
  args: _upcoming(keeperPhoto: null),
);

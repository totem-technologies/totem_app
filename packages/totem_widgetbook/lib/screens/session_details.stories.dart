import 'package:flutter/widgets.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:totem_widgetbook/figma.dart';
import 'package:totem_widgetbook/viewports.dart';
import 'package:widgetbook/widgetbook.dart';

part 'session_details.stories.g.dart';

/// `RouteNames.spaceEvent(':slug')`. A separate design from SessionEntry
/// under `Screens/session/:slug`.
const component = ComponentMeta(path: 'Screens/spaces/event/:slug');

/// Custom args: the Session itself is catalog data, so the knobs are its
/// state and the facts that change the layout. Attend, leave and the
/// ended dialog write back to `status`.
const meta = Meta(SessionDetailsPage.new, argsType: SessionDetailsInput.new);

class SessionDetailsInput {
  const SessionDetailsInput({
    this.status = SessionDetailsStatus.open,
    this.seatsLeft = 9,
    this.recurring = true,
    this.free = true,
    this.showSimilar = true,
  });

  final SessionDetailsStatus status;
  final int seatsLeft;

  /// Shows "Twice a month" in the facts.
  final bool recurring;

  /// "No Cost" when true, otherwise the price.
  final bool free;

  final bool showSimilar;
}

final defaults = _Defaults(
  setup: (context, child, args) => SizedBox.expand(child: child),
  builder: (context, args) => SessionDetailsPage(
    status: args.status,
    seatsLeft: args.seatsLeft,
    recurring: args.recurring,
    free: args.free,
    showSimilar: args.showSimilar,
    onBack: () {},
    onShare: () {},
    onAttend: () =>
        args.statusArg.update(context, SessionDetailsStatus.attending),
    onLeave: () => args.statusArg.update(context, SessionDetailsStatus.open),
    onSignUpNext: () =>
        args.statusArg.update(context, SessionDetailsStatus.open),
    onReturnHome: () {},
    onViewKeeper: () {},
  ),
);

_Story _state(
  String name, {
  SessionDetailsStatus status = SessionDetailsStatus.open,
  int seatsLeft = 9,
  String node = '2379:2498',
}) {
  return _Story(
    name: name,
    designLink: figma(node),
    args: _Args(
      status: EnumArg(status, values: SessionDetailsStatus.values),
      seatsLeft: IntArg(seatsLeft),
      recurring: BoolArg(true),
      free: BoolArg(true),
      showSimilar: BoolArg(true),
    ),
    modes: [ViewportMode(TotemViewports.phone)],
  );
}

final $Open = _state('Open');

/// Not in Figma. Attend turns into an outlined "Attending".
final $Attending = _state(
  'Attending',
  status: SessionDetailsStatus.attending,
  seatsLeft: 8,
);

/// Not in Figma. No seats, so Attend is disabled.
final $Full = _state('Full', status: SessionDetailsStatus.full);

final $Ended = _state(
  'Ended',
  status: SessionDetailsStatus.ended,
  node: '3200:8158',
);

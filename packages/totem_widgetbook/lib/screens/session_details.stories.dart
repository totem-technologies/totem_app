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

const _similar = SimilarSession(
  spaceName: 'What is Love?',
  sessionName: 'The Fear of Being Loved',
  keeperName: 'Heather',
  dateLabel: '5 Feb',
  time: '8:30',
  period: 'PM',
  seatsLeft: 2,
);

final defaults = _Defaults(
  setup: (context, child, args) => SizedBox.expand(child: child),
  builder: (context, args) => SessionDetailsPage(
    spaceName:
        'Transition: Panic. Pause. Pivot. Repeat — a Space for the moments '
        'everything shifts at once',
    sessionName: 'Learning to Witness Yourself When the Ground Moves Under You',
    keeperName: 'Vanessa',
    keeperBio:
        'Vanessa is a Los Angeles-based artist and recovering hot mess. '
        "She's battled many challenges, from undiagnosed depression to "
        'struggling with alcohol abuse, and knows first hand how hard it is '
        'to face complex emotions alone.',
    dateLabel: 'Wednesday, February 11th',
    timeLabel: '12:30 AM GMT+1',
    description:
        'Change rarely arrives one piece at a time. A move, a loss, a new '
        'role, a body that feels different — they tend to land together, '
        'and the mind starts narrating before we have had a chance to feel '
        'anything.\n\n'
        'In this Session we practice noticing that narration. We will share '
        'one moment from the past month when things shifted, and listen '
        'without fixing, advising or comparing.\n\n'
        'You can keep your camera off and pass whenever you like. Come as '
        'you are; there is nothing to prepare.',
    status: args.status,
    seatsLeft: args.seatsLeft,
    recurring: args.recurring,
    free: args.free,
    similar: args.showSimilar ? _similar : null,
    onBack: () {},
    onShare: () {},
    onAttend: () =>
        args.statusArg.update(context, SessionDetailsStatus.attending),
    onLeave: () => args.statusArg.update(context, SessionDetailsStatus.open),
    onSignUpNext: () =>
        args.statusArg.update(context, SessionDetailsStatus.open),
    onReturnHome: () {},
    onViewKeeper: () {},
    onAttendSimilar: () {},
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

/// Not in Figma. No seats, so Attend is disabled. An open Session with
/// the seats knob at 0 looks the same.
final $Full = _state('Full', status: SessionDetailsStatus.full);

final $Ended = _state(
  'Ended',
  status: SessionDetailsStatus.ended,
  node: '3200:8158',
);

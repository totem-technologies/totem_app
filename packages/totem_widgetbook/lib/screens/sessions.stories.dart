import 'package:flutter/widgets.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:totem_widgetbook/figma.dart';
import 'package:totem_widgetbook/viewports.dart';
import 'package:widgetbook/widgetbook.dart';

part 'sessions.stories.g.dart';

/// The Sessions tab is `RouteNames.spaces`.
const component = ComponentMeta(path: 'Screens/spaces');

/// Custom args: the list is catalog data, so the knobs are what the member
/// controls on the page — the quick filter and "My Sessions".
const meta = Meta(SessionsScreen.new, argsType: SessionsInput.new);

class SessionsInput {
  const SessionsInput({
    this.filter = SessionsFilter.all,
    this.mySessions = false,
  });

  final SessionsFilter filter;

  /// Only the Sessions the member is attending.
  final bool mySessions;
}

final defaults = _Defaults(
  setup: (context, child, args) => SizedBox.expand(child: child),
  builder: (context, args) => SessionsScreen(
    filter: args.filter,
    mySessions: args.mySessions,
    onFilter: (filter) => args.filterArg.update(context, filter),
    onMySessions: () => args.mySessionsArg.update(context, !args.mySessions),
    onShowAll: () {
      args.filterArg.update(context, SessionsFilter.all);
      args.mySessionsArg.update(context, false);
    },
    onAddToCalendar: (_) {},
  ),
);

_Story _state(
  String name, {
  SessionsFilter filter = SessionsFilter.all,
  bool mySessions = false,
}) {
  return _Story(
    name: name,
    designLink: figma('2315:8056'),
    args: _Args(
      filter: EnumArg(filter, values: SessionsFilter.values),
      mySessions: BoolArg(mySessions),
    ),
    modes: [ViewportMode(TotemViewports.phone)],
  );
}

/// The Figma frame: every upcoming Session, grouped by day.
final $Default = _state('All sessions');

final $Filtered = _state('Filtered, Mothers', filter: SessionsFilter.mothers);

final $MySessions = _state('My sessions', mySessions: true);

/// Not in Figma. A filter and "My Sessions" that leave nothing.
final $Empty = _state('Empty', filter: SessionsFilter.lgbtq, mySessions: true);

import 'package:flutter/widgets.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:totem_widgetbook/figma.dart';
import 'package:totem_widgetbook/viewports.dart';
import 'package:widgetbook/widgetbook.dart';

part 'home.stories.g.dart';

/// `RouteNames.home`.
const component = ComponentMeta(path: 'Screens/home');

/// Custom args: the page content is catalog data, so the knobs are who
/// is looking and how much there is to show.
const meta = Meta(HomeScreen.new, argsType: HomeInput.new);

class HomeInput {
  const new({
    this.user = HomeUser.returning,
    this.live = false,
    this.upcomingCount = 5,
    this.showBlog = true,
  });

  final HomeUser user;

  /// The next Session has started. Returning members only.
  final bool live;

  /// Rows under "Upcoming Sessions", 0 to 5.
  final int upcomingCount;

  final bool showBlog;
}

final defaults = _Defaults(
  setup: (context, child, args) => SizedBox.expand(child: child),
  builder: (context, args) => HomeScreen(
    user: args.user,
    live: args.live,
    upcomingCount: args.upcomingCount,
    showBlog: args.showBlog,
    onJoin: () {},
    onAttend: (_) {},
    onReadMission: () {},
    onReadBlog: () {},
  ),
);

_Story _state(
  String name, {
  required String node,
  HomeUser user = HomeUser.returning,
  bool live = false,
  int upcomingCount = 5,
  bool showBlog = true,
}) {
  return _Story(
    name: name,
    designLink: figma(node),
    args: _Args(
      user: EnumArg(user, values: HomeUser.values),
      live: BoolArg(live),
      upcomingCount: IntArg(upcomingCount),
      showBlog: BoolArg(showBlog),
    ),
    modes: [ViewportMode(TotemViewports.phone)],
  );
}

final $NewUser = _state('New user', node: '2316:7123', user: HomeUser.newUser);

final $Returning = _state('Returning', node: '2316:7032');

final $ReturningLive = _state(
  'Returning, session live',
  node: '2403:2424',
  live: true,
);

/// Not in Figma. Nothing open to sign up for.
final $NoUpcoming = _state(
  'Returning, no upcoming',
  node: '2316:7032',
  upcomingCount: 0,
);

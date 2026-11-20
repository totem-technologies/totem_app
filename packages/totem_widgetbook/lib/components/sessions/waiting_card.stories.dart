import 'package:flutter/widgets.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';
import 'package:widgetbook/widgetbook.dart';

part 'waiting_card.stories.g.dart';

const meta = Meta(JoinTransitionCard.new, argsType: JoinCardInput.new);
const component = ComponentMeta(path: 'Components/Sessions');

class JoinCardInput {
  const JoinCardInput({this.waiting = false, this.keeperUnresponsive = false});

  final bool waiting;

  /// The Keeper hasn't confirmed the request, so waiting shows a warning.
  final bool keeperUnresponsive;
}

final defaults = _Defaults(
  setup: (context, child, args) =>
      Padding(padding: const EdgeInsets.all(24), child: child),
  builder: (context, args) => JoinTransitionCard(
    onActionPressed: () async => true,
    waiting: args.waiting,
    waitingMessage: args.keeperUnresponsive
        ? "The Keeper hasn't confirmed your request. Ask them to reconnect or update Totem, or leave and try again."
        : null,
    onLeaveWaiting: () {},
  ),
);

final $Default = _Story();
final $Waiting = _Story(args: _Args(waiting: BoolArg(true)));
final $KeeperUnresponsive = _Story(
  args: _Args(waiting: BoolArg(true), keeperUnresponsive: BoolArg(true)),
);

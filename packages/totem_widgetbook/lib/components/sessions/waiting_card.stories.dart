import 'package:flutter/widgets.dart';
import 'package:totem_core/features/sessions/widgets/transition_card.dart';
import 'package:widgetbook/widgetbook.dart';

part 'waiting_card.stories.g.dart';

const meta = Meta(JoinTransitionCard.new, argsType: JoinCardInput.new);
const component = ComponentMeta(path: 'Components/Sessions');

class JoinCardInput {
  const JoinCardInput({this.waiting = false});

  final bool waiting;
}

final defaults = _Defaults(
  setup: (context, child, args) =>
      Padding(padding: const EdgeInsets.all(24), child: child),
  builder: (context, args) => JoinTransitionCard(
    onActionPressed: () async => true,
    waiting: args.waiting,
    onLeaveWaiting: () {},
  ),
);

final $Default = _Story();
final $Waiting = _Story(args: _Args(waiting: BoolArg(true)));

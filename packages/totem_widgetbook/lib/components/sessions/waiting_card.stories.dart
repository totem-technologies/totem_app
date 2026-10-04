import 'package:flutter/widgets.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:totem_widgetbook/figma.dart';
import 'package:widgetbook/widgetbook.dart';

part 'waiting_card.stories.g.dart';

const meta = Meta(WaitingCard.new);

const component = ComponentMeta(path: 'Components/Sessions');

final defaults = _Defaults(
  setup: (context, child, args) =>
      Padding(padding: const EdgeInsets.all(Spacing.s24), child: child),
);

/// Late arrival: the Keeper decides before the request expires.
final $Reviewing = _Story(
  designLink: figma('3796:9181'),
  args: _Args(
    title: StringArg('Keeper is reviewing your request to join'),
    body: Arg.fixed(
      const Text.rich(
        TextSpan(
          text: 'Please wait,\nwe will let you know in ',
          children: [
            TextSpan(
              text: '1:47',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: ' min'),
          ],
        ),
      ),
    ),
    action: Arg.fixed(
      Button(
        onPressed: () {},
        variant: ButtonVariant.secondary,
        block: true,
        child: const Text('Cancel request and leave'),
      ),
    ),
  ),
);

/// Admitted before start. Nothing to do but wait, so no action.
final $Admitted = _Story(
  args: _Args(
    title: StringArg("You're in."),
    body: Arg.fixed(
      const Text(
        'Letting Shame Fall Away begins at 6:30 PM GMT. Settle in. '
        'The circle opens then.',
      ),
    ),
  ),
);

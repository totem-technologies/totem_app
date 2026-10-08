import 'package:flutter/widgets.dart';
import 'package:totem_widgetbook/design/design.dart';
import 'package:totem_widgetbook/figma.dart';
import 'package:widgetbook/widgetbook.dart';

part 'button.stories.g.dart';

const meta = Meta(Button.new);

const component = ComponentMeta(path: 'Components/Buttons');

void _noop() {}

final defaults = _Defaults(
  // Catalog frame only. The button itself hugs a 140 min and grows
  // when `block` — same control on phone and desktop.
  setup: (context, child, args) => Padding(
    padding: const EdgeInsets.all(Spacing.s24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 362),
      child: child,
    ),
  ),
);

final $Primary = _Story(
  designLink: figma('3734:10292'),
  args: _Args(
    child: Arg.fixed(const Text('Join the Next session')),
    onPressed: Arg.fixed(_noop),
    block: BoolArg(true),
  ),
  scenarios: [
    _Scenario(name: 'Default'),
    _Scenario(
      name: 'Long label',
      args: _Args.fixed(
        child: const Text('Join the Session That Opens in a Few Minutes'),
        onPressed: _noop,
        block: true,
      ),
    ),
  ],
);

final $Secondary = _Story(
  args: _Args(
    child: Arg.fixed(const Text('Cancel request and leave')),
    onPressed: Arg.fixed(_noop),
    variant: EnumArg(ButtonVariant.secondary, values: ButtonVariant.values),
    block: BoolArg(true),
  ),
);

final $Text = _Story(
  args: _Args(
    child: Arg.fixed(const Text('Return to the Space')),
    onPressed: Arg.fixed(_noop),
    variant: EnumArg(ButtonVariant.text, values: ButtonVariant.values),
  ),
);

/// No `onPressed`: the join window hasn't opened yet.
final $Disabled = _Story(
  args: _Args(
    child: Arg.fixed(const Text('Join session')),
    block: BoolArg(true),
  ),
);

/// The dense size used in request rows and cards.
final $Compact = _Story(
  args: _Args(
    child: Arg.fixed(const Text('Admit')),
    onPressed: Arg.fixed(_noop),
    size: EnumArg(ButtonSize.compact, values: ButtonSize.values),
  ),
);

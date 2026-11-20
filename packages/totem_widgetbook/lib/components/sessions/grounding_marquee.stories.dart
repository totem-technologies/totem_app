import 'package:flutter/widgets.dart';
import 'package:totem_core/features/sessions/widgets/grounding_marquee.dart';
import 'package:widgetbook/widgetbook.dart';

part 'grounding_marquee.stories.g.dart';

const meta = Meta(GroundingMarquee.new, argsType: GroundingMarqueeInput.new);
const component = ComponentMeta(path: 'Components/Sessions');

class GroundingMarqueeInput {
  const GroundingMarqueeInput({this.initialIndex = 0});

  /// The first tip shown. Fixed so the rendered catalog is deterministic.
  final int initialIndex;
}

final defaults = _Defaults(
  setup: (context, child, args) =>
      Padding(padding: const EdgeInsets.all(24), child: child),
  builder: (context, args) => GroundingMarquee(
    // A new key restarts the rotation when the first tip changes.
    key: ValueKey(args.initialIndex),
    initialIndex: args.initialIndex,
  ),
);

final $Default = _Story();

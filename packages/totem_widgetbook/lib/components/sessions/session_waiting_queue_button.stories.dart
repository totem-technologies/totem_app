import 'package:flutter/widgets.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_queue_button.dart';
import 'package:widgetbook/widgetbook.dart';

part 'session_waiting_queue_button.stories.g.dart';

const meta = Meta(SessionWaitingQueueButton.new);
const component = ComponentMeta(path: 'Components/Sessions');

final defaults = _Defaults(
  setup: (context, child, args) =>
      Padding(padding: const EdgeInsets.all(24), child: child),
);

final $Default = _Story(
  args: _Args(count: IntArg(3), onPressed: Arg.fixed(() {})),
);

final $OneWaiting = _Story(args: _Args(count: IntArg(1)));
final $Empty = _Story(args: _Args(count: IntArg(0)));

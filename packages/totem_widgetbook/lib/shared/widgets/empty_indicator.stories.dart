import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/empty_indicator.dart';
import 'package:totem_widgetbook/utils/args.dart';
import 'package:widgetbook/widgetbook.dart';

part 'empty_indicator.stories.g.dart';

const meta = Meta(EmptyIndicator.new);

final $Default = _Story(
  args: _Args(
    text: NullableStringArg('Nothing available yet'),
    icon: iconArg(),
  ),
);

final $WithRetry = _Story(
  args: _Args(
    text: NullableStringArg('Could not load sessions'),
    icon: iconArg(TotemIcons.wifiOff),
    onRetry: ConstArg(noop),
  ),
);

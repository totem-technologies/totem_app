import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/circle_icon_button.dart';
import 'package:totem_widgetbook/utils/args.dart';
import 'package:widgetbook/widgetbook.dart';

part 'circle_icon_button.stories.g.dart';

const meta = Meta(CircleIconButton.new);

final $Default = _Story(
  args: _Args(
    icon: iconArg(TotemIcons.share),
    onPressed: ConstArg(noop),
    tooltip: NullableStringArg('Share'),
  ),
);

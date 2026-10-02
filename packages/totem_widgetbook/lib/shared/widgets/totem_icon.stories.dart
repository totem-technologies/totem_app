import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_widgetbook/utils/args.dart';
import 'package:widgetbook/widgetbook.dart';

part 'totem_icon.stories.g.dart';

const meta = Meta(TotemIcon.new);

final $Default = _Story(
  args: _Args(icon: iconArg(), size: NullableDoubleArg(24)),
);

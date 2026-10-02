import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';
import 'package:widgetbook/widgetbook.dart';

part 'loading_indicator.stories.g.dart';

const meta = Meta(LoadingIndicator.new);

final $Default = _Story(
  args: _Args(
    size: DoubleArg(
      36,
      style: const SliderDoubleArgStyle(min: 12, max: 120, divisions: 36),
    ),
  ),
);

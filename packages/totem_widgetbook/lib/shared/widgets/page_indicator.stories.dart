import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/page_indicator.dart';
import 'package:widgetbook/widgetbook.dart';

part 'page_indicator.stories.g.dart';

const meta = Meta(PageIndicator.new);

final $Default = _Story(
  args: _Args(length: NullableIntArg(3), currentIndex: NullableIntArg(0)),
);

final $Last = _Story(
  args: _Args(length: NullableIntArg(3), currentIndex: NullableIntArg(2)),
);

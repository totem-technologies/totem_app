import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/info_text.dart';
import 'package:widgetbook/widgetbook.dart';

part 'info_text.stories.g.dart';

const meta = Meta(InfoText.new);

const component = ComponentMeta(path: 'Components/Feedback');

final $Default = _Story(
  args: _Args(
    text: StringArg(
      'Sessions are confidential. Please do not record or share them.',
    ),
  ),
);

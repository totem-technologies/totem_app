import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';
import 'package:widgetbook/widgetbook.dart';

part 'error_dialog.stories.g.dart';

const meta = Meta(ErrorDialog.new);

final $Default = _Story(
  args: _Args(
    message: NullableStringArg('Check your connection and try again.'),
  ),
);

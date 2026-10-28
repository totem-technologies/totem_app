import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/update_available_dialog.dart';
import 'package:totem_widgetbook/utils/args.dart';
import 'package:widgetbook/widgetbook.dart';

part 'update_available_dialog.stories.g.dart';

const meta = Meta(UpdateAvailableDialog.new);

const component = ComponentMeta(path: 'Components/Dialogs');

final $Default = _Story(
  args: _Args(
    title: StringArg('Update available'),
    message: StringArg(
      'A newer version of Totem is available. Update to get the latest '
      'fixes and improvements.',
    ),
    prompt: NullableStringArg('Would you like to update now?'),
    updateButtonText: StringArg('Update'),
    onUpdate: ConstArg(noop),
    laterButtonText: NullableStringArg('Later'),
    onLater: ConstArg(noop),
    ignoreButtonText: NullableStringArg('Ignore'),
    onIgnore: ConstArg(noop),
  ),
);

final $WithoutDismiss = _Story(
  args: _Args(
    title: StringArg('Update available'),
    message: StringArg(
      'This version of Totem is no longer supported. Please update to continue.',
    ),
    updateButtonText: StringArg('Update'),
    onUpdate: ConstArg(noop),
    // Force-update / blocked: no Later or Ignore.
    laterButtonText: NullableStringArg(null),
    onLater: ConstArg(null),
    ignoreButtonText: NullableStringArg(null),
    onIgnore: ConstArg(null),
  ),
);

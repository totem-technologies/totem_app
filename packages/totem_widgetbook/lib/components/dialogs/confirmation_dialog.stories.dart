import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_widgetbook/utils/args.dart';
import 'package:widgetbook/widgetbook.dart';

part 'confirmation_dialog.stories.g.dart';

const meta = Meta(ConfirmationDialog.new);

const component = ComponentMeta(path: 'Components/Dialogs');

final $Destructive = _Story(
  args: _Args(
    content: NullableStringArg(
      'You will leave the session and lose your spot.',
    ),
    confirmButtonText: StringArg('Leave'),
    icon: nullableIconArg(TotemIcons.leaveCall),
    onConfirm: ConstArg(asyncNoop),
  ),
);

final $Standard = _Story(
  args: _Args(
    type: EnumArg(
      ConfirmationDialogType.standard,
      values: ConfirmationDialogType.values,
    ),
    title: StringArg('Pass the totem?'),
    content: NullableStringArg('The next participant will be able to speak.'),
    confirmButtonText: StringArg('Pass'),
    onConfirm: ConstArg(asyncNoop),
  ),
);

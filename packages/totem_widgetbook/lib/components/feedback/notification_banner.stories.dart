import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';
import 'package:totem_widgetbook/utils/args.dart';
import 'package:widgetbook/widgetbook.dart';

part 'notification_banner.stories.g.dart';

const meta = Meta(NotificationBanner.new);

const component = ComponentMeta(path: 'Components/Feedback');

final $Default = _Story(
  args: _Args(
    icon: iconArg(TotemIcons.microphoneOff),
    title: StringArg('Your microphone is off'),
    message: StringArg('Tap to turn it on when you are ready to speak.'),
  ),
);

/// A failed in-session action, shown with the error icon color.
final $Error = _Story(
  args: _Args(
    icon: iconArg(TotemIcons.errorOutlined),
    title: StringArg("Couldn't pass the totem"),
    message: StringArg(
      "It's still your turn. Check your connection and try again.",
    ),
    iconBackgroundColor: NullableColorArg(const Color(0xFFF44336)),
  ),
);

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';
import 'package:totem_widgetbook/utils/args.dart';
import 'package:widgetbook/widgetbook.dart';

part 'error_screen.stories.g.dart';

const meta = Meta(ErrorScreen.new);

const component = ComponentMeta(path: 'Components/Feedback');

final $WithRetry = _Story(
  args: _Args(
    title: NullableStringArg('Something went wrong'),
    error: NullableStringArg('Failed to load the session.'),
    onRetry: ConstArg(asyncNoop),
  ),
);

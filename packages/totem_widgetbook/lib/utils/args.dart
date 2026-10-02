import 'package:totem_core/shared/totem_icons.dart';
import 'package:widgetbook/widgetbook.dart';

/// A representative subset of [TotemIcons], since icons are raw SVG strings
/// that would otherwise show up as a text field.
const _icons = <String, TotemIconData>{
  'lock': TotemIcons.lock,
  'home': TotemIcons.home,
  'calendar': TotemIcons.calendar,
  'chat': TotemIcons.chat,
  'microphoneOn': TotemIcons.microphoneOn,
  'microphoneOff': TotemIcons.microphoneOff,
  'cameraOn': TotemIcons.cameraOn,
  'leaveCall': TotemIcons.leaveCall,
  'share': TotemIcons.share,
  'delete': TotemIcons.delete,
  'errorOutlined': TotemIcons.errorOutlined,
  'wifiOff': TotemIcons.wifiOff,
};

String _iconName(TotemIconData icon) =>
    _icons.entries.firstWhere((e) => e.value == icon).key;

SingleArg<TotemIconData> iconArg([TotemIconData initial = TotemIcons.lock]) {
  return SingleArg(
    initial,
    values: _icons.values.toList(),
    labelBuilder: _iconName,
  );
}

NullableSingleArg<TotemIconData> nullableIconArg([TotemIconData? initial]) {
  return NullableSingleArg(
    initial,
    values: _icons.values.toList(),
    labelBuilder: _iconName,
  );
}

void noop() {}

Future<void> asyncNoop() async {}

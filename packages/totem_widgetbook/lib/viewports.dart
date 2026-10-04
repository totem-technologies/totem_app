import 'package:flutter/foundation.dart';
import 'package:widgetbook/widgetbook.dart';

/// Frames from the Figma board.
///
/// Heights match the screen frames, so a screen fills its viewport:
/// 812 on the phone, 760 once it reads as a window.
abstract final class TotemViewports {
  static const phone = ViewportData(
    name: 'Phone',
    width: 360,
    height: 812,
    pixelRatio: 2,
    platform: TargetPlatform.iOS,
  );

  static const tablet = ViewportData(
    name: 'Tablet',
    width: 768,
    height: 760,
    pixelRatio: 2,
    platform: TargetPlatform.iOS,
  );

  static const desktop = ViewportData(
    name: 'Desktop',
    width: 1280,
    height: 760,
    pixelRatio: 1,
    platform: TargetPlatform.macOS,
  );
}

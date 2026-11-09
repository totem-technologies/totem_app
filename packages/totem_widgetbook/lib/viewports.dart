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

  /// Phone rotated: same 360 × 812 frame, now 812 × 360.
  ///
  /// Session video crop is a landscape-phone problem. Portrait rules
  /// (4:5 tiles, full-bleed speaker) do not rotate cleanly.
  static const phoneLandscape = ViewportData(
    name: 'Phone Landscape',
    width: 812,
    height: 360,
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

  static const tabletLandscape = ViewportData(
    name: 'Tablet Landscape',
    width: 1024,
    height: 768,
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

  /// Browser windows from the TOT-1439 review, where the post-session card
  /// was cut off: a short desktop, a short narrow window and a very short
  /// landscape window.
  static const shortDesktop = ViewportData(
    name: 'Short Desktop (1702×650)',
    width: 1702,
    height: 650,
    pixelRatio: 1,
    platform: TargetPlatform.macOS,
  );

  static const shortTablet = ViewportData(
    name: 'Short Window (812×650)',
    width: 812,
    height: 650,
    pixelRatio: 1,
    platform: TargetPlatform.macOS,
  );

  static const shortLandscape = ViewportData(
    name: 'Short Landscape (906×339)',
    width: 906,
    height: 339,
    pixelRatio: 1,
    platform: TargetPlatform.macOS,
  );
}

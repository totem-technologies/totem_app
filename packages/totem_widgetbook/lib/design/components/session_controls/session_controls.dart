import 'dart:ui' show ImageFilter;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../pressable.dart';
import '../../tokens/tokens.dart';

const _icons = 'assets/design/session_controls';

/// `glass` is the Figma surface: white 8% over dark video.
/// `solid` swaps in slate so the bar still reads on cream screens.
enum SessionControlsTone { glass, solid }

/// Session Controls / Compact bar.
///
/// One pill, round buttons, the same order every time:
/// mic, camera, reactions, chat, more.
///
/// A filled button means "something is different from normal":
///   - Mic muted or camera off  → berry fill, rose glyph
///   - Reactions open           → cream fill, slate glyph
/// Everything else is a bare cream glyph on the glass.
///
/// Every measurement is a ratio of the Figma frame, where a button is 78px.
/// Change [buttonSize] and the whole bar scales with it: padding, gap,
/// border, radius, and glyphs.
class SessionControls extends StatelessWidget {
  const SessionControls({
    super.key,
    required this.micOn,
    required this.cameraOn,
    required this.onMic,
    required this.onCamera,
    this.showSessionActions = true,
    this.reactionsOpen = false,
    this.onReactions,
    this.onChat,
    this.moreLabel = 'More',
    this.moreExpanded = false,
    this.onMore,
    this.tone = SessionControlsTone.glass,
    this.buttonSize = 48,
  });

  /// Live mic state. `false` shows the muted, filled button.
  final bool micOn;

  /// Live camera state. `false` shows the filled camera-off button.
  final bool cameraOn;
  final VoidCallback onMic;
  final VoidCallback onCamera;

  /// Reactions and chat only make sense inside the circle.
  /// Leave this off for the waiting room or Keeper prep.
  final bool showSessionActions;
  final bool reactionsOpen;
  final VoidCallback? onReactions;
  final VoidCallback? onChat;

  /// Accessible name for the overflow button.
  final String moreLabel;
  final bool moreExpanded;
  final VoidCallback? onMore;

  final SessionControlsTone tone;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    final k = buttonSize / 78;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;

    final background = switch (tone) {
      SessionControlsTone.glass => TotemColors.overlayWhite08,
      SessionControlsTone.solid => TotemColors.overlaySlate70,
    };

    Widget button({
      required String label,
      required Widget Function(Color color) glyph,
      required VoidCallback? onTap,
      _Fill fill = _Fill.none,
      bool? toggled,
      bool? expanded,
    }) {
      return _ControlButton(
        size: buttonSize,
        k: k,
        fill: fill,
        label: label,
        toggled: toggled,
        expanded: expanded,
        onTap: onTap ?? () {},
        glyph: glyph,
      );
    }

    return Semantics(
      container: true,
      label: 'Session controls',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.full),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.all(13 * k),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(Radii.full),
              border: Border.all(
                width: 1.625 * k,
                color: highContrast
                    ? TotemColors.coreCream
                    : TotemColors.overlayWhite16,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 10 * k,
              children: [
                // Mic. Bare while live; berry with a slash while muted.
                button(
                  label: micOn ? 'Mute microphone' : 'Unmute microphone',
                  toggled: micOn,
                  fill: micOn ? _Fill.none : _Fill.alert,
                  onTap: onMic,
                  glyph: (color) => Stack(
                    children: [
                      _glyph('microphone', 37.1719 * k, 39 * k, color),
                      if (!micOn)
                        Positioned.fill(
                          child: CustomPaint(painter: _MuteSlash(color)),
                        ),
                    ],
                  ),
                ),
                // Camera. Same rule as the mic.
                button(
                  label: cameraOn ? 'Turn camera off' : 'Turn camera on',
                  toggled: cameraOn,
                  fill: cameraOn ? _Fill.none : _Fill.alert,
                  onTap: onCamera,
                  glyph: (color) => _glyph(
                    cameraOn ? 'camera-on' : 'camera-off',
                    41.8771 * k,
                    36.9616 * k,
                    color,
                  ),
                ),
                // In-circle actions. Hidden before admission.
                if (showSessionActions) ...[
                  button(
                    label: 'Reactions',
                    toggled: reactionsOpen,
                    fill: reactionsOpen ? _Fill.selected : _Fill.none,
                    onTap: onReactions,
                    glyph: (color) =>
                        _glyph('reactions', 39 * k, 39 * k, color),
                  ),
                  button(
                    label: 'Chat',
                    onTap: onChat,
                    glyph: (color) => _glyph('chat', 39 * k, 39 * k, color),
                  ),
                ],
                // Overflow. The parent owns whatever it opens.
                button(
                  label: moreLabel,
                  expanded: moreExpanded,
                  onTap: onMore,
                  glyph: (color) => _glyph('more', 39 * k, 39 * k, color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The SVG is a mask; [color] is the paint. Boxes match each asset's own
  /// root size.
  static Widget _glyph(String name, double width, double height, Color color) {
    return SvgPicture.asset(
      '$_icons/$name.svg',
      width: width,
      height: height,
      fit: BoxFit.fill,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

enum _Fill { none, alert, selected }

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.size,
    required this.k,
    required this.fill,
    required this.label,
    required this.onTap,
    required this.glyph,
    this.toggled,
    this.expanded,
  });

  final double size;
  final double k;
  final _Fill fill;
  final String label;
  final VoidCallback onTap;
  final Widget Function(Color color) glyph;
  final bool? toggled;
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final (Color? background, Color foreground) = switch (fill) {
      // Muted mic, camera off.
      _Fill.alert => (TotemColors.extendedBerry, TotemColors.extendedRose),
      // Reactions tray open.
      _Fill.selected => (TotemColors.coreCream, TotemColors.coreSlate),
      _Fill.none => (null, TotemColors.coreCream),
    };
    final radius = fill == _Fill.none ? 19.5 * k : size / 2;

    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      focusColor: TotemColors.coreCream,
      focusRadius: BorderRadius.circular(radius),
      semanticLabel: label,
      toggled: toggled,
      expanded: expanded,
      builder: (context, states) {
        final hovered = states.contains(WidgetState.hovered);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: const Cubic(0.22, 1, 0.36, 1),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                background ??
                (hovered
                    ? TotemColors.overlayWhite08
                    : const Color(0x00FFFFFF)),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: glyph(foreground),
        );
      },
    );
  }
}

/// The slash across a muted mic, drawn at the same angle and weight as
/// camera-off. Figma's line lives in the camera's 41.88 × 36.96 box and is
/// stretched to fill the mic box.
class _MuteSlash extends CustomPainter {
  const _MuteSlash(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 41.8771;
    final sy = size.height / 36.9616;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.41148 * (sx + sy) / 2;
    canvas.drawLine(
      Offset(4.50738 * sx, 34.7558 * sy),
      Offset(37.0575 * sx, 2.20574 * sy),
      paint,
    );
  }

  @override
  bool shouldRepaint(_MuteSlash oldDelegate) => oldDelegate.color != color;
}

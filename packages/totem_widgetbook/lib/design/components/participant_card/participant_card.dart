import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../paint.dart';
import '../../pressable.dart';
import '../../tokens/tokens.dart';

const _assets = 'assets/design/participant_card';

/// Figma 142° red → blue, used any time the camera still is missing.
const participantFallback = CssLinearGradient(
  angle: 142.26,
  colors: [Color(0xFFF71A1A), Color(0xFF1C42EB)],
  stops: [0.0896, 0.9707],
);

/// One tile for the circle and the waiting-room preview. Video (or a still)
/// fills the card edge to edge. No picture? The Figma wash sits
/// underneath so the name still reads. The name sits low and centered;
/// more sits top right; the talking piece sits top left when this
/// person holds it.
///
/// Type, radius, and inset all scale with the card's own size, measured
/// against the 180 × 220 Figma card. Each proportion is written against
/// both sides and the smaller wins, so a short, wide gallery tile scales
/// down the same way a narrow one does. Values stop at the Figma size, so
/// big speaker tiles don't blow up. The speaker tile on web (3800:10538)
/// lets the name grow with the frame.
class ParticipantCard extends StatelessWidget {
  const ParticipantCard({
    super.key,
    required this.name,
    this.photo,
    this.background,
    this.onMore,
    this.showMore = true,
    this.showTalkingPiece = false,
    this.feature = false,
  });

  /// Shown on the card. Pass "Alex (you)" style labels from the caller.
  final String name;

  /// Image or video poster. Covers the card. Leave off to show the wash.
  final ImageProvider? photo;

  /// Painted under or instead of the photo. Defaults to the Figma wash.
  final Gradient? background;

  /// Opens the per-person menu. Hidden when [showMore] is false.
  final VoidCallback? onMore;

  /// Top-right more control. On by default in the circle.
  final bool showMore;

  /// Top-left talking-piece badge. Off by default.
  final bool showTalkingPiece;

  /// Larger speaker tile. Same card, different layout slot.
  final bool feature;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: name,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // CSS container units: 1cqw is 1% of the card's width.
          double fit(double cqw, double cqh) =>
              math.min(w * cqw / 100, h * cqh / 100);

          // The 180px gallery caps near 27.5; the 391px web speaker reaches 32.
          final radius = clampPx(12, fit(15.3, 12.5), 32);

          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: background ?? participantFallback,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Picture layer. Empty when there's no photo, so the wash shows.
                  if (photo case final photo?)
                    Image(
                      image: photo,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  if (showTalkingPiece) _piece(fit),
                  if (showMore) _more(w, fit),
                  _name(w, h, fit),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Same badge as the waiting-room preview. Size tracks the more icon so
  /// the two corners stay in balance. Native Figma mark is 37.7px on the
  /// 234px waiting-room tile. Decoration only — the tile is not a control.
  Widget _piece(double Function(double, double) fit) {
    final size = clampPx(18, fit(16.1, 13.4), 37.7062);
    return Positioned(
      top: clampPx(6, fit(5.6, 4.67), 13.13),
      left: clampPx(6, fit(5.15, 4.29), 12.05),
      width: size,
      height: size,
      child: IgnorePointer(
        child: SvgPicture.asset(
          '$_assets/talking-piece.svg',
          excludeFromSemantics: true,
        ),
      ),
    );
  }

  /// One quiet control per person, when the menu exists.
  Widget _more(double w, double Function(double, double) fit) {
    final icon = clampPx(18, fit(15.25, 12.47), 27.44);
    // Hit area stays at 32px or more even when the glyph is small, and
    // grows outward so the glyph stays where Figma put it.
    final hit = math.max(32.0, icon);
    final outset = (hit - icon) / 2;
    // Figma web speaker: 38.4 from the top, 30 from the right.
    final top = clampPx(8, fit(8, 9.7), 38.4);
    final right = clampPx(6, w * 0.077, 30);

    return Positioned(
      top: top - outset,
      right: right - outset,
      width: hit,
      height: hit,
      child: Pressable(
        onTap: onMore ?? () {},
        pressedScale: 0.92,
        focusColor: TotemColors.coreWhite,
        focusOffset: 1,
        focusRadius: BorderRadius.circular(Radii.full),
        semanticLabel: 'More options for $name',
        builder: (context, states) => AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: states.contains(WidgetState.hovered)
                ? const Color(0x2E000000)
                : Colors.transparent,
          ),
          child: SvgPicture.asset(
            '$_assets/more.svg',
            width: icon,
            height: icon,
            colorFilter: const ColorFilter.mode(
              TotemColors.coreWhite,
              BlendMode.srcIn,
            ),
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }

  /// The name, shadowed so it reads on any picture or wash.
  Widget _name(double w, double h, double Function(double, double) fit) {
    final double inset;
    final double bottom;
    final double size;
    final Shadow shadow;

    if (feature) {
      // Figma web (3800:10538) paints the speaker's name much larger than
      // the 180px gallery card — about 16cqh, capped so a full-bleed tile
      // doesn't turn into a billboard.
      inset = w * 0.08;
      bottom = clampPx(16, h * 0.055, 32);
      size = clampPx(28, fit(22, 15.5), 80);
      shadow = const Shadow(
        offset: Offset(0, 11),
        blurRadius: 11,
        color: Color(0x80000000),
      );
    } else {
      final lift = clampPx(1, fit(6.1, 5), 11);
      inset = w * 0.06;
      bottom = clampPx(8, fit(16.8, 13.7), 30.2);
      size = clampPx(13, fit(17.48, 14.3), 31.46);
      shadow = Shadow(
        offset: Offset(0, lift),
        blurRadius: lift,
        color: const Color(0x80000000),
      );
    }

    return Positioned(
      left: inset,
      right: inset,
      bottom: bottom,
      child: ExcludeSemantics(
        child: Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TotemText.raw(
            size: size,
            weight: FontWeight.w600,
            color: TotemColors.coreWhite,
          ).copyWith(shadows: [shadow]),
        ),
      ),
    );
  }
}

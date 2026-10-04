import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../paint.dart';
import '../../pressable.dart';
import '../../tokens/tokens.dart';

const _assets = 'assets/design/session_card';

/// Figma "Session Card — Session Screen" (3734:10290): photo on top,
/// time and seats, then the Space, the Session, and who holds it.
/// The calendar / Attend slot stays off — that variant hides it.
///
/// Native size is the Figma frame: 362 × 253, split evenly between the
/// photo and the white body. Width follows the parent; height keeps that
/// ratio so a narrower column doesn't squash the type against the picture.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.photo,
    required this.spaceName,
    required this.sessionName,
    required this.keeperName,
    this.keeperPhoto,
    required this.time,
    required this.meridiem,
    required this.seatsLeft,
    this.onSelect,
  });

  /// Cover photo. Crops to the top half of the card.
  final ImageProvider photo;

  /// Space the Session belongs to. One line, then it ellipsizes.
  final String spaceName;

  /// Session title. Two lines, then it ellipsizes.
  final String sessionName;

  /// Keeper shown next to "with".
  final String keeperName;

  /// Round Keeper photo. An initial stands in when this is missing.
  final ImageProvider? keeperPhoto;

  /// Clock time only — "4:00". Meridiem is a separate label.
  final String time;

  /// "AM" or "PM". Sits beside the time, lighter than the digits.
  final String meridiem;

  /// Open seats. The card always says "seats left" after the number.
  final int seatsLeft;

  /// Whole card is the hit target when this is set.
  final VoidCallback? onSelect;

  String get _seatsLabel =>
      seatsLeft == 1 ? '1 seat left' : '$seatsLeft seats left';

  @override
  Widget build(BuildContext context) {
    final label =
        '$sessionName, $time $meridiem, $_seatsLabel, with $keeperName';

    Widget card(Set<WidgetState> _) => AspectRatio(
      aspectRatio: 362 / 253,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: ColoredBox(
          color: TotemColors.coreWhite,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Portrait source; this crop matches the Figma frame.
              Expanded(
                child: Image(
                  image: photo,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.44),
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );

    // A card with onSelect is one control — the whole tile, not a nested
    // Attend chip. 253px is well over the 44pt hit target.
    final select = onSelect;
    if (select == null) {
      return Semantics(
        container: true,
        label: label,
        child: ExcludeSemantics(child: card({})),
      );
    }
    return Pressable(
      onTap: select,
      pressedScale: 0.98,
      focusColor: TotemColors.coreMauve,
      focusOffset: 3,
      focusRadius: BorderRadius.circular(Radii.lg),
      semanticLabel: label,
      excludeChildSemantics: true,
      builder: (context, states) => card(states),
    );
  }

  Widget _body() {
    const ink = TotemColors.coreSlate;
    final fact = TotemText.raw(size: 9, color: ink);

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Time first, then seats — same order as the Figma row.
          // The icon flips are how they sit in the file — do not "correct" them.
          Row(
            spacing: 21,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 3,
                children: [
                  Transform.flip(
                    flipY: true,
                    child: SvgPicture.asset(
                      '$_assets/icon-clock.svg',
                      width: 10.3547,
                      height: 10.3547,
                    ),
                  ),
                  // Digits sit a hair smaller and heavier than "PM".
                  Text(
                    time,
                    style: TotemText.raw(
                      size: 8,
                      weight: FontWeight.w700,
                      height: 1,
                      color: ink,
                    ),
                  ),
                  Text(meridiem, style: fact),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 3,
                children: [
                  Transform.flip(
                    flipX: true,
                    child: SvgPicture.asset(
                      '$_assets/icon-seats.svg',
                      width: 9.83693,
                      height: 9.83693,
                    ),
                  ),
                  Text(
                    '$seatsLeft',
                    style: fact.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    seatsLeft == 1 ? 'seat left' : 'seats left',
                    style: fact,
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 5,
            children: [
              Text(
                spaceName,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TotemText.raw(
                  size: 9,
                  weight: FontWeight.w600,
                  color: fade(ink, 0.7),
                ),
              ),
              Text(
                sessionName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TotemText.raw(
                  size: 12,
                  weight: FontWeight.w600,
                  color: const Color(0xFF000000),
                ),
              ),
            ],
          ),
          Row(
            spacing: 6,
            children: [
              _avatar(),
              Text('with', style: TotemText.raw(size: 14, color: ink)),
              Flexible(
                child: Text(
                  keeperName,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TotemText.raw(
                    size: 14,
                    weight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    const size = 28.24;
    final photo = keeperPhoto;
    if (photo != null) {
      return ClipOval(
        child: Image(
          image: photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: TotemColors.coreMauve,
        shape: BoxShape.circle,
      ),
      child: Text(
        keeperName.isEmpty ? '' : keeperName.substring(0, 1),
        style: TotemText.raw(
          size: 12,
          weight: FontWeight.w600,
          height: 1,
          color: TotemColors.coreWhite,
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

/// Overlay badge sizes for participant tiles.
///
/// Derived from the card's own size rather than the viewport, so the chrome
/// stays proportional to the video it sits on: a 12-person grid tile keeps the
/// compact badge no matter how large the window is, while a featured tile or a
/// 2-person grid gets a larger one.
///
/// The clamp is tight enough that most cards land on it rather than on the
/// ratio: with [_badgeToCardRatio] against [_minBadge]/[_maxBadge], the badge
/// only tracks the card for a shortest side of roughly 222–311dp. Below that
/// it pins to [_minBadge] (dense grids, phone portrait tiles), above it to
/// [_maxBadge] (featured tiles, sparse grids). The band mostly covers
/// mid-size tiles such as a phone-landscape grid.
@immutable
class ParticipantOverlayMetrics {
  const ParticipantOverlayMetrics({
    required this.badgeSize,
    required this.iconSize,
    required this.badgePadding,
    required this.emojiFontSize,
    required this.cornerInset,
  });

  /// Chrome for a card of [cardSize].
  ///
  /// [badgeSize] tracks the card's shortest side, clamped so small tiles keep
  /// a legible badge and large cards don't let it dominate the video. The
  /// remaining values are derived from it, which keeps the
  /// `badgeSize - 2 * badgePadding == iconSize` invariant true by
  /// construction.
  factory ParticipantOverlayMetrics.forCard(Size cardSize) {
    final shortestSide = cardSize.shortestSide;
    // An unbounded card would otherwise clamp *up* to the ceiling. A zero-size
    // card needs no guard: the clamp already lifts it to the floor.
    final badgeSize =
        (shortestSide.isFinite ? shortestSide * _badgeToCardRatio : _minBadge)
            .clamp(_minBadge, _maxBadge)
            .roundToDouble();
    final iconSize = (badgeSize * _iconToBadgeRatio).roundToDouble();

    return ParticipantOverlayMetrics(
      badgeSize: badgeSize,
      iconSize: iconSize,
      badgePadding: (badgeSize - iconSize) / 2,
      emojiFontSize: badgeSize * _emojiToBadgeRatio,
      cornerInset: (badgeSize * _insetToBadgeRatio)
          .clamp(_minCornerInset, _maxCornerInset)
          .roundToDouble(),
    );
  }

  /// Floor: the badge a phone grid tile has always used. Below this the glyph
  /// stops reading as an icon.
  static const _minBadge = 20.0;

  /// Ceiling: past this the badge starts dominating the video on a hero tile.
  static const _maxBadge = 28.0;

  static const _badgeToCardRatio = 0.09;
  static const _iconToBadgeRatio = 0.8;
  static const _emojiToBadgeRatio = 0.5;
  static const _insetToBadgeRatio = 0.5;
  static const _minCornerInset = 10.0;
  static const _maxCornerInset = 12.0;

  final double badgeSize;
  final double iconSize;
  final double badgePadding;
  final double emojiFontSize;
  final double cornerInset;

  @override
  bool operator ==(Object other) {
    return other is ParticipantOverlayMetrics &&
        badgeSize == other.badgeSize &&
        iconSize == other.iconSize &&
        badgePadding == other.badgePadding &&
        emojiFontSize == other.emojiFontSize &&
        cornerInset == other.cornerInset;
  }

  @override
  int get hashCode => Object.hash(
    badgeSize,
    iconSize,
    badgePadding,
    emojiFontSize,
    cornerInset,
  );
}

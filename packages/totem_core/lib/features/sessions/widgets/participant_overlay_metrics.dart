import 'package:flutter/widgets.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

/// Overlay badge sizes for participant tiles.
///
/// Compact covers phone, including landscape (`shortestSide <= 600`).
/// Comfortable applies at shortest side > 600dp (tablet portrait and desktop).
///
/// Not keyed off [ViewportKind.isLarge] — that flag also treats phone
/// landscape as large, which would blow these badges up on a 400×800 phone
/// rotated sideways.
@immutable
class ParticipantOverlayMetrics {
  const ParticipantOverlayMetrics({
    required this.badgeSize,
    required this.iconSize,
    required this.badgePadding,
    required this.emojiFontSize,
    required this.cornerInset,
  });

  /// Grid-tile chrome on phones. `badgeSize - 2 * badgePadding == iconSize`.
  static const compact = ParticipantOverlayMetrics(
    badgeSize: 20,
    iconSize: 16,
    badgePadding: 2,
    emojiFontSize: 10,
    cornerInset: 10,
  );

  /// Featured-tile chrome on phones. Slightly larger than [compact] so the
  /// hero video keeps the 24dp badge it used before overlay metrics existed.
  static const compactFeatured = ParticipantOverlayMetrics(
    badgeSize: 24,
    iconSize: 20,
    badgePadding: 2,
    emojiFontSize: 12,
    cornerInset: 10,
  );

  /// Tablet / desktop chrome. Shared by grid tiles and the featured tile.
  static const comfortable = ParticipantOverlayMetrics(
    badgeSize: 40,
    iconSize: 22,
    badgePadding: 9,
    emojiFontSize: 20,
    cornerInset: 12,
  );

  final double badgeSize;
  final double iconSize;
  final double badgePadding;
  final double emojiFontSize;
  final double cornerInset;

  /// Metrics for grid participant-card overlays.
  static ParticipantOverlayMetrics of(BuildContext context) {
    return switch (ViewportResolver.getViewportKind(context)) {
      ViewportKind.mediumSmall || ViewportKind.mediumPlus => comfortable,
      ViewportKind.smallPortrait || ViewportKind.smallLandscape => compact,
    };
  }

  /// Metrics for featured participant-card overlays.
  static ParticipantOverlayMetrics featuredOf(BuildContext context) {
    return switch (ViewportResolver.getViewportKind(context)) {
      ViewportKind.mediumSmall || ViewportKind.mediumPlus => comfortable,
      ViewportKind.smallPortrait ||
      ViewportKind.smallLandscape => compactFeatured,
    };
  }

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

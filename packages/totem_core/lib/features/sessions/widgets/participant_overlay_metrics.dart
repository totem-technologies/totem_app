import 'package:flutter/widgets.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

/// Overlay badge sizes for participant tiles.
///
/// Not keyed off [ViewportKind.isLarge] — that includes phone landscape.
@immutable
class ParticipantOverlayMetrics {
  const ParticipantOverlayMetrics({
    required this.badgeSize,
    required this.iconSize,
    required this.badgePadding,
    required this.emojiFontSize,
    required this.cornerInset,
  });

  static const compact = ParticipantOverlayMetrics(
    badgeSize: 20,
    iconSize: 16,
    badgePadding: 2,
    emojiFontSize: 10,
    cornerInset: 10,
  );

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

  static ParticipantOverlayMetrics of(BuildContext context) {
    return switch (ViewportResolver.getViewportKind(context)) {
      ViewportKind.mediumSmall || ViewportKind.mediumPlus => comfortable,
      ViewportKind.smallPortrait || ViewportKind.smallLandscape => compact,
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

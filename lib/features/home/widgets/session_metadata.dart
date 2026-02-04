import 'package:flutter/material.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/features/home/widgets/next_session_card.dart';
import 'package:totem_app/shared/totem_icons.dart';

/// Shared metadata components used across session cards.
///
/// These widgets provide consistent styling for session metadata like
/// date, time, and seats information across [NextSessionCard] and
/// [UpcomingSessionData].

// =============================================================================
// Session Metadata Icon
// =============================================================================

/// A small icon widget used in session metadata displays.
///
/// Displays a Totem icon with configurable size and color.
/// Default styling uses [AppTheme.gray] at 10px for compact cards.
class SessionMetadataIcon extends StatelessWidget {
  const SessionMetadataIcon({
    required this.icon,
    super.key,
    this.size = 10,
    this.color = AppTheme.gray,
  });

  /// The icon path from [TotemIcons]
  final String icon;

  /// Icon size in pixels (default: 10)
  final double size;

  /// Icon color (default: AppTheme.gray)
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TotemIcon(
      icon,
      size: size,
      color: color,
    );
  }
}

// =============================================================================
// Session Metadata Item
// =============================================================================

/// A metadata item widget combining an icon with text.
///
/// Used for displaying single-value metadata like date.
/// For time displays with separate period, use [SessionTimeMetadata].
class SessionMetadataItem extends StatelessWidget {
  const SessionMetadataItem({
    required this.icon,
    required this.text,
    super.key,
    this.textStyle,
    this.iconSize = 10,
    this.iconColor = AppTheme.gray,
    this.spacing = 2.4,
  });

  /// The icon path from [TotemIcons]
  final String icon;

  /// The text to display
  final String text;

  /// Custom text style (defaults to slate, w600, 10px)
  final TextStyle? textStyle;

  /// Icon size in pixels (default: 10)
  final double iconSize;

  /// Icon color (default: AppTheme.gray)
  final Color iconColor;

  /// Spacing between icon and text (default: 2.4)
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SessionMetadataIcon(icon: icon, size: iconSize, color: iconColor),
        SizedBox(width: spacing),
        Text(
          text,
          style:
              textStyle ??
              const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate,
              ),
        ),
      ],
    );
  }
}

// =============================================================================
// Session Time Metadata
// =============================================================================

/// A metadata widget for displaying time with separate period styling.
///
/// Shows time (e.g., "4:00") and period (e.g., "PM") with different styles.
/// The time value is typically bold, while the period is lighter.
class SessionTimeMetadata extends StatelessWidget {
  const SessionTimeMetadata({
    required this.time,
    required this.period,
    super.key,
    this.timeStyle,
    this.periodStyle,
    this.iconSize = 10,
    this.iconColor = AppTheme.gray,
    this.iconSpacing = 2.4,
    this.periodSpacing = 2,
  });

  /// The time string (e.g., "4:00")
  final String time;

  /// The period string (e.g., "PM")
  final String period;

  /// Custom style for the time (defaults to slate, w700, 10px)
  final TextStyle? timeStyle;

  /// Custom style for the period (defaults to gray, w400, 10px)
  final TextStyle? periodStyle;

  /// Icon size in pixels (default: 10)
  final double iconSize;

  /// Icon color (default: AppTheme.gray)
  final Color iconColor;

  /// Spacing between icon and time (default: 2.4)
  final double iconSpacing;

  /// Spacing between time and period (default: 2)
  final double periodSpacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Clock icon
        SessionMetadataIcon(
          icon: TotemIcons.clockCircle,
          size: iconSize,
          color: iconColor,
        ),
        SizedBox(width: iconSpacing),

        // Time value (bold)
        Text(
          time,
          style:
              timeStyle ??
              const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate,
              ),
        ),
        SizedBox(width: periodSpacing),

        // Period (lighter)
        Text(
          period,
          style:
              periodStyle ??
              const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppTheme.gray,
              ),
        ),
      ],
    );
  }
}

// =============================================================================
// Session Seats Metadata
// =============================================================================

/// A metadata widget for displaying remaining seat count.
///
/// Shows the number of seats left with a seats icon.
/// Splits into count (bold) and "seats left" label (lighter).
class SessionSeatsMetadata extends StatelessWidget {
  const SessionSeatsMetadata({
    required this.seatsLeft,
    super.key,
    this.countStyle,
    this.labelStyle,
    this.iconSize = 10,
    this.iconColor = AppTheme.gray,
    this.iconSpacing = 2.4,
    this.labelSpacing = 2,
  });

  /// The number of seats remaining
  final int seatsLeft;

  /// Custom style for the count (defaults to slate, w600, 10px)
  final TextStyle? countStyle;

  /// Custom style for the "seats left" label (defaults to gray, w400, 10px)
  final TextStyle? labelStyle;

  /// Icon size in pixels (default: 10)
  final double iconSize;

  /// Icon color (default: AppTheme.gray)
  final Color iconColor;

  /// Spacing between icon and count (default: 2.4)
  final double iconSpacing;

  /// Spacing between count and label (default: 2)
  final double labelSpacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Seats icon
        SessionMetadataIcon(
          icon: TotemIcons.seats,
          size: iconSize,
          color: iconColor,
        ),
        SizedBox(width: iconSpacing),

        // Count (bold)
        Text(
          '$seatsLeft',
          style:
              countStyle ??
              const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate,
              ),
        ),
        SizedBox(width: labelSpacing),

        // Label (lighter)
        Text(
          'seats left',
          style:
              labelStyle ??
              const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppTheme.gray,
              ),
        ),
      ],
    );
  }
}

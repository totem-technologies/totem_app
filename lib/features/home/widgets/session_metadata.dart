import 'package:flutter/material.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/features/home/widgets/next_session_card.dart';
import 'package:totem_app/shared/totem_icons.dart';

/// Shared metadata components used across session cards.
class SessionMetadataIcon extends StatelessWidget {
  const SessionMetadataIcon({
    required this.icon,
    super.key,
    this.size = 10,
    this.color = AppTheme.gray,
  });

  final String icon;
  final double size;
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

/// A metadata item widget combining an icon with text.
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

  final String icon;
  final String text;
  final TextStyle? textStyle;
  final double iconSize;
  final Color iconColor;
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

/// A metadata widget for displaying time with separate period styling.
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

  final String time;
  final String period;
  final TextStyle? timeStyle;
  final TextStyle? periodStyle;
  final double iconSize;
  final Color iconColor;
  final double iconSpacing;
  final double periodSpacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SessionMetadataIcon(
          icon: TotemIcons.clockCircle,
          size: iconSize,
          color: iconColor,
        ),
        SizedBox(width: iconSpacing),
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

/// A metadata widget for displaying remaining seat count.
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

  final int seatsLeft;
  final TextStyle? countStyle;
  final TextStyle? labelStyle;
  final double iconSize;
  final Color iconColor;
  final double iconSpacing;
  final double labelSpacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SessionMetadataIcon(
          icon: TotemIcons.seats,
          size: iconSize,
          color: iconColor,
        ),
        SizedBox(width: iconSpacing),
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

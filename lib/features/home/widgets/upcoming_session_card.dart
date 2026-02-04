import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/mobile_space_detail_schema.dart';
import 'package:totem_app/api/models/next_session_schema.dart';
import 'package:totem_app/api/models/session_detail_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

/// A card widget displaying an upcoming session with its details.
///
/// Design specs from Figma (node 2252:1202):
/// - White background, 20px rounded corners, 131px height
/// - Left: Image (130px width, rounded left corners only)
/// - Right: Content area with 10px padding containing metadata, title, and CTA
class UpcomingSessionCard extends StatelessWidget {
  const UpcomingSessionCard({
    required this.data,
    super.key,
    this.onTap,
  });

  /// Convenience constructor from SessionDetailSchema
  factory UpcomingSessionCard.fromSessionDetail(
    SessionDetailSchema session, {
    Key? key,
    VoidCallback? onTap,
  }) {
    return UpcomingSessionCard(
      key: key,
      data: UpcomingSessionData.fromSessionDetail(session),
      onTap: onTap,
    );
  }

  /// Convenience constructor from space and session
  factory UpcomingSessionCard.fromSpaceAndSession(
    MobileSpaceDetailSchema space,
    NextSessionSchema session, {
    Key? key,
    VoidCallback? onTap,
  }) {
    return UpcomingSessionCard(
      key: key,
      data: UpcomingSessionData.fromSpaceAndSession(space, session),
      onTap: onTap,
    );
  }

  final UpcomingSessionData data;
  final VoidCallback? onTap;

  /// Card dimensions from Figma design
  static const double _cardHeight = 131;
  static const double _imageWidth = 130;
  static const double _borderRadius = 20;
  static const double _contentPadding = 10;

  @override
  Widget build(BuildContext context) {
    // Format date and time for display using shared utilities
    final formattedDate = formatShortDate(data.start);
    final formattedTime = formatTimeOnly(data.start);
    final formattedTimePeriod = formatTimePeriod(data.start);

    // Build semantic label for accessibility
    final semanticLabel = [
      data.sessionTitle,
      formattedDate,
      '$formattedTime $formattedTimePeriod',
      '${data.seatsLeft} seats left',
      'with ${data.author.name ?? ''}',
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_borderRadius),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_borderRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap ?? () => _navigateToSession(context),
            child: SizedBox(
              height: _cardHeight,
              child: Row(
                children: [
                  // Left: Session image with rounded left corners only
                  _buildThumbnail(),

                  // Right: Content area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(_contentPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top: Metadata row (date, time, seats)
                          _buildMetadataRow(
                            formattedDate: formattedDate,
                            formattedTime: formattedTime,
                            formattedTimePeriod: formattedTimePeriod,
                          ),

                          // Middle: Space/category name
                          _buildSpaceName(),

                          // Middle: Session title
                          _buildSessionTitle(),

                          // Bottom: Keeper info and attend button
                          _buildKeeperRow(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the thumbnail image with rounded left corners only.
  Widget _buildThumbnail() {
    final imageUrl = data.imageUrl;

    return SizedBox(
      width: _imageWidth,
      height: double.infinity,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: getFullUrl(imageUrl),
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade200,
              ),
              errorWidget: (context, url, error) => Image.asset(
                TotemAssets.genericBackground,
                fit: BoxFit.cover,
              ),
            )
          : Image.asset(
              TotemAssets.genericBackground,
              fit: BoxFit.cover,
            ),
    );
  }

  /// Builds the metadata row showing date, time, and seats left.
  /// Uses space-between layout to spread items across the width.
  Widget _buildMetadataRow({
    required String formattedDate,
    required String formattedTime,
    required String formattedTimePeriod,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Date with calendar icon
        _MetadataItem(
          icon: TotemIcons.calendar,
          text: formattedDate,
          textStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate,
          ),
        ),

        // Time with clock icon
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MetadataIcon(icon: TotemIcons.clockCircle),
            const SizedBox(width: 2.4),
            Text(
              formattedTime,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              formattedTimePeriod,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppTheme.gray,
              ),
            ),
          ],
        ),

        // Seats left with chair icon
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MetadataIcon(icon: TotemIcons.seats),
            const SizedBox(width: 2.4),
            Text(
              '${data.seatsLeft}',
              style: const TextStyle(
                fontSize: 8.3,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate,
              ),
            ),
            const SizedBox(width: 2),
            const Text(
              'seats left',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: AppTheme.gray,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the space/category name text with muted styling.
  Widget _buildSpaceName() {
    // Use space title as fallback if category is empty
    final displayText = (data.category?.isNotEmpty ?? false)
        ? data.category!
        : data.spaceTitle;

    return SizedBox(
      height: 20,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate.withValues(alpha: 0.7),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Builds the session title with bold styling.
  Widget _buildSessionTitle() {
    return SizedBox(
      height: 38,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          data.sessionTitle,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.slate,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Builds the keeper info row with avatar, name, and attend button.
  Widget _buildKeeperRow(BuildContext context) {
    return Row(
      children: [
        // Keeper avatar (28px diameter)
        UserAvatar.fromUserSchema(
          data.author,
          radius: 14.12,
          borderWidth: 0,
        ),
        const SizedBox(width: 4),

        // "with" text
        const Text(
          'with ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: AppTheme.slate,
          ),
        ),

        // Keeper name
        Expanded(
          child: Text(
            data.author.name ?? '',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Attend button
        _buildAttendButton(context),
      ],
    );
  }

  /// Builds the attend button with outlined style matching Figma design.
  Widget _buildAttendButton(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.mauve, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToSession(context),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Text(
              'Attend',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.mauve,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Navigates to the session detail screen.
  void _navigateToSession(BuildContext context) {
    context.push(
      RouteNames.spaceEvent(data.spaceSlug, data.sessionSlug),
    );
  }
}

/// Helper widget for metadata items with icon and text.
class _MetadataItem extends StatelessWidget {
  const _MetadataItem({
    required this.icon,
    required this.text,
    required this.textStyle,
  });

  final String icon;
  final String text;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MetadataIcon(icon: icon),
        const SizedBox(width: 2.4),
        Text(text, style: textStyle),
      ],
    );
  }
}

/// Helper widget for metadata icons (10x10px).
class _MetadataIcon extends StatelessWidget {
  const _MetadataIcon({required this.icon});

  final String icon;

  @override
  Widget build(BuildContext context) {
    return TotemIcon(
      icon,
      size: 10,
      color: AppTheme.gray,
    );
  }
}

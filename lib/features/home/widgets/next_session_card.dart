import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/session_detail_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/home/widgets/session_metadata.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

/// A card widget displaying the user's next session with vertical layout.
///
/// Design based on screenshot:
/// - Large image at top with rounded corners
/// - Metadata row: date, time, seats left
/// - Space title in muted color
/// - Session title in bold
/// - Author row with avatar
class NextSessionCard extends StatelessWidget {
  const NextSessionCard({
    required this.session,
    super.key,
    this.onTap,
  });

  final SessionDetailSchema session;
  final VoidCallback? onTap;

  /// Design constants
  static const double _borderRadius = 20;
  static const double _contentPadding = 16;
  static const double _imageAspectRatio = 16 / 9;

  @override
  Widget build(BuildContext context) {
    // Format date and time for display
    final formattedDate = formatShortDate(session.start);
    final formattedTime = formatTimeOnly(session.start);
    final formattedTimePeriod = formatTimePeriod(session.start);

    // Build semantic label for accessibility
    final semanticLabel = [
      session.title,
      formattedDate,
      '$formattedTime $formattedTimePeriod',
      '${session.seatsLeft} seats left',
      'with ${session.space.author.name ?? ''}',
    ].join(', ');

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () => _navigateToSession(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top: Session image
              _buildImage(),

              // Bottom: Content area
              Padding(
                padding: const EdgeInsets.all(_contentPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Metadata row: date, time, seats
                    _buildMetadataRow(
                      formattedDate: formattedDate,
                      formattedTime: formattedTime,
                      formattedTimePeriod: formattedTimePeriod,
                    ),
                    const SizedBox(height: 12),

                    // Space title in muted color
                    _buildSpaceTitle(),
                    const SizedBox(height: 4),

                    // Session title in bold
                    _buildSessionTitle(),
                    const SizedBox(height: 12),

                    // Author row with avatar
                    _buildAuthorRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the session image with 16:9 aspect ratio.
  Widget _buildImage() {
    final imageUrl = session.space.imageLink;

    return AspectRatio(
      aspectRatio: _imageAspectRatio,
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
  /// Uses shared [SessionMetadataItem] widgets with larger sizing for this card.
  Widget _buildMetadataRow({
    required String formattedDate,
    required String formattedTime,
    required String formattedTimePeriod,
  }) {
    // Styling constants for this larger card variant
    const iconSize = 16.0;
    const spacing = 4.0;
    const textStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppTheme.slate,
    );
    const periodStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppTheme.gray,
    );

    return Row(
      children: [
        // Date with calendar icon
        SessionMetadataItem(
          icon: TotemIcons.calendar,
          text: formattedDate,
          iconSize: iconSize,
          spacing: spacing,
          textStyle: textStyle,
        ),
        const SizedBox(width: 24),

        // Time with clock icon
        SessionTimeMetadata(
          time: formattedTime,
          period: formattedTimePeriod,
          iconSize: iconSize,
          iconSpacing: spacing,
          periodSpacing: spacing,
          timeStyle: textStyle,
          periodStyle: periodStyle,
        ),
        const SizedBox(width: 24),

        // Seats left with chair icon
        SessionSeatsMetadata(
          seatsLeft: session.seatsLeft,
          iconSize: iconSize,
          iconSpacing: spacing,
          labelSpacing: spacing,
          countStyle: textStyle,
          labelStyle: periodStyle,
        ),
      ],
    );
  }

  /// Builds the space title with muted brown styling.
  Widget _buildSpaceTitle() {
    return Text(
      session.space.title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.slate.withValues(alpha: 0.7),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Builds the session title with bold black styling.
  Widget _buildSessionTitle() {
    return Text(
      session.title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppTheme.slate,
        height: 1.3,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Builds the author row with avatar and name.
  Widget _buildAuthorRow() {
    return Row(
      children: [
        // Author avatar
        UserAvatar.fromUserSchema(
          session.space.author,
          radius: 16,
          borderWidth: 0,
        ),
        const SizedBox(width: 8),

        // "with" text
        const Text(
          'with',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.slate,
          ),
        ),
        const SizedBox(width: 6),

        // Author name
        Expanded(
          child: Text(
            session.space.author.name ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Navigates to the session detail screen.
  void _navigateToSession(BuildContext context) {
    context.push(
      RouteNames.spaceEvent(session.space.slug, session.slug),
    );
  }
}

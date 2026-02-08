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
class NextSessionCard extends StatelessWidget {
  const NextSessionCard({
    required this.session,
    super.key,
    this.onTap,
  });

  final SessionDetailSchema session;
  final VoidCallback? onTap;

  static const double _borderRadius = 20;
  static const double _contentPadding = 16;
  static const double _imageAspectRatio = 16 / 9;

  @override
  Widget build(BuildContext context) {
    final formattedDate = formatShortDate(session.start);
    final formattedTime = formatTimeOnly(session.start);
    final formattedTimePeriod = formatTimePeriod(session.start);

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
              _buildImage(),
              Padding(
                padding: const EdgeInsets.all(_contentPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetadataRow(
                      formattedDate: formattedDate,
                      formattedTime: formattedTime,
                      formattedTimePeriod: formattedTimePeriod,
                    ),
                    const SizedBox(height: 12),
                    _buildSpaceTitle(),
                    const SizedBox(height: 4),
                    _buildSessionTitle(),
                    const SizedBox(height: 12),
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

  Widget _buildMetadataRow({
    required String formattedDate,
    required String formattedTime,
    required String formattedTimePeriod,
  }) {
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
        SessionMetadataItem(
          icon: TotemIcons.calendar,
          text: formattedDate,
          iconSize: iconSize,
          spacing: spacing,
          textStyle: textStyle,
        ),
        const SizedBox(width: 24),
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

  Widget _buildAuthorRow() {
    return Row(
      children: [
        UserAvatar.fromUserSchema(
          session.space.author,
          radius: 16,
          borderWidth: 0,
        ),
        const SizedBox(width: 8),
        const Text(
          'with',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.slate,
          ),
        ),
        const SizedBox(width: 6),
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

  void _navigateToSession(BuildContext context) {
    context.push(
      RouteNames.spaceEvent(session.space.slug, session.slug),
    );
  }
}

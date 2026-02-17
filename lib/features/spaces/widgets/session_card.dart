import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/features/home/models/upcoming_session_data.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class SessionCard extends StatelessWidget {
  const SessionCard({
    required this.data,
    super.key,
  });

  final UpcomingSessionData data;

  static const _borderRadius = 16.0;
  static const _imageHeight = 160.0;
  static const _contentPadding = EdgeInsets.all(12);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Session: ${data.sessionTitle}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_borderRadius),
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
            onTap: () => _navigateToSession(context),
            borderRadius: BorderRadius.circular(_borderRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: _SessionImage(
                    imageUrl: data.imageUrl,
                    height: _imageHeight,
                  ),
                ),
                Padding(
                  padding: _contentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SessionMetadata(
                        time: data.start,
                        seatsLeft: data.seatsLeft,
                        isAttending: data.attending,
                      ),
                      const SizedBox(height: 8),
                      _SessionSpaceTitle(title: data.spaceTitle),
                      const SizedBox(height: 4),
                      _SessionTitle(title: data.sessionTitle),
                      const SizedBox(height: 10),
                      _SessionFacilitator(author: data.author),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToSession(BuildContext context) {
    context.push(RouteNames.spaceSession(data.spaceSlug, data.sessionSlug));
  }
}

class _SessionImage extends StatelessWidget {
  const _SessionImage({required this.imageUrl, required this.height});

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height),
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: getFullUrl(imageUrl!),
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: Colors.grey.shade200),
                errorWidget: (_, _, _) => Image.asset(
                  TotemAssets.genericBackground,
                  fit: BoxFit.cover,
                ),
              )
            : Image.asset(TotemAssets.genericBackground, fit: BoxFit.cover),
      ),
    );
  }
}

class _SessionMetadata extends StatelessWidget {
  const _SessionMetadata({
    required this.time,
    required this.seatsLeft,
    required this.isAttending,
  });

  final DateTime time;
  final int seatsLeft;
  final bool isAttending;

  static final _textStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppTheme.slate.withValues(alpha: 0.8),
  );

  static final Color _iconColor = AppTheme.slate.withValues(alpha: 0.7);

  String get _availabilityText {
    if (isAttending) return 'Attending';
    if (seatsLeft == 0) return 'Full';
    return '$seatsLeft seats left';
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = formatTimeOnly(time);
    final formattedPeriod = formatTimePeriod(time);

    return Row(
      children: [
        Icon(Icons.access_time_outlined, size: 14, color: _iconColor),
        const SizedBox(width: 4),
        Text('$formattedTime $formattedPeriod', style: _textStyle),
        const SizedBox(width: 16),
        if (isAttending)
          Icon(Icons.check_circle_outline, size: 14, color: _iconColor)
        else
          TotemIcon(TotemIcons.seats, size: 14, color: _iconColor),
        const SizedBox(width: 4),
        Text(_availabilityText, style: _textStyle),
      ],
    );
  }
}

class _SessionSpaceTitle extends StatelessWidget {
  const _SessionSpaceTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppTheme.slate.withValues(alpha: 0.6),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SessionTitle extends StatelessWidget {
  const _SessionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.slate,
        height: 1.3,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SessionFacilitator extends StatelessWidget {
  const _SessionFacilitator({required this.author});

  final PublicUserSchema author;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar.fromUserSchema(author, radius: 14, borderWidth: 0),
        const SizedBox(width: 6),
        Text(
          'with ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.slate.withValues(alpha: 0.7),
          ),
        ),
        Expanded(
          child: Text(
            author.name ?? '',
            style: const TextStyle(
              fontSize: 12,
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
}

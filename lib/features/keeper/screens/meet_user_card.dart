import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class MeetUserCard extends StatelessWidget {
  const MeetUserCard({
    required this.user,
    super.key,
    this.margin = const EdgeInsetsDirectional.symmetric(horizontal: 16),
    this.bio,
    this.location,
  });

  final PublicUserSchema user;
  final EdgeInsetsGeometry margin;

  /// Optional bio text shown below the name/avatar row.
  final String? bio;

  /// Optional location string shown with a pin icon under the name.
  final String? location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      padding: const EdgeInsetsDirectional.fromSTEB(20, 21, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          // ── Avatar + name + location ──────────────────────────
          Row(
            spacing: 10,
            children: [
              UserAvatar.fromUserSchema(
                user,
                onTap: user.slug != null
                    ? () => context.push(RouteNames.keeperProfile(user.slug!))
                    : null,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name ?? 'Keeper',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      color: AppTheme.slate,
                    ),
                  ),
                  if (location != null && location!.isNotEmpty)
                    Row(
                      spacing: 2,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppTheme.gray,
                        ),
                        Text(
                          location!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.gray,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),

          // ── Bio ───────────────────────────────────────────────
          if (bio != null && bio!.isNotEmpty)
            Text(
              bio!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontFamily: AppTheme.fontFamilySans,
                fontWeight: FontWeight.w400,
                height: 1.2,
                color: AppTheme.slate.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}

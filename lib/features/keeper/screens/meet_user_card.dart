import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class MeetUserCard extends StatelessWidget {
  const MeetUserCard({required this.user, super.key});

  final PublicUserSchema user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsetsDirectional.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        spacing: 8,
        children: [
          UserAvatar.fromUserSchema(
            user,
            onTap: user.slug != null
                ? () {
                    context.push(
                      RouteNames.keeperProfile(user.slug!),
                    );
                  }
                : null,
          ),
          Expanded(
            child: Text(
              user.name ?? 'Keeper',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () {
              if (user.slug != null) {
                context.push(
                  RouteNames.keeperProfile(
                    user.slug!,
                  ),
                );
              }
            },
            child: const Text(
              'View Profile',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

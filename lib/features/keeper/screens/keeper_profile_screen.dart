import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/features/keeper/repositories/keeper_repository.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class KeeperProfileScreen extends ConsumerWidget {
  const KeeperProfileScreen({required this.username, super.key});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(keeperProfileProvider(username));
    return Scaffold(
      appBar: AppBar(),
      body: async.when(
        data: (keeper) {
          return ListView(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        spacing: 8,
                        children: [
                          UserAvatar(
                            seed: keeper.user.profileAvatarSeed,
                            image:
                                keeper.user.profileImage != null
                                    ? CachedNetworkImageProvider(
                                      keeper.user.profileImage!,
                                    )
                                    : null,
                            radius: 50,
                          ),
                          Text(keeper.user.name ?? 'Keeper'),
                          Text(keeper.location),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        spacing: 8,
                        children: [
                          Text('${keeper.circleCount}'),
                          const Text('Hosted Spaces'),

                          Text(keeper.monthJoined),
                          const Text('Month Joined'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Text('Biography'),
              Html(
                data: keeper.bio,
              ),
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorScreen(error: error),
      ),
    );
  }
}

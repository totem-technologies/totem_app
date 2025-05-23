import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boring_avatars/flutter_boring_avatars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';

class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, this.radius = 30, this.image});

  final double radius;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    return ClipOval(
      child: CircleAvatar(
        radius: radius,
        backgroundImage:
            image ??
            (user?.profileImage == null
                ? null
                : CachedNetworkImageProvider(user!.profileImage!)),
        child:
            user?.profileImage == null && image == null
                ? AnimatedBoringAvatar(
                  name: user!.profileAvatarSeed,
                  type: BoringAvatarType.beam,
                  duration: const Duration(milliseconds: 300),
                )
                : null,
      ),
    );
  }
}

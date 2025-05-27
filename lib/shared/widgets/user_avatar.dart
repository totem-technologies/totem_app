import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boring_avatars/flutter_boring_avatars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';

class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    this.radius = 30,
    this.image,
    this.showImage = true,
  });

  final double radius;
  final ImageProvider? image;
  final bool showImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    return Hero(
      tag: 'user-avatar-${user?.email}',
      child: ClipOval(
        child: CircleAvatar(
          radius: radius,
          backgroundImage:
              showImage
                  ? (image ??
                      (user?.profileImage == null
                          ? null
                          : CachedNetworkImageProvider(user!.profileImage!)))
                  : null,
          child:
              showImage && user?.profileImage == null && image == null
                  ? AnimatedBoringAvatar(
                    name: user!.profileAvatarSeed,
                    type: BoringAvatarType.beam,
                    duration: const Duration(milliseconds: 300),
                  )
                  : null,
        ),
      ),
    );
  }
}

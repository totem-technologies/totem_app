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
    this.seed,
    this.showImage = true,
    this.onTap,
    this.borderWidth = 1.5,
  });

  final double radius;
  final ImageProvider? image;
  final String? seed;
  final bool showImage;
  final VoidCallback? onTap;
  final double borderWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'user-avatar-${user?.email}',
        // For some reason, DecoratedBox is not working here
        // ignore: use_decorated_box
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: borderWidth),
          ),
          child: ClipOval(
            child: CircleAvatar(
              radius: radius,
              backgroundImage: showImage
                  ? (image ??
                        (user?.profileImage == null
                            ? null
                            : CachedNetworkImageProvider(user!.profileImage!)))
                  : null,
              child: showImage && user?.profileImage == null && image == null
                  ? AnimatedBoringAvatar(
                      name: seed ?? user!.profileAvatarSeed,
                      type: BoringAvatarType.marble,
                      duration: const Duration(milliseconds: 300),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

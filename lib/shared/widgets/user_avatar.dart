import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boring_avatars/flutter_boring_avatars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
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

  factory UserAvatar.fromUserSchema(
    PublicUserSchema? author, {
    double radius = 30,
    bool showImage = true,
    VoidCallback? onTap,
    double borderWidth = 1.5,
  }) {
    return UserAvatar(
      image: author?.profileImage != null
          ? CachedNetworkImageProvider(
              author!.profileImage!,
              cacheKey: author.slug,
            )
          : null,
      seed: author?.profileAvatarSeed,
      radius: radius,
      showImage: showImage,
      onTap: onTap,
      borderWidth: borderWidth,
    );
  }

  static Widget currentUser({
    double radius = 30,
    bool showImage = true,
    VoidCallback? onTap,
    double borderWidth = 1.5,
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);
        final user = authState.user;

        return UserAvatar(
          image: user?.profileImage != null
              ? CachedNetworkImageProvider(user!.profileImage!)
              : null,
          seed: user?.profileAvatarSeed,
          radius: radius,
          showImage: showImage,
          borderWidth: borderWidth,
          onTap: onTap,
        );
      },
    );
  }

  final double radius;
  final ImageProvider? image;
  final String? seed;
  final bool showImage;
  final VoidCallback? onTap;
  final double borderWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
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
            backgroundImage: showImage ? image : null,
            child: showImage && image == null
                ? AnimatedBoringAvatar(
                    name: seed ?? 'default',
                    type: BoringAvatarType.marble,
                    duration: const Duration(milliseconds: 300),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

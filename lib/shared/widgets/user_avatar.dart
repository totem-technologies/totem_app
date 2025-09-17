import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boring_avatars/flutter_boring_avatars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/profile_avatar_type_enum.dart';
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
    this.borderRadius = const BorderRadius.all(Radius.circular(100)),
  });

  factory UserAvatar.fromUserSchema(
    PublicUserSchema? author, {
    double radius = 30,
    bool showImage = true,
    VoidCallback? onTap,
    double borderWidth = 1.5,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(
      Radius.circular(100),
    ),
  }) {
    return UserAvatar(
      image:
          author?.profileImage != null &&
              author?.profileAvatarType == ProfileAvatarTypeEnum.im
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
      borderRadius: borderRadius,
    );
  }

  static Widget currentUser({
    double radius = 30,
    bool showImage = true,
    VoidCallback? onTap,
    double borderWidth = 1.5,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(
      Radius.circular(100),
    ),
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authControllerProvider);
        final user = authState.user;

        return UserAvatar(
          image:
              user?.profileImage != null &&
                  user?.profileAvatarType == ProfileAvatarTypeEnum.im
              ? CachedNetworkImageProvider(user!.profileImage!)
              : null,
          seed: user?.profileAvatarSeed,
          radius: radius,
          showImage: showImage,
          borderWidth: borderWidth,
          onTap: onTap,
          borderRadius: borderRadius,
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
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      // For some reason, DecoratedBox is not working here
      // ignore: use_decorated_box
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: borderWidth),
          borderRadius: borderRadius,
          image: showImage && image != null
              ? DecorationImage(
                  image: image!,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        height: radius * 2,
        width: radius * 2,
        child: showImage && image == null
            ? AnimatedBoringAvatar(
                name: seed ?? 'default',
                type: BoringAvatarType.marble,
                duration: const Duration(milliseconds: 300),
              )
            : null,
      ),
    );
  }
}

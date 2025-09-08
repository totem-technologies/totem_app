import 'dart:ui';

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
  });

  factory UserAvatar.fromUserSchema(
    PublicUserSchema? author, {
    double radius = 30,
    bool showImage = true,
    VoidCallback? onTap,
    double borderWidth = 1.5,
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
    final heroTag = 'avatar-${seed ?? image.hashCode}';
    return GestureDetector(
      onTap:
          onTap ??
          () {
            if (image != null) {
              showGeneralDialog(
                context: context,
                barrierDismissible: true,
                barrierLabel: MaterialLocalizations.of(
                  context,
                ).modalBarrierDismissLabel,
                barrierColor: Colors.black.withValues(alpha: 0.8),
                pageBuilder: (context, animation, secondaryAnimation) {
                  return _FullScreenImageViewer(
                    image: image!,
                    heroTag: heroTag,
                  );
                },
              );
            }
          },
      child: DecoratedBox(
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

class _FullScreenImageViewer extends StatefulWidget {
  const _FullScreenImageViewer({required this.image, required this.heroTag});
  final ImageProvider image;
  final Object heroTag;

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Offset _dragPosition = Offset.zero;
  late final _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () => Navigator.of(context).pop(),
          child: ColoredBox(
            color: Colors.black.withValues(
              alpha: clampDouble(0.0 - _controller.value, 0, 1),
            ),
            child: InteractiveViewer(
              transformationController: _transformationController,
              panEnabled: false,
              minScale: 1,
              maxScale: 4,
              onInteractionUpdate: (details) {
                setState(() {
                  _dragPosition += details.focalPointDelta;
                  final dragDistance = _dragPosition.dy.abs();
                  _controller.value = (dragDistance / 200).clamp(0.0, 1.0);
                });
              },
              onInteractionEnd: (details) {
                if (_controller.value > 0.5) {
                  Navigator.of(context).pop();
                } else {
                  _transformationController.value = Matrix4.identity();
                  setState(() {
                    _dragPosition = Offset.zero;
                    _controller.reverse();
                  });
                }
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(50),
                  child: Transform.translate(
                    offset: _dragPosition,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Hero(
        tag: widget.heroTag,
        child: ClipOval(
          child: Image(
            image: widget.image,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

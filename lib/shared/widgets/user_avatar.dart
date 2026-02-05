import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_boring_avatars/flutter_boring_avatars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/api/models/profile_avatar_type_enum.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/shared/network.dart';

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
          ? CachedNetworkImageProvider(getFullUrl(author!.profileImage!))
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
        final user = ref.watch(
          authControllerProvider.select((auth) => auth.user),
        );

        return UserAvatar(
          image:
              user?.profileImage != null &&
                  user?.profileAvatarType == ProfileAvatarTypeEnum.im
              ? CachedNetworkImageProvider(getFullUrl(user!.profileImage!))
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
    final heroTag = 'avatar-${seed ?? image.hashCode}';

    return GestureDetector(
      onTap:
          onTap ??
          () async {
            if (image != null) {
              await showGeneralDialog(
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
            ? ClipRRect(
                borderRadius: borderRadius,
                child: AnimatedBoringAvatar(
                  name: seed ?? 'default',
                  type: BoringAvatarType.marble,
                  duration: const Duration(milliseconds: 300),
                ),
              )
            : null,
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
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ColoredBox(
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
                  _controller.value = clampDouble(dragDistance / 200, 0, 1);
                });
              },
              onInteractionEnd: (details) {
                if (_controller.value > 0.5) {
                  Navigator.of(context).pop();
                } else {
                  _transformationController.value = Matrix4.identity();
                  setState(() {
                    _dragPosition = Offset.zero;
                  });
                  _controller.reverse();
                }
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(50),
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
      ),
    );
  }
}

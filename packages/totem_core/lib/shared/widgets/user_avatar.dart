import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_boring_avatars/flutter_boring_avatars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/repositories/user_repository.dart';
import 'package:totem_core/shared/network.dart';

class UserAvatar extends ConsumerWidget {
  const UserAvatar.custom({
    super.key,
    this.radius = 30,
    this.image,
    this.seed,
    this.showImage = true,
    this.onTap,
    this.borderWidth = 1.5,
    this.borderRadius = const BorderRadius.all(Radius.circular(100)),
  }) : user = null,
       slug = null,
       loading = null,
       error = null,
       _usesCurrentUser = false,
       _alwaysUseCurrentUser = false;

  const UserAvatar.fromUserSchema(
    this.user, {
    super.key,
    this.radius = 30,
    this.showImage = true,
    this.onTap,
    this.borderWidth = 1.5,
    this.borderRadius = const BorderRadius.all(Radius.circular(100)),
  }) : image = null,
       seed = null,
       slug = null,
       loading = null,
       error = null,
       _usesCurrentUser = true,
       _alwaysUseCurrentUser = false;

  const UserAvatar.currentUser({
    super.key,
    this.radius = 30,
    this.showImage = true,
    this.onTap,
    this.borderWidth = 1.5,
    this.borderRadius = const BorderRadius.all(Radius.circular(100)),
  }) : user = null,
       image = null,
       seed = null,
       slug = null,
       loading = null,
       error = null,
       _usesCurrentUser = true,
       _alwaysUseCurrentUser = true;

  const UserAvatar.slug(
    this.slug, {
    super.key,
    this.radius = 30,
    this.showImage = true,
    this.onTap,
    this.borderWidth = 1.5,
    this.borderRadius = const BorderRadius.all(Radius.circular(100)),
    this.loading,
    this.error,
  }) : user = null,
       image = null,
       seed = null,
       _usesCurrentUser = false,
       _alwaysUseCurrentUser = false;

  final double radius;
  final ImageProvider? image;
  final String? seed;
  final PublicUserSchema? user;
  final String? slug;
  final Widget? loading;
  final Widget? error;
  final bool _usesCurrentUser;
  final bool _alwaysUseCurrentUser;
  final bool showImage;
  final VoidCallback? onTap;
  final double borderWidth;
  final BorderRadiusGeometry borderRadius;

  static ImageProvider? _imageForUser({
    required String? profileImage,
    required ProfileAvatarTypeEnum profileAvatarType,
  }) {
    if (profileImage == null ||
        profileImage.isEmpty ||
        profileAvatarType != ProfileAvatarTypeEnum.im) {
      return null;
    }

    return CachedNetworkImageProvider(getFullUrl(profileImage));
  }

  Widget _buildSlugAvatar(WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(slug!));
    final fallback = UserAvatar.custom(
      seed: slug,
      radius: radius,
      showImage: showImage,
      onTap: onTap,
      borderWidth: borderWidth,
      borderRadius: borderRadius,
    );
    return profile.when(
      data: (user) => UserAvatar.custom(
        image: _imageForUser(
          profileImage: user.profileImage.value,
          profileAvatarType: user.profileAvatarType,
        ),
        seed: user.profileAvatarSeed,
        radius: radius,
        showImage: showImage,
        onTap: onTap,
        borderWidth: borderWidth,
        borderRadius: borderRadius,
      ),
      loading: () => loading ?? fallback,
      error: (error, stackTrace) => this.error ?? fallback,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (slug != null) return _buildSlugAvatar(ref);

    final currentUser = _usesCurrentUser
        ? ref.watch(authControllerProvider.select((auth) => auth.user))
        : null;
    final useCurrentUser =
        _usesCurrentUser &&
        (_alwaysUseCurrentUser ||
            (user != null && user!.slug.value == currentUser?.slug.value));
    final avatarImage = _usesCurrentUser
        ? _imageForUser(
            profileImage: useCurrentUser
                ? currentUser?.profileImage.value
                : user?.profileImage.value,
            profileAvatarType: useCurrentUser
                ? currentUser?.profileAvatarType ?? ProfileAvatarTypeEnum.td
                : user?.profileAvatarType ?? ProfileAvatarTypeEnum.td,
          )
        : image;
    final avatarSeed = _usesCurrentUser
        ? (useCurrentUser
              ? currentUser?.profileAvatarSeed
              : user?.profileAvatarSeed)
        : seed;
    final heroTag = 'avatar-${avatarSeed ?? avatarImage.hashCode}';

    final child = Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white,
          width: borderWidth,
          style: borderWidth == 0 ? BorderStyle.none : BorderStyle.solid,
        ),
        borderRadius: borderRadius,
        image: showImage && avatarImage != null
            ? DecorationImage(image: avatarImage, fit: BoxFit.cover)
            : null,
      ),
      height: radius * 2,
      width: radius * 2,
      child: showImage && avatarImage == null
          ? ClipRRect(
              borderRadius: borderRadius,
              child: AnimatedBoringAvatar(
                name: avatarSeed ?? 'default',
                type: BoringAvatarType.marble,
                duration: const Duration(milliseconds: 300),
              ),
            )
          : null,
    );

    if (onTap == null && avatarImage == null) return child;

    return GestureDetector(
      onTap:
          onTap ??
          () async {
            await showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: MaterialLocalizations.of(
                context,
              ).modalBarrierDismissLabel,
              barrierColor: Colors.black.withValues(alpha: 0.8),
              pageBuilder: (context, animation, secondaryAnimation) {
                return _FullScreenImageViewer(
                  image: avatarImage!,
                  heroTag: heroTag,
                );
              },
            );
          },
      child: child,
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
  final _dragPositionNotifier = ValueNotifier<Offset>(Offset.zero);
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
    _dragPositionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _dragPositionNotifier]),
        builder: (context, child) {
          final dragPosition = _dragPositionNotifier.value;
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
                _dragPositionNotifier.value += details.focalPointDelta;
                final dragDistance = _dragPositionNotifier.value.dy.abs();
                _controller.value = clampDouble(dragDistance / 200, 0, 1);
              },
              onInteractionEnd: (details) {
                if (_controller.value > 0.5) {
                  Navigator.of(context).pop();
                } else {
                  _transformationController.value = Matrix4.identity();
                  _dragPositionNotifier.value = Offset.zero;
                  _controller.reverse();
                }
              },
              child: Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(50),
                  child: Transform.translate(
                    offset: dragPosition,
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
            child: Image(image: widget.image, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

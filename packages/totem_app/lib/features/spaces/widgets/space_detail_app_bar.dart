import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/widgets/space_gradient_mask.dart';
import 'package:totem_core/shared/widgets/totem_image.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';

class SpaceDetailAppBar extends StatelessWidget {
  const SpaceDetailAppBar({required this.space, this.session, super.key});

  final MobileSpaceDetailSchema space;
  final AsyncValue<SessionDetailSchema>? session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.widthOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return GestureDetector(
      onTap: () async {
        await Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 180),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(25),
              ),
              child: ImageGradientMask(
                gradientHeight: 200,
                child: TotemImage(
                  imageUrl: space.imageLink,
                  memCacheWidth: (screenWidth * pixelRatio).round(),
                  loadingPlaceholder: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 8,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (session != null)
                          session!.when(
                            data: (session) => Text(
                              session.title,
                              style: theme.textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 28,
                                shadows: kElevationToShadow[4],
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (err, stack) => const SizedBox.shrink(),
                          ),
                        Text(
                          space.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                            ),
                            children: <TextSpan>[
                              const TextSpan(text: 'with '),
                              TextSpan(
                                text: space.author.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  UserAvatar.fromUserSchema(
                    space.author,
                    onTap: space.author.slug != null
                        ? () => context.push(
                            RouteNames.keeperProfile(space.author.slug!),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

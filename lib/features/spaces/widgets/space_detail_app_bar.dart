import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/widgets/space_gradient_mask.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class SpaceDetailAppBar extends StatelessWidget {
  const SpaceDetailAppBar({required this.event, super.key});

  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Scrollable.ensureVisible(
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
              child: SpaceGradientMask(
                gradientHeight: 200,
                child: CachedNetworkImage(
                  imageUrl: getFullUrl(event.space.image ?? ''),
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) {
                    return Image.asset(
                      TotemAssets.genericBackground,
                      fit: BoxFit.cover,
                    );
                  },
                  placeholder: (context, url) => ColoredBox(
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
                        Text(
                          event.title,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 28,
                            shadows: kElevationToShadow[4],
                          ),
                        ),
                        Text(
                          event.space.title,
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
                                text: event.space.author.name,
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
                    event.space.author,
                    onTap: event.space.author.slug != null
                        ? () {
                            context.push(
                              RouteNames.keeperProfile(
                                event.space.author.slug!,
                              ),
                            );
                          }
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

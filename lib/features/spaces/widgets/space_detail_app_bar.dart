import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/navigation/route_names.dart';
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
              child: CachedNetworkImage(
                imageUrl: event.space.image!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.error),
                color: Colors.black38,
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),

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
          /* This is now handled by the main app bar
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.adaptive.arrow_back),
                      iconSize: 24,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => popOrHome(context),
                    ),
                  ),
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Builder(
                      builder: (context) {
                        return IconButton(
                          icon: Icon(Icons.adaptive.share),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Scrollable.ensureVisible(
                              context,
                              duration: const Duration(milliseconds: 180),
                            );
                            final box =
                                context.findRenderObject() as RenderBox?;
                            SharePlus.instance.share(
                              ShareParams(
                                uri: Uri.parse(
                                  'https://totem.org/spaces/event/${event.slug}?utm_source=app&utm_medium=share',
                                ),
                                sharePositionOrigin:
                                    box != null
                                        ? box.localToGlobal(Offset.zero) &
                                            box.size
                                        : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          */
        ],
      ),
    );
  }
}

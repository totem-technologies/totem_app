import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';

class SpaceCard extends StatelessWidget {
  const SpaceCard({required this.space, super.key});
  final SpaceDetailSchema space;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 240,
        minWidth: 340,
        maxHeight: 340,
        maxWidth: 400,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsetsDirectional.zero,
        child: InkWell(
          highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
          onTap: () {
            context.push(RouteNames.space(space.nextEvent.slug));
          },
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (space.imageLink != null)
                Expanded(
                  child: Ink.image(
                    image: CachedNetworkImageProvider(
                      getFullUrl(space.imageLink!),
                    ),
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),

              Padding(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      space.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (space.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        space.description,
                        style: const TextStyle(color: Colors.grey),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Author info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: space.author.profileImage != null
                              ? CachedNetworkImageProvider(
                                  getFullUrl(space.author.profileImage!),
                                )
                              : null,
                          child: space.author.profileImage == null
                              ? Text(
                                  space.author.name?[0].toUpperCase() ?? '',
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${space.author.name}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),

                    if (space.category != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 8),
                        child: Chip(
                          label: Text(
                            space.category!,
                            style: const TextStyle(fontSize: 12),
                          ),
                          padding: EdgeInsetsDirectional.zero,
                        ),
                      ),

                    const SizedBox(height: 12),

                    if (space.nextEvent.link.isNotEmpty)
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Next event: '
                                    '${space.nextEvent.title!}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            if (space.nextEvent.start.isNotEmpty)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  top: 4,
                                ),
                                child: Text(
                                  formatEventDateTime(
                                    DateTime.parse(space.nextEvent.start),
                                  ),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SmallSpaceCard extends StatelessWidget {
  const SmallSpaceCard({required this.space, super.key});

  final SpaceDetailSchema space;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: CachedNetworkImageProvider(
            getFullUrl(space.imageLink ?? ''),
          ),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0x262F3799).withValues(alpha: 0),
            const Color(0xFF2F3799),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0x99262F37),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              formatEventDateTime(
                DateTime.parse(space.nextEvent.start),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${space.nextEvent.seatsLeft} seats left',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          Text(
            space.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

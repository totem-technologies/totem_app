import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';

class SpaceCard extends StatelessWidget {
  const SpaceCard({required this.space, super.key});
  final SpaceDetailSchema space;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsetsDirectional.zero,
      child: InkWell(
        highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
        onTap: () {
          context.push('/spaces/${space.nextEvent.slug}');
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (space.imageLink != null)
              Ink.image(
                image: CachedNetworkImageProvider(getFullUrl(space.imageLink!)),
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),

            Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
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
                      space.description.length > 100
                          ? '${space.description.substring(0, 100)}...'
                          : space.description,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Author info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage:
                            space.author.profileImage != null
                                ? CachedNetworkImageProvider(
                                  getFullUrl(space.author.profileImage!),
                                )
                                : null,
                        child:
                            space.author.profileImage == null
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Next event: '
                                '${space.nextEvent.title ?? "Upcoming Event"}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        if (space.nextEvent.start.isNotEmpty)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(top: 4),
                            child: Text(
                              formatEventDateTime(
                                DateTime.parse(space.nextEvent.start),
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

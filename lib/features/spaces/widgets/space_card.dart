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
    return AspectRatio(
      aspectRatio: 1.38,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsetsDirectional.zero,
        child: InkWell(
          highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
          onTap: () {
            context.push(RouteNames.space(space.nextEvent.slug));
          },
          borderRadius: BorderRadius.circular(8),

          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  getFullUrl(space.imageLink ?? ''),
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.45),
                  colorBlendMode: BlendMode.multiply,
                ),
              ),
              PositionedDirectional(
                top: 20,
                start: 20,
                end: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
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
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${space.nextEvent.seatsLeft}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: ' seats left',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      space.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      spacing: 8,
                      children: [
                        CircleAvatar(
                          radius: 18,
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
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'with ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                TextSpan(
                                  text: '${space.author.name}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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

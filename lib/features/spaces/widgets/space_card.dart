import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/api/models/next_event_schema.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/extensions.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

class SpaceCard extends StatelessWidget {
  const SpaceCard({
    required this.space,
    super.key,
    this.compact = false,
    this.onTap,
  });

  factory SpaceCard.fromEventDetailSchema(EventDetailSchema event) {
    return SpaceCard(
      space: SpaceDetailSchema(
        slug: event.space.slug!,
        title: event.space.title,
        imageLink: event.space.image,
        description: event.space.subtitle,
        author: event.space.author,
        nextEvent: NextEventSchema(
          start: event.start.toIso8601String(),
          link: event.calLink,
          seatsLeft: event.seatsLeft,
          slug: event.slug,
          title: event.title,
        ),
        category: '',
      ),
    );
  }

  final SpaceDetailSchema space;
  final bool compact;
  final VoidCallback? onTap;

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
          onTap:
              onTap ??
              () {
                context.push(RouteNames.space(space.nextEvent.slug));
              },
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    final cardHeight = rect.height;
                    const gradientHeight = 135.0;
                    final startStop =
                        ((cardHeight - gradientHeight) / cardHeight).clamp(
                          0.0,
                          1.0,
                        );
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [Colors.transparent, Colors.black],
                      stops: [startStop, 1.0],
                    ).createShader(
                      Rect.fromLTRB(0, 0, rect.width, rect.height),
                    );
                  },
                  blendMode: BlendMode.darken,
                  child: CachedNetworkImage(
                    imageUrl: getFullUrl(space.imageLink ?? ''),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => ColoredBox(
                      color: Colors.black.withValues(alpha: 0.75),
                    ),
                    errorWidget: (context, url, error) {
                      return Image.asset(
                        TotemAssets.genericBackground,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
              PositionedDirectional(
                top: compact ? 10.0 : 20.0,
                start: compact ? 10.0 : 20.0,
                end: compact ? 10.0 : 20.0,
                bottom: compact ? 10.0 : 26.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // If the width is too small, only show the image.
                    final isContentVisible = constraints.maxWidth > 66;
                    if (!isContentVisible) {
                      return const SizedBox.shrink();
                    }
                    final seatsLeft = RichText(
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${space.nextEvent.seatsLeft}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: ' seats left',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0x99262F37),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
                            children: [
                              const TotemIcon(
                                TotemIcons.calendar,
                                size: 12,
                                color: Colors.white,
                              ),
                              Flexible(
                                child: Text(
                                  buildTimeLabel(
                                    DateTime.parse(space.nextEvent.start),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (compact) seatsLeft,
                        AutoSizeText(
                          space.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 14 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.fade,
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'with '),
                                  TextSpan(
                                    text: space.author.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                                style: TextStyle(
                                  fontSize: compact ? 10 : 16,
                                  color: Colors.white,
                                ),
                              ),
                              const TextSpan(text: '  '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: UserAvatar.fromUserSchema(
                                  space.author,
                                  radius: 25 / 2,
                                ),
                              ),
                            ].reversedIf(compact),
                          ),
                        ),
                        if (!compact)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              top: 4,
                            ),
                            child: seatsLeft,
                          ),
                      ],
                    );
                  },
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
  const SmallSpaceCard({
    required this.space,
    this.onTap,
    super.key,
  });

  final SpaceDetailSchema space;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
      onTap:
          onTap ??
          () {
            context.push(RouteNames.space(space.nextEvent.slug));
          },
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ShaderMask(
                shaderCallback: (rect) {
                  final cardHeight = rect.height;
                  const gradientHeight = 90.0;
                  final startStop = ((cardHeight - gradientHeight) / cardHeight)
                      .clamp(
                        0.0,
                        1.0,
                      );
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [Colors.transparent, Colors.black],
                    stops: [startStop, 1.0],
                  ).createShader(
                    Rect.fromLTRB(0, 0, rect.width, rect.height),
                  );
                },
                blendMode: BlendMode.darken,
                child: CachedNetworkImage(
                  imageUrl: getFullUrl(space.imageLink ?? ''),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    TotemAssets.genericBackground,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black54,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 10,
            start: 10,
            end: 10,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x99262F37),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    buildTimeLabel(
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
                const SizedBox(height: 5),
                AutoSizeText(
                  space.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

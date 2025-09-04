import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
                child: CachedNetworkImage(
                  imageUrl: getFullUrl(space.imageLink ?? ''),
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.45),
                  colorBlendMode: BlendMode.multiply,
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
                    final isJoinButtonVisible = constraints.maxWidth > 200;

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
                        Text(
                          space.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 14 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
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
                          Container(
                            margin: const EdgeInsetsDirectional.only(
                              top: 4,
                            ),
                            height: 30,
                            child: Row(
                              spacing: 8,
                              children: [
                                Expanded(child: seatsLeft),
                                if (isJoinButtonVisible)
                                  Center(
                                    child: ElevatedButton.icon(
                                      onPressed: () {},
                                      label: const Text('Join'),
                                      icon: const TotemIcon(
                                        TotemIcons.arrowForward,
                                      ),
                                      iconAlignment: IconAlignment.end,
                                      style: const ButtonStyle(
                                        minimumSize: WidgetStatePropertyAll(
                                          Size(0, 28),
                                        ),
                                        padding: WidgetStatePropertyAll(
                                          EdgeInsetsDirectional.only(
                                            top: 8,
                                            bottom: 8,
                                            start: 24,
                                            end: 15,
                                          ),
                                        ),
                                        textStyle: WidgetStatePropertyAll(
                                          TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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
      child: Ink(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: CachedNetworkImageProvider(
              getFullUrl(space.imageLink ?? ''),
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.2),
              BlendMode.multiply,
            ),
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
    );
  }
}

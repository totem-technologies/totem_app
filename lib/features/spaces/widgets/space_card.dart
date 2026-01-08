import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/api/models/mobile_space_detail_schema.dart';
import 'package:totem_app/api/models/next_event_schema.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/extensions.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/space_gradient_mask.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

const _textShadows = [
  Shadow(
    offset: Offset(0, 1),
    blurRadius: 2,
    color: Color.fromRGBO(0, 0, 0, 0.5),
  ),
];

MobileSpaceDetailSchema _spaceDetailFromEventDetailSchema(
  EventDetailSchema event,
) {
  return MobileSpaceDetailSchema(
    slug: event.space.slug,
    title: event.space.title,
    imageLink: event.space.imageLink,
    content: event.space.content,
    shortDescription: event.space.shortDescription,
    author: event.space.author,
    recurring: event.space.recurring,
    price: event.space.price,
    subscribers: event.space.subscribers,
    nextEvents: [
      NextEventSchema(
        start: event.start,
        link: event.calLink,
        seatsLeft: event.seatsLeft,
        slug: event.slug,
        title: event.title,
        attending: event.attending,
        calLink: event.calLink,
        cancelled: event.cancelled,
        duration: event.duration,
        joinable: event.joinable,
        meetingProvider: event.meetingProvider,
        open: event.open,
      ),
    ],
    category: event.space.category,
  );
}

class SpaceCard extends StatelessWidget {
  const SpaceCard({
    required this.space,
    super.key,
    this.compact = false,
    this.onTap,
  });

  factory SpaceCard.fromEventDetailSchema(
    EventDetailSchema event, {
    bool compact = false,
    VoidCallback? onTap,
  }) {
    return SpaceCard(
      space: _spaceDetailFromEventDetailSchema(event),
      compact: compact,
      onTap: onTap,
    );
  }

  static Widget shimmer({bool compact = false}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: AspectRatio(
        aspectRatio: compact ? 16 / 9 : 1.38,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  final MobileSpaceDetailSchema space;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final nextEvent = space.nextEvents.firstOrNull;

    final semanticParts = <String>[
      space.title,
      if (nextEvent != null) ...[
        'next session: ${nextEvent.title}',
        buildTimeLabel(nextEvent.start),
        if (nextEvent.seatsLeft > 0)
          '${nextEvent.seatsLeft} ${nextEvent.seatsLeft == 1 ? 'spot' : 'spots'} left',
      ],
      'with keeper ${space.author.name}',
    ];
    final semanticLabel = semanticParts.join(', ');

    return AspectRatio(
      aspectRatio: 1.38,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsetsDirectional.zero,
        child: MergeSemantics(
          child: Semantics(
            button: true,
            label: semanticLabel,
            excludeSemantics: true,
            child: InkWell(
              highlightColor: theme.colorScheme.secondary.withValues(
                alpha: 0.1,
              ),
              onTap:
                  onTap ??
                  () async {
                    if (nextEvent != null) {
                      await context.push(
                        RouteNames.spaceEvent(
                          space.slug,
                          nextEvent.slug,
                        ),
                      );
                    } else {
                      await context.push(RouteNames.space(space.slug));
                    }
                  },
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ImageGradientMask(
                      child:
                          (space.imageLink != null &&
                              space.imageLink!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: getFullUrl(space.imageLink!),
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
                            )
                          : Image.asset(
                              TotemAssets.genericBackground,
                              fit: BoxFit.cover,
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
                        final seatsLeft = nextEvent != null
                            ? DefaultTextStyle.merge(
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  shadows: _textShadows,
                                ),
                                child: SeatsLeftText(
                                  seatsLeft: nextEvent.seatsLeft,
                                ),
                              )
                            : const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (nextEvent != null)
                              Container(
                                padding: const EdgeInsetsDirectional.all(8),
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
                                        buildTimeLabel(nextEvent.start),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          shadows: _textShadows,
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
                            if (nextEvent?.title != null)
                              AutoSizeText(
                                'Next: ${nextEvent!.title}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  shadows: _textShadows,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 6),
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
                                    child: IgnorePointer(
                                      child: UserAvatar.fromUserSchema(
                                        space.author,
                                        radius: 25 / 2,
                                      ),
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

  factory SmallSpaceCard.fromEventDetailSchema(
    EventDetailSchema event, {
    VoidCallback? onTap,
  }) {
    return SmallSpaceCard(
      space: _spaceDetailFromEventDetailSchema(event),
      onTap: onTap,
    );
  }

  final MobileSpaceDetailSchema space;
  final VoidCallback? onTap;

  static Widget shimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final nextEvent = space.nextEvents.firstOrNull;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
      onTap: onTap ?? () => context.push(RouteNames.space(space.slug)),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ImageGradientMask(
                child: (space.imageLink != null && space.imageLink!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: getFullUrl(space.imageLink!),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                        errorWidget: (context, url, error) => Image.asset(
                          TotemAssets.genericBackground,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        TotemAssets.genericBackground,
                        fit: BoxFit.cover,
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
            start: 12,
            end: 12,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nextEvent != null)
                  Container(
                    padding: const EdgeInsetsDirectional.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x99262F37),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      buildTimeLabel(nextEvent.start),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        shadows: _textShadows,
                      ),
                    ),
                  ),
                const Spacer(),
                if (nextEvent != null) ...[
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      shadows: _textShadows,
                    ),
                    child: SeatsLeftText(seatsLeft: nextEvent.seatsLeft),
                  ),
                  const SizedBox(height: 5),
                ],
                AutoSizeText(
                  space.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: _textShadows,
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

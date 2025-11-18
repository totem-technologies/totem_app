import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/api/models/meeting_provider_enum.dart';
import 'package:totem_app/api/models/mobile_space_detail_schema.dart';
import 'package:totem_app/api/models/next_event_schema.dart';
import 'package:totem_app/api/models/profile_avatar_type_enum.dart';
import 'package:totem_app/api/models/public_user_schema.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/extensions.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/space_gradient_mask.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

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

MobileSpaceDetailSchema _dummySpaceDetail() {
  return MobileSpaceDetailSchema(
    slug: 'dummy-space',
    title: 'Dummy Space',
    imageLink: 'https://placehold.co/400',
    shortDescription: 'Dummy Space',
    content: 'Dummy Space',
    author: PublicUserSchema(
      profileAvatarType: ProfileAvatarTypeEnum.im,
      dateCreated: DateTime.now(),
      name: 'Dummy User',
      slug: 'dummy-user',
      profileAvatarSeed: 'dummy-seed',
      profileImage: 'https://placehold.co/400',
      circleCount: 0,
    ),
    category: 'Dummy Category',
    subscribers: 0,
    recurring: 'Dummy Recurring',
    price: 0,
    nextEvents: [
      NextEventSchema(
        start: DateTime.now(),
        link: 'https://placehold.co/400',
        seatsLeft: 0,
        slug: 'dummy-event',
        title: 'Dummy Event',
        attending: false,
        calLink: 'https://placehold.co/400',
        duration: 0,
        meetingProvider: MeetingProviderEnum.googleMeet,
        cancelled: false,
        open: true,
        joinable: true,
      ),
    ],
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
      child: SpaceCard(space: _dummySpaceDetail(), compact: compact),
    );
  }

  final MobileSpaceDetailSchema space;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final nextEvent = space.nextEvents.firstOrNull;

    return AspectRatio(
      aspectRatio: 1.38,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsetsDirectional.zero,
        child: InkWell(
          highlightColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
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
                child: SpaceGradientMask(
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
                    final seatsLeft = DefaultTextStyle.merge(
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: kElevationToShadow[4],
                      ),
                      child: buildSeatsLeftText(
                        nextEvent?.seatsLeft ?? 0,
                      ),
                    );
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
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      shadows: kElevationToShadow[4],
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
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              shadows: kElevationToShadow[4],
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
      child: SmallSpaceCard(space: _dummySpaceDetail()),
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
              child: SpaceGradientMask(
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
                if (nextEvent != null)
                  Container(
                    padding: const EdgeInsetsDirectional.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x99262F37),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      buildTimeLabel(nextEvent.start),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        shadows: kElevationToShadow[4],
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  '${nextEvent?.seatsLeft ?? 'No'} seats left',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: kElevationToShadow[4],
                  ),
                ),
                const SizedBox(height: 5),
                AutoSizeText(
                  space.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: kElevationToShadow[4],
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

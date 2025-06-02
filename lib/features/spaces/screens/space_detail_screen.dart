import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/core/services/analytics_service.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_join_card.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({required this.eventSlug, super.key});
  final String eventSlug;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).logSpaceViewed(widget.eventSlug);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventAsync = ref.watch(eventProvider(widget.eventSlug));

    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 600;

    return Scaffold(
      body: eventAsync.when(
        data: (event) {
          return Stack(
            children: [
              Positioned.fill(
                child: RefreshIndicator.adaptive(
                  onRefresh:
                      () => ref.refresh(eventProvider(widget.eventSlug).future),
                  child: CustomScrollView(
                    slivers: [
                      SliverAppBar.large(
                        centerTitle: true,
                        collapsedHeight: 0,
                        toolbarHeight: 0,
                        expandedHeight: MediaQuery.sizeOf(context).height * 0.4,
                        automaticallyImplyLeading: false,
                        backgroundColor: theme.scaffoldBackgroundColor,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(25),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: event.space.image!,
                                    fit: BoxFit.cover,
                                    errorWidget:
                                        (context, url, error) =>
                                            const Icon(Icons.error),
                                    color: Colors.black38,
                                    colorBlendMode: BlendMode.darken,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsetsDirectional.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  spacing: 8,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            event.title,
                                            style: theme.textTheme.headlineLarge
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),

                                          RichText(
                                            text: TextSpan(
                                              style: theme.textTheme.bodyLarge
                                                  ?.copyWith(
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
                                    UserAvatar(
                                      seed:
                                          event.space.author.profileAvatarSeed,
                                      image:
                                          event.space.author.profileImage !=
                                                  null
                                              ? CachedNetworkImageProvider(
                                                getFullUrl(
                                                  event
                                                      .space
                                                      .author
                                                      .profileImage!,
                                                ),
                                              )
                                              : null,
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 20,
                                left: 20,
                                right: 20,
                                child: SafeArea(
                                  bottom: false,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                          onPressed: context.pop,
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
                                        child: IconButton(
                                          icon: Icon(Icons.adaptive.share),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () {
                                            launchUrl(
                                              Uri.parse(
                                                'https://totem.org/spaces/event/${event.slug}?utm_source=app&utm_medium=share',
                                              ),
                                              mode:
                                                  LaunchMode
                                                      .externalApplication,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding:
                            isPhone
                                ? const EdgeInsetsDirectional.only(
                                  start: 16,
                                  top: 16,
                                  end: 16,
                                  bottom: 16 + 64 * 2,
                                )
                                : const EdgeInsetsDirectional.only(
                                  start: 80,
                                  end: 80,
                                  top: 16,
                                  bottom: 16 + 64 * 2,
                                ),
                        sliver: SliverList.list(
                          children: [
                            Text(
                              'About this session',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildInfoText(
                                  const TotemIcon(TotemIcons.clockCircle),
                                  Text('${event.duration} minutes'),
                                ),
                                _buildInfoText(
                                  const TotemIcon(TotemIcons.seats),
                                  Text(
                                    event.seatsLeft > 0
                                        ? '${event.seatsLeft} seats left'
                                        : 'No seats left',
                                  ),
                                ),
                              ],
                            ),

                            Html(data: event.description),

                            // TODO(bdlukaa): About this space
                            Text(
                              'About this space',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildInfoText(
                                  const TotemIcon(TotemIcons.person),
                                  Text('${event.subscribers} subscribers'),
                                ),
                                _buildInfoText(
                                  const TotemIcon(TotemIcons.priceTag),
                                  Text(
                                    event.price == 0
                                        ? 'No cost'
                                        // TODO(bdlukaa): Format this price
                                        : 'Cost: ${event.price}',
                                  ),
                                ),
                                _buildInfoText(
                                  const TotemIcon(TotemIcons.calendar),
                                  Text(event.space.recurring),
                                ),
                              ],
                            ),

                            Html(data: event.space.shortDescription),

                            const SizedBox(height: 16),
                            Text(
                              'Meet the keeper',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Row(
                              spacing: 8,
                              children: [
                                UserAvatar(
                                  image:
                                      event.space.author.profileImage != null
                                          ? CachedNetworkImageProvider(
                                            getFullUrl(
                                              event.space.author.profileImage!,
                                            ),
                                          )
                                          : null,
                                  seed: event.space.author.profileAvatarSeed,
                                ),
                                Expanded(
                                  child: Text(
                                    event.space.author.name ?? 'Keeper',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    // TODO(bdlukaa): View keeper profile
                                  },
                                  child: const Text(
                                    'View Profile',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            // TODO(bdlukaa): More spaces held by this keeper
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: SpaceJoinCard(event: event),
              ),
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error:
            (err, stack) => Center(
              child: Text(
                'Error loading event details: $err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
      ),
    );
  }

  Widget _buildInfoText(Widget icon, Widget text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        IconTheme.merge(
          data: const IconThemeData(size: 14, color: Color(0xFF787D7E)),
          child: icon,
        ),
        DefaultTextStyle.merge(
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF787D7E),
          ),
          child: text,
        ),
      ],
    );
  }
}

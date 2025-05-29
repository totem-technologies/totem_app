import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/core/services/analytics_service.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';
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

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const TotemLogo(size: 24),
      ),
      body: eventAsync.when(
        data: (event) {
          return RefreshIndicator.adaptive(
            onRefresh:
                () => ref.refresh(eventProvider(widget.eventSlug).future),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isPhone = constraints.maxWidth < 600;
                return ListView(
                  padding:
                      isPhone
                          ? const EdgeInsetsDirectional.all(16)
                          : const EdgeInsetsDirectional.symmetric(
                            horizontal: 80,
                            vertical: 16,
                          ),
                  children: [
                    SizedBox(
                      height: constraints.maxHeight * 0.4,
                      child: Card(
                        margin: EdgeInsetsDirectional.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned.fill(
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
                            Padding(
                              padding: const EdgeInsetsDirectional.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
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
                                                ?.copyWith(color: Colors.white),
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
                                    image:
                                        event.space.author.profileImage != null
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
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      margin: const EdgeInsetsDirectional.symmetric(
                        vertical: 16,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatEventDate(event.start),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Text(
                              formatEventTime(event.start),
                              style: theme.textTheme.bodyMedium?.copyWith(),
                            ),

                            // TODO(bdlukaa): Attend to this session button
                          ],
                        ),
                      ),
                    ),
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
                        Chip(label: Text('${event.duration} minutes')),
                        Chip(
                          label: Text(
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
                        Chip(label: Text('${event.subscribers} subscribers')),
                        Chip(
                          label: Text(
                            event.price == 0
                                ? 'No cost'
                                // TODO(bdlukaa): Format this price
                                : 'Cost: ${event.price}',
                          ),
                        ),
                        Chip(label: Text(event.space.recurring)),
                      ],
                    ),

                    Html(data: event.space.shortDescription),

                    Text(
                      'About the author',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // TODO(bdlukaa): About the author

                    // TODO(bdlukaa): Join now button
                  ],
                );
              },
            ),
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
}

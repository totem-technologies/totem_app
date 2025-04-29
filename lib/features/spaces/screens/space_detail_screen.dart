import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/totem_icon.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.eventSlug, super.key});
  final String eventSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eventAsync = ref.watch(eventProvider(eventSlug));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const TotemLogo(size: 24),
      ),
      body: eventAsync.when(
        data: (event) {
          return RefreshIndicator.adaptive(
            onRefresh: () => ref.refresh(eventProvider(eventSlug).future),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ListView(
                  padding: const EdgeInsetsDirectional.all(16),
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: context.pop,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface,
                          textStyle: const TextStyle(
                            decoration: TextDecoration.none,
                          ),
                        ),
                        label: const Text('All spaces'),
                        icon: Icon(Icons.adaptive.arrow_back),
                        iconAlignment: IconAlignment.start,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: constraints.maxHeight * 0.6,
                      child: Card(
                        margin: EdgeInsets.zero,
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
                                color: Colors.black54,
                                colorBlendMode: BlendMode.darken,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text(
                                    event.title,
                                    style: theme.textTheme.headlineLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    event.spaceTitle,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w400,
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

                                  Text(
                                    'Starting at '
                                    '${formatEventDateTime(event.start)}',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  Flexible(
                                    child: Center(
                                      child: CircleAvatar(
                                        backgroundColor: Colors.transparent,
                                        foregroundImage:
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
                                        radius: 52,
                                      ),
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                _buildInfoItem(
                                  icon: Icons.star_border,
                                  title: '${event.subscribers} subscribers',
                                ),
                                _buildInfoItem(
                                  icon: Icons.attach_money_rounded,
                                  title:
                                      event.price == 0
                                          ? 'No cost'
                                          // TODO(bdlukaa): Format this price
                                          : 'Cost: ${event.price}',
                                ),
                                _buildInfoItem(
                                  icon: Icons.schedule,
                                  title: '${event.duration} minutes',
                                ),
                                _buildInfoItem(
                                  icon: Icons.repeat,
                                  title: event.recurring,
                                ),
                                _buildInfoItem(
                                  icon: Icons.chair_outlined,
                                  title:
                                      event.seatsLeft > 0
                                          ? '${event.seatsLeft} seats left'
                                          : 'No seats left',
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

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
                    Html(data: event.description),

                    // TODO(bdlukaa): About this space
                    // Text(
                    //   'About this space',
                    //   style: theme.textTheme.titleSmall?.copyWith(
                    //     fontWeight: FontWeight.bold,
                    //   ),
                    // ),
                    // Html(data: event.space.shortDescription),
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

  Widget _buildInfoItem({required IconData icon, required String title}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle()),
      ],
    );
  }
}

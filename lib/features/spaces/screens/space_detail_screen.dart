import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:share_plus/share_plus.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/core/services/analytics_service.dart';
import 'package:totem_app/features/keeper/screens/meet_user_card.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/info_text.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/features/spaces/widgets/space_detail_app_bar.dart';
import 'package:totem_app/features/spaces/widgets/space_join_card.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/extensions.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
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

  static const horizontalPadding = EdgeInsetsDirectional.symmetric(
    horizontal: 22,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventAsync = ref.watch(eventProvider(widget.eventSlug));

    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 600;

    final currencyFormatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: r'USD $',
    );

    return eventAsync.when(
      data: (event) {
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: NestedScrollView(
                  headerSliverBuilder: (context, _) {
                    return [
                      SliverAppBar.large(
                        centerTitle: true,
                        expandedHeight: MediaQuery.sizeOf(context).height * 0.4,
                        automaticallyImplyLeading: false,
                        backgroundColor: theme.scaffoldBackgroundColor,
                        flexibleSpace: FlexibleSpaceBar(
                          background: SpaceDetailAppBar(event: event),
                        ),
                        leading: Container(
                          margin: const EdgeInsetsDirectional.only(start: 20),
                          alignment: AlignmentDirectional.center,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.adaptive.arrow_back),
                              iconSize: 24,
                              visualDensity: VisualDensity.compact,
                              onPressed: () => popOrHome(context),
                            ),
                          ),
                        ),
                        actionsPadding: const EdgeInsetsDirectional.only(
                          end: 20,
                        ),
                        actions: [
                          Container(
                            height: 36,
                            alignment: AlignmentDirectional.center,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor,
                                shape: BoxShape.circle,
                              ),
                              child: Builder(
                                builder: (context) {
                                  return IconButton(
                                    icon: Icon(Icons.adaptive.share),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      final box =
                                          context.findRenderObject()
                                              as RenderBox?;
                                      SharePlus.instance.share(
                                        ShareParams(
                                          uri: Uri.parse(AppConfig.mobileApiUrl)
                                              .resolve(
                                                '/spaces/event/${event.slug}',
                                              )
                                              .resolve(
                                                '?utm_source=app'
                                                '&utm_medium=share',
                                              ),
                                          sharePositionOrigin: box != null
                                              ? box.localToGlobal(
                                                      Offset.zero,
                                                    ) &
                                                    box.size
                                              : null,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        title: Text(event.space.title),
                      ),
                    ];
                  },
                  body: RefreshIndicator.adaptive(
                    onRefresh: () =>
                        ref.refresh(eventProvider(widget.eventSlug).future),
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: ListView(
                        padding:
                            (isPhone
                                    ? const EdgeInsetsDirectional.only(
                                        top: 16,
                                        bottom: 124,
                                      )
                                    : const EdgeInsetsDirectional.only(
                                        start: 80,
                                        end: 80,
                                        top: 16,
                                        bottom: 16 + 64 * 2,
                                      ))
                                .add(
                                  EdgeInsetsDirectional.only(
                                    bottom: MediaQuery.paddingOf(
                                      context,
                                    ).bottom,
                                  ),
                                ),
                        children: [
                          Padding(
                            padding: horizontalPadding,
                            child: Column(
                              spacing: 10,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InfoText(
                                  const TotemIcon(TotemIcons.subscribers),
                                  Text('${event.subscribers} subscribers'),
                                  const Text(
                                    'Be part of a growing community. Join '
                                    'others who share your interests. Small '
                                    'but mighty — join today.',
                                  ),
                                ),
                                InfoText(
                                  const TotemIcon(TotemIcons.priceTag),
                                  Text(
                                    event.price == 0
                                        ? 'No cost'
                                        : currencyFormatter.format(event.price),
                                  ),
                                  Text(
                                    event.price == 0
                                        ? 'Completely free — no hidden fees. '
                                              'Enjoy all the benefits at no '
                                              'charge. It costs nothing to get '
                                              'started.'
                                        : 'This price grants you full access '
                                              'to the event. Secure your spot '
                                              'and enjoy all the activities '
                                              'and content available.',
                                  ),
                                ),
                                InfoText(
                                  const TotemIcon(TotemIcons.recurring),
                                  Text(event.recurring),
                                  const Text(
                                    'We meet according to the space’s unique '
                                    'schedule.',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: horizontalPadding.add(
                              const EdgeInsetsDirectional.only(
                                top: 22,
                                bottom: 4,
                              ),
                            ),
                            child: Text(
                              'About',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          Html(
                            data:
                                event.space.shortDescription
                                        ?.trim()
                                        .isNotEmpty ??
                                    false
                                ? event.space.shortDescription
                                : event.description,
                            style: {
                              ...AppTheme.htmlStyle,
                              'body': Style(
                                margin: Margins.symmetric(
                                  horizontal: horizontalPadding.start,
                                ),
                              ),
                            },
                            onLinkTap: (url, _, _) {
                              if (url != null) launchUrl(Uri.parse(url));
                            },
                            onAnchorTap: (url, _, _) {
                              if (url != null) launchUrl(Uri.parse(url));
                            },
                          ),

                          if (event.space.content.trim().isNotEmpty)
                            Container(
                              height: 32,
                              margin: const EdgeInsetsDirectional.only(top: 8),
                              padding: horizontalPadding,
                              child: OutlinedButton(
                                onPressed: () =>
                                    _showAboutSpaceSheet(context, event),
                                style: const ButtonStyle(
                                  padding: WidgetStatePropertyAll(
                                    EdgeInsetsDirectional.zero,
                                  ),
                                ),
                                child: const Text('Show more'),
                              ),
                            ),
                          const SizedBox(height: 16),

                          // TODO(bdlukaa): Sessions Calendar
                          Container(
                            padding: horizontalPadding,
                            constraints: const BoxConstraints(maxHeight: 160),
                            child: SpaceCard.fromEventDetailSchema(
                              event,
                              onTap: () => _showSessionSheet(context, event),
                              compact: true,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Padding(
                            padding: horizontalPadding,
                            child: Text(
                              'Meet the keeper',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          MeetUserCard(user: event.space.author),
                        ],
                      ),
                    ),
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
          ),
        );
      },
      loading: () => const LoadingScreen(),
      error: (err, stack) => ErrorScreen(error: err, showHomeButton: true),
    );
  }

  Future<void> _showAboutSpaceSheet(
    BuildContext context,
    EventDetailSchema event,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (context) {
        return AboutSpaceSheet(event: event);
      },
    );
  }

  Future<void> _showSessionSheet(
    BuildContext context,
    EventDetailSchema event,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return SessionSheet(event: event);
      },
    );
  }
}

class AboutSpaceSheet extends StatelessWidget {
  const AboutSpaceSheet({required this.event, super.key});

  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const titleCurve = Curves.easeOut;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 1,
      builder: (context, controller) {
        return CustomScrollView(
          controller: controller,
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              expandedHeight: 112,
              flexibleSpace: ListenableBuilder(
                listenable: Listenable.merge([controller]),
                builder: (context, child) {
                  const scrollRange = 56.0;
                  final progress = (controller.offset / scrollRange).clamp(
                    0.0,
                    1.0,
                  );
                  final curvedProgress = titleCurve.transform(progress);
                  const maxAdditionalPadding = 48.0;
                  final additionalPadding =
                      maxAdditionalPadding * curvedProgress;
                  return FlexibleSpaceBar(
                    titlePadding: EdgeInsetsDirectional.only(
                      start: 20 + additionalPadding,
                      bottom: 12,
                    ),
                    collapseMode: CollapseMode.pin,
                    expandedTitleScale: 1,
                    title: Text('About', style: theme.textTheme.titleLarge),
                  );
                },
              ),
              leading: Container(
                margin: const EdgeInsetsDirectional.only(start: 20),
                alignment: Alignment.center,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.adaptive.arrow_back),
                    iconSize: 24,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsetsDirectional.only(
                top: 8,
                start: 20,
                end: 20,
                bottom: 20,
              ),
              sliver: SliverList.list(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      CompactInfoText(
                        const TotemIcon(TotemIcons.subscribers),
                        Text('${event.subscribers} subscribers'),
                      ),
                      CompactInfoText(
                        const TotemIcon(TotemIcons.priceTag),
                        Text(
                          event.price == 0
                              ? 'No cost'
                              : NumberFormat.currency(
                                  locale: 'en_US',
                                  symbol: r'USD $',
                                ).format(event.price),
                        ),
                      ),
                      CompactInfoText(
                        const TotemIcon(TotemIcons.recurring),
                        Text(event.recurring.uppercaseFirst()),
                      ),
                    ],
                  ),
                  Html(
                    data: markdown.markdownToHtml(event.space.content),
                    shrinkWrap: true,
                    onLinkTap: (url, _, _) {
                      if (url != null) launchUrl(Uri.parse(url));
                    },
                    onAnchorTap: (url, _, _) {
                      if (url != null) launchUrl(Uri.parse(url));
                    },
                    style: {...AppTheme.compactHtmlStyle},
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class SessionSheet extends StatelessWidget {
  const SessionSheet({required this.event, super.key});

  final EventDetailSchema event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              controller: controller,
              shrinkWrap: true,
              padding: const EdgeInsetsDirectional.only(
                start: 20,
                end: 20,
                bottom: 20,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title, style: theme.textTheme.titleLarge),
                          Text.rich(
                            TextSpan(
                              text: 'with ',
                              children: [
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
                    UserAvatar.fromUserSchema(
                      event.space.author,
                      radius: 40,
                      onTap: event.space.slug != null
                          ? () {
                              context.push(
                                RouteNames.keeperProfile(event.space.slug!),
                              );
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'About this session',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CompactInfoText(
                      const TotemIcon(TotemIcons.clockCircle),
                      Text('${event.duration} minutes'),
                    ),
                    CompactInfoText(
                      const TotemIcon(TotemIcons.seats),
                      Text('${event.seatsLeft} seats left'),
                    ),
                  ],
                ),
                Html(
                  data: event.description,
                  shrinkWrap: true,
                  style: AppTheme.compactHtmlStyle,
                  onLinkTap: (url, _, _) {
                    if (url != null) launchUrl(Uri.parse(url));
                  },
                  onAnchorTap: (url, _, _) {
                    if (url != null) launchUrl(Uri.parse(url));
                  },
                ),
              ],
            ),
          ),
          SpaceJoinCard(event: event),
        ],
      ),
    );
  }
}

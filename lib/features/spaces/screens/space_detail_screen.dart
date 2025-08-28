import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/api/models/next_event_schema.dart';
import 'package:totem_app/api/models/space_detail_schema.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/core/services/analytics_service.dart';
import 'package:totem_app/features/keeper/screens/meet_user_card.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/space_card.dart';
import 'package:totem_app/features/spaces/widgets/space_detail_app_bar.dart';
import 'package:totem_app/features/spaces/widgets/space_join_card.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/extensions.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';

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
          body: NestedScrollView(
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
                    alignment: Alignment.center,
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
                      alignment: Alignment.center,
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
                                    context.findRenderObject() as RenderBox?;
                                SharePlus.instance.share(
                                  ShareParams(
                                    uri: Uri.parse(
                                      'https://totem.org/spaces/event/${event.slug}?utm_source=app&utm_medium=share',
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
                              bottom: MediaQuery.paddingOf(context).bottom,
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
                      data: event.space.shortDescription?.isNotEmpty ?? false
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
                    ),

                    if (event.space.shortDescription != null &&
                        event.space.shortDescription!.isNotEmpty)
                      Container(
                        height: 32,
                        margin: const EdgeInsetsDirectional.only(top: 8),
                        padding: horizontalPadding,
                        child: OutlinedButton(
                          onPressed: () => _showAboutSpaceSheet(context, event),
                          style: const ButtonStyle(
                            padding: WidgetStatePropertyAll(
                              EdgeInsets.zero,
                            ),
                          ),
                          child: const Text('Show more'),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // TODO(bdlukaa): Sessions Calendar
                    Container(
                      padding: horizontalPadding,
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: SpaceCard(
                        onTap: () => _showSessionSheet(context, event),
                        compact: true,
                        space: SpaceDetailSchema(
                          author: event.space.author,
                          category: '',
                          description: event.space.shortDescription ?? '',
                          imageLink: event.space.image,
                          nextEvent: NextEventSchema(
                            slug: event.space.slug!,
                            start: event.start.toIso8601String(),
                            link: event.calLink,
                            title: event.title,
                            seatsLeft: event.seatsLeft,
                          ),
                          slug: event.slug,
                          title: event.title,
                        ),
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 1,
      builder: (context, controller) {
        return Scaffold(
          appBar: AppBar(),
          body: ListView(
            controller: controller,
            padding: const EdgeInsetsDirectional.only(
              start: 20,
              end: 20,
              bottom: 20,
            ),
            children: [
              Text('About', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
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
                data: event.space.shortDescription,
                shrinkWrap: true,
              ),
            ],
          ),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
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
              ),
            ],
          ),
        ),
        SpaceJoinCard(event: event),
      ],
    );
  }
}

class InfoText extends StatelessWidget {
  const InfoText(this.icon, this.text, this.subtitle, {super.key});

  final Widget icon;
  final Widget text;
  final Widget subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        IconTheme.merge(
          data: const IconThemeData(size: 24, color: AppTheme.slate),
          child: icon,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppTheme.slate,
                  fontWeight: FontWeight.w600,
                ),
                child: text,
              ),
              DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppTheme.slate,
                  fontWeight: FontWeight.w400,
                ),
                child: subtitle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CompactInfoText extends StatelessWidget {
  const CompactInfoText(this.icon, this.text, {super.key});

  final Widget icon;
  final Widget text;

  @override
  Widget build(BuildContext context) {
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

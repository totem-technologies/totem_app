import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:totem_app/api/export.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/config/theme.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/analytics_service.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/core/services/calendar_service.dart';
import 'package:totem_app/features/keeper/screens/meet_user_card.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/features/spaces/widgets/info_text.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/navigation/route_names.dart';
import 'package:totem_app/shared/assets.dart';
import 'package:totem_app/shared/date.dart';
import 'package:totem_app/shared/extensions.dart';
import 'package:totem_app/shared/html.dart';
import 'package:totem_app/shared/logger.dart';
import 'package:totem_app/shared/network.dart';
import 'package:totem_app/shared/routing.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/utils.dart';
import 'package:totem_app/shared/widgets/circle_icon_button.dart';
import 'package:totem_app/shared/widgets/confirmation_dialog.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/loading_indicator.dart';
import 'package:totem_app/shared/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

enum SpaceJoinCardState {
  ended,
  cancelled,
  closed,
  joinable,
  full,
  attending,
  notJoined,
}

Future<void> _handleHtmlLinkTap(String? url, BuildContext context) async {
  if (url == null) return;
  final appRoute = RoutingUtils.parseTotemDeepLink(url);
  if (appRoute != null && context.mounted) {
    await context.push(appRoute);
  } else {
    launchUrl(Uri.parse(url));
  }
}

class SpaceDetailScreen extends ConsumerStatefulWidget {
  const SpaceDetailScreen({required this.slug, this.sessionSlug, super.key});

  final String slug;

  /// The slug used to get a specific session. If null, the session will be the
  /// next upcoming session.
  final String? sessionSlug;

  @override
  ConsumerState<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends ConsumerState<SpaceDetailScreen> {
  final _scrollController = ScrollController();
  bool _appBarCollapsed = false;
  String? _selectedEventSlug;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).logSpaceViewed(widget.slug);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final collapsed =
        _scrollController.hasClients && _scrollController.offset > 180;
    if (collapsed != _appBarCollapsed) {
      setState(() => _appBarCollapsed = collapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spaceAsync = ref.watch(spaceProvider(widget.slug));
    ref.sentryReportFullyDisplayed(spaceProvider(widget.slug));

    // Determine if we have a valid session slug to watch
    final String? effectiveEventSlug =
        _selectedEventSlug ??
        widget.sessionSlug ??
        spaceAsync.maybeWhen(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          data: (space) => space.nextEvents.firstOrNull?.slug,
          orElse: () => null,
        );

    // Only watch event provider if we have a valid slug
    final bool hasValidEventSlug =
        effectiveEventSlug != null && effectiveEventSlug.isNotEmpty;

    final AsyncValue<SessionDetailSchema>? eventAsync = hasValidEventSlug
        ? ref.watch(eventProvider(effectiveEventSlug))
        : null;

    return spaceAsync.when(
      data: (space) {
        return Scaffold(
          body: Stack(
            children: [
              const SizedBox.expand(),
              Positioned.fill(
                child: NestedScrollView(
                  controller: _scrollController,
                  headerSliverBuilder: (context, _) {
                    final collapsedTitle =
                        eventAsync?.maybeWhen(
                          data: (event) => event.title,
                          orElse: () => null,
                        ) ??
                        space.title;
                    return [
                      SliverAppBar(
                        expandedHeight: 262,
                        pinned: true,
                        automaticallyImplyLeading: false,
                        backgroundColor: theme.scaffoldBackgroundColor,
                        scrolledUnderElevation: 0,
                        title: AnimatedOpacity(
                          opacity: _appBarCollapsed ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            collapsedTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.slate,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          collapseMode: CollapseMode.parallax,
                          background: _SpaceHeaderImage(space: space),
                        ),
                        leading: CircleIconButton(
                          margin: const EdgeInsetsDirectional.only(start: 20),
                          icon: TotemIcons.arrowBack,
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          onPressed: () => popOrHome(context),
                        ),
                        leadingWidth: 50,
                        actionsPadding: const EdgeInsetsDirectional.only(
                          end: 20,
                        ),
                        actions: [
                          Builder(
                            builder: (context) {
                              return CircleIconButton(
                                icon: TotemIcons.share,
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).shareButtonLabel,
                                onPressed: () async {
                                  final box =
                                      context.findRenderObject() as RenderBox?;
                                  await SharePlus.instance.share(
                                    ShareParams(
                                      uri: Uri.parse(AppConfig.mobileApiUrl)
                                          .resolve(
                                            '/spaces/event/${space.slug}',
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
                        ],
                      ),
                    ];
                  },
                  body: RefreshIndicator.adaptive(
                    onRefresh: () {
                      return Future.wait([
                        ref.refresh(spaceProvider(widget.slug).future),
                        if (hasValidEventSlug)
                          ref.refresh(
                            eventProvider(effectiveEventSlug).future,
                          ),
                      ]);
                    },
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: ListView(
                        padding: EdgeInsetsDirectional.only(
                          bottom: MediaQuery.paddingOf(context).bottom + 24,
                        ),
                        children: [
                          const SizedBox(height: 10),

                          // ── Title section ──────────────────────────────
                          Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 10,
                              children: [
                                // Space title — shown as a label only when
                                // a session title will appear below it
                                if (eventAsync != null &&
                                    space.title.trim().isNotEmpty)
                                  Text(
                                    space.title,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: AppTheme.slate.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                // Session title (or space title when no session)
                                Text(
                                  eventAsync?.maybeWhen(
                                        data: (event) => event.title,
                                        orElse: () => null,
                                      ) ??
                                      space.title,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 21,
                                        color: AppTheme.slate,
                                      ),
                                ),

                                // "with [Author]" row
                                Row(
                                  spacing: 4,
                                  children: [
                                    UserAvatar.fromUserSchema(
                                      space.author,
                                      radius: 19,
                                      onTap: space.author.slug != null
                                          ? () => context.push(
                                              RouteNames.keeperProfile(
                                                space.author.slug!,
                                              ),
                                            )
                                          : null,
                                    ),
                                    Text(
                                      'with ',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                    Text(
                                      space.author.name ?? '',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 18,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Session info card ──────────────────────────
                          Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 20,
                            ),
                            child: _SessionInfoCard(
                              space: space,
                              eventAsync: eventAsync,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── About this Session ─────────────────────────
                          if (eventAsync != null)
                            Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 16,
                                children: [
                                  Text(
                                    'About this Session',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 14,
                                        ),
                                  ),
                                  eventAsync.when(
                                    data: (event) => Html(
                                      data: event.content,
                                      shrinkWrap: true,
                                      style: {
                                        ...AppTheme.compactHtmlStyle,
                                        'body': Style(margin: Margins.zero),
                                      },
                                      extensions: [
                                        TotemImageHtmlExtension(),
                                      ],
                                      onLinkTap: (url, _, _) =>
                                          _handleHtmlLinkTap(url, context),
                                      onAnchorTap: (url, _, _) =>
                                          _handleHtmlLinkTap(url, context),
                                    ),
                                    loading: () => const SizedBox(height: 80),
                                    error: (_, _) => const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          // ── Upcoming Similar Sessions ──────────────────
                          _UpcomingSessionsSection(
                            space: space,
                            currentEventSlug: effectiveEventSlug,
                          ),

                          const SizedBox(height: 24),

                          // ── Meet The Keeper ────────────────────────────
                          Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 16,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Meet The Keeper',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.black,
                                            ),
                                      ),
                                    ),
                                    if (space.author.slug != null)
                                      GestureDetector(
                                        onTap: () => context.push(
                                          RouteNames.keeperProfile(
                                            space.author.slug!,
                                          ),
                                        ),
                                        child: Row(
                                          spacing: 2,
                                          children: [
                                            Text(
                                              'View Profile',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: AppTheme.slate
                                                        .withValues(alpha: 0.7),
                                                  ),
                                            ),
                                            const TotemIcon(
                                              TotemIcons.arrowForward,
                                              size: 12,
                                              color: AppTheme.gray,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                MeetUserCard(
                                  user: space.author,
                                  margin: EdgeInsetsDirectional.zero,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const LoadingScreen(),
      error: (err, stack) => ErrorScreen(error: err, showHomeButton: true),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header image (no text overlay)
// ─────────────────────────────────────────────────────────────

class _SpaceHeaderImage extends StatelessWidget {
  const _SpaceHeaderImage({required this.space});

  final MobileSpaceDetailSchema space;

  @override
  Widget build(BuildContext context) {
    if (space.imageLink != null && space.imageLink!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: getFullUrl(space.imageLink!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => ColoredBox(
          color: Colors.black.withValues(alpha: 0.5),
        ),
        errorWidget: (context, url, error) => Image.asset(
          TotemAssets.genericBackground,
          fit: BoxFit.cover,
        ),
      );
    }
    return Image.asset(
      TotemAssets.genericBackground,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Session info card — state-aware attend button
// ─────────────────────────────────────────────────────────────

class _SessionInfoCard extends ConsumerStatefulWidget {
  const _SessionInfoCard({required this.space, required this.eventAsync});

  final MobileSpaceDetailSchema space;
  final AsyncValue<SessionDetailSchema>? eventAsync;

  @override
  ConsumerState<_SessionInfoCard> createState() => _SessionInfoCardState();
}

class _SessionInfoCardState extends ConsumerState<_SessionInfoCard> {
  MobileSpaceDetailSchema get space => widget.space;

  bool _attending = false;
  bool _loading = false;
  bool _joined = false;
  bool _initialized = false;
  String _currentTimeago = '';
  Timer? _timer;
  Timer? _confettiTimer;

  void _initFromEvent(SessionDetailSchema event) {
    if (_initialized) return;
    _initialized = true;
    _attending = event.attending;
    _currentTimeago = timeago.format(event.start, allowFromNow: true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = timeago.format(event.start, allowFromNow: true);
      if (_currentTimeago != next) setState(() => _currentTimeago = next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiTimer?.cancel();
    super.dispose();
  }

  SpaceJoinCardState _computeState(
    SessionDetailSchema event,
    UserSchema? user,
  ) {
    final ended =
        event.ended ||
        event.start
            .add(Duration(minutes: event.duration))
            .isBefore(DateTime.now());
    return switch (event) {
      _ when event.cancelled => SpaceJoinCardState.cancelled,
      _ when ended => SpaceJoinCardState.ended,
      _ when _joined || (event.canJoinNow(user) && event.joinable) =>
        SpaceJoinCardState.joinable,
      _ when _attending => SpaceJoinCardState.attending,
      _ when event.seatsLeft <= 0 => SpaceJoinCardState.full,
      _ when !event.open => SpaceJoinCardState.closed,
      _ => SpaceJoinCardState.notJoined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider.select((a) => a.user));
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: r'USD $',
    );

    widget.eventAsync?.whenData(_initFromEvent);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
      ),
      padding: const EdgeInsetsDirectional.all(20),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats grid ───────────────────────────────────────
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              CompactInfoText(
                const TotemIcon(TotemIcons.subscribers),
                Text('${space.subscribers} subscribers'),
              ),
              if (widget.eventAsync != null)
                ...widget.eventAsync!.maybeWhen(
                  data: (event) => [
                    CompactInfoText(
                      const TotemIcon(TotemIcons.clockCircle),
                      Text('${event.duration} min'),
                    ),
                    CompactInfoText(
                      const TotemIcon(TotemIcons.seats),
                      SeatsLeftText(seatsLeft: event.seatsLeft),
                    ),
                  ],
                  orElse: () => <Widget>[],
                ),
              if (space.recurring != null && space.recurring!.isNotEmpty)
                CompactInfoText(
                  const TotemIcon(TotemIcons.recurring),
                  Text(space.recurring!),
                ),
              CompactInfoText(
                const TotemIcon(TotemIcons.priceTag),
                Text(
                  space.price == 0
                      ? 'No Cost'
                      : currencyFormatter.format(space.price),
                ),
              ),
            ],
          ),

          // ── Date / Attend row ────────────────────────────────
          if (widget.eventAsync != null) ...[
            const SizedBox(height: 17),
            widget.eventAsync!.when(
              data: (event) {
                final state = _computeState(event, user);
                return _DateAttendRow(
                  event: event,
                  state: state,
                  currentTimeago: _currentTimeago,
                  loading: _loading,
                  onAttend: () => _attend(event),
                  onGiveUpSpot: () => _giveUpSpot(event),
                  onAddToCalendar: () => _addToCalendar(event),
                  onJoinLivekit: () => _joinLivekit(event),
                  onJoinGoogleMeet: () => _joinGoogleMeet(event),
                  onExplore: () => toHome(HomeRoutes.spaces),
                );
              },
              loading: () => const SizedBox(height: 44),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────

  Future<void> _attend(SessionDetailSchema event) async {
    if (_attending ||
        _loading ||
        (kDebugMode && AppConfig.isProduction) ||
        !mounted) {
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(mobileApiServiceProvider);
      final response = await api.spaces
          .totemSpacesMobileApiMobileApiRsvpConfirm(eventSlug: event.slug);
      if (response.attending) {
        if (mounted) setState(() => _attending = true);
        await _attendingPopup(event);
        await _refresh(event);
      } else {
        if (mounted) {
          showErrorPopup(
            context,
            icon: TotemIcons.spaces,
            title: 'Failed to attend this circle',
            message: 'Please try again later',
          );
        }
      }
    } catch (e, st) {
      ErrorHandler.logError(e, stackTrace: st, message: 'Failed to attend');
      if (mounted) {
        showErrorPopup(
          context,
          icon: TotemIcons.spaces,
          title: 'Failed to attend this circle',
          message: 'Please try again later',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _attendingPopup(SessionDetailSchema event) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AttendingDialog(
        eventSlug: event.slug,
        onAddToCalendar: () => _addToCalendar(event),
      ),
    );
    double randomInRange(double min, double max) =>
        min + Random().nextDouble() * (max - min);
    const total = 10;
    var progress = 0;
    _confettiTimer?.cancel();
    _confettiTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      progress++;
      if (progress >= total) {
        timer.cancel();
        return;
      }
      final count = ((1 - progress / total) * 50).toInt();
      final ctx = context; // snapshot after mounted check
      Confetti.launch(
        ctx,
        options: ConfettiOptions(
          particleCount: count,
          startVelocity: 30,
          spread: 360,
          ticks: 60,
          x: randomInRange(0.1, 0.3),
          y: Random().nextDouble() - 0.2,
        ),
      );
      Confetti.launch(
        ctx,
        options: ConfettiOptions(
          particleCount: count,
          startVelocity: 30,
          spread: 360,
          ticks: 60,
          x: randomInRange(0.7, 0.9),
          y: Random().nextDouble() - 0.2,
        ),
      );
    });
  }

  Future<void> _addToCalendar(SessionDetailSchema event) async {
    final calendarEvent = AppCalendarEvent(
      title: '[TOTEM] ${event.title} - ${space.title}',
      description: space.shortDescription,
      location: getFullUrl(event.calLink),
      start: event.start.toLocal(),
      end: event.start.add(Duration(minutes: event.duration)).toLocal(),
      reminderMinutesBefore: 10,
    );
    try {
      final success = await CalendarService.addToCalendar(calendarEvent);
      if (!success && mounted) {
        showErrorPopup(
          context,
          icon: TotemIcons.calendar,
          title: 'Failed to add event to calendar',
          message: 'Please try again later',
        );
      }
    } catch (e, st) {
      ErrorHandler.logError(
        e,
        stackTrace: st,
        message: 'Failed to add to calendar',
      );
      if (mounted) {
        showErrorPopup(
          context,
          icon: TotemIcons.calendar,
          title: 'Failed to add event to calendar',
          message: 'Please try again later',
        );
      }
    }
  }

  Future<void> _giveUpSpot(SessionDetailSchema event) async {
    final giveUp = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        content: 'Are you sure you want to give up your spot?',
        confirmButtonText: 'Give up my spot',
        onConfirm: () async => Navigator.of(context).pop(true),
      ),
    );
    if (giveUp == null || !giveUp || !mounted) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(mobileApiServiceProvider);
      final response = await api.spaces.totemSpacesMobileApiMobileApiRsvpCancel(
        eventSlug: event.slug,
      );
      if (mounted) {
        setState(() => _loading = false);
      }
      if (!response.attending) {
        if (mounted) {
          setState(() => _attending = false);
        }
        if (mounted) {
          showErrorPopup(
            context,
            icon: TotemIcons.seats,
            title: 'You gave up your spot',
            message: 'You can always attend again if a spot opens up.',
          );
        }
        await _refresh(event);
      } else {
        if (mounted) {
          showErrorPopup(
            context,
            icon: TotemIcons.seats,
            title: 'Failed to give up your spot',
            message: 'Please try again later',
          );
        }
      }
    } catch (e, st) {
      ErrorHandler.logError(
        e,
        stackTrace: st,
        message: 'Failed to give up spot',
      );
      if (mounted) {
        showErrorPopup(
          context,
          icon: TotemIcons.seats,
          title: 'Failed to give up your spot',
          message: 'Please try again later',
        );
      }
    }
  }

  Future<void> _joinLivekit(SessionDetailSchema event) async {
    logger.d('Joining livekit session: ${event.slug}');
    setState(() => _joined = true);
    await context.pushNamed(RouteNames.videoSessionPrejoin, extra: event.slug);
  }

  Future<void> _joinGoogleMeet(SessionDetailSchema event) async {
    setState(() => _joined = true);
    await launchUrl(
      Uri.parse(getFullUrl(event.calLink)),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _refresh(SessionDetailSchema event) async {
    _initialized =
        false; // allow _initFromEvent to re-run with fresh start time
    // ignore: unused_result
    await ref.refresh(eventProvider(event.slug).future);
    // ignore: unused_result
    await ref.refresh(spaceProvider(space.slug).future);
  }
}

// ─────────────────────────────────────────────────────────────
// Date + attend button row (pure display)
// ─────────────────────────────────────────────────────────────

class _DateAttendRow extends StatelessWidget {
  const _DateAttendRow({
    required this.event,
    required this.state,
    required this.currentTimeago,
    required this.loading,
    required this.onAttend,
    required this.onGiveUpSpot,
    required this.onAddToCalendar,
    required this.onJoinLivekit,
    required this.onJoinGoogleMeet,
    required this.onExplore,
  });

  final SessionDetailSchema event;
  final SpaceJoinCardState state;
  final String currentTimeago;
  final bool loading;
  final VoidCallback onAttend;
  final VoidCallback onGiveUpSpot;
  final VoidCallback onAddToCalendar;
  final VoidCallback onJoinLivekit;
  final VoidCallback onJoinGoogleMeet;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dateLabel = switch (state) {
      SpaceJoinCardState.ended => 'No more upcoming sessions',
      SpaceJoinCardState.cancelled => 'Session cancelled',
      SpaceJoinCardState.joinable => 'Session started',
      SpaceJoinCardState.closed => 'Registration closed',
      SpaceJoinCardState.full => 'Session full',
      SpaceJoinCardState.attending ||
      SpaceJoinCardState.notJoined => formatSessionDate(event.start),
    };
    final timeLabel = switch (state) {
      SpaceJoinCardState.attending || SpaceJoinCardState.notJoined =>
        formatSessionTime(event.start, event.userTimezone),
      SpaceJoinCardState.joinable => currentTimeago,
      _ => 'Explore upcoming sessions',
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                dateLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate,
                ),
              ),
              Text(
                timeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.gray,
                ),
              ),
            ],
          ),
        ),
        _buildButton(context),
      ],
    );
  }

  Widget _buildButton(BuildContext context) {
    const pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(42)),
    );
    const pad = EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8);
    const minSize = Size.zero;
    const tap = MaterialTapTargetSize.shrinkWrap;

    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: AppTheme.mauve,
      side: const BorderSide(color: AppTheme.mauve),
      shape: pill,
      padding: pad,
      minimumSize: minSize,
      tapTargetSize: tap,
    );

    // Attending: calendar + give-up-spot buttons
    if (state == SpaceJoinCardState.attending) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Tooltip(
            message: 'Add to calendar',
            child: OutlinedButton(
              onPressed: onAddToCalendar,
              style: outlinedStyle,
              child: const TotemIcon(TotemIcons.calendar, size: 16),
            ),
          ),
          Tooltip(
            message: 'Give up your spot',
            child: OutlinedButton(
              onPressed: loading ? null : onGiveUpSpot,
              style: outlinedStyle,
              child: loading
                  ? const LoadingIndicator(size: 16)
                  : const TotemIcon(TotemIcons.giveUpSpot, size: 16),
            ),
          ),
        ],
      );
    }

    final label = switch (state) {
      SpaceJoinCardState.ended ||
      SpaceJoinCardState.cancelled ||
      SpaceJoinCardState.closed ||
      SpaceJoinCardState.full => 'Explore',
      SpaceJoinCardState.joinable => 'Join Now',
      SpaceJoinCardState.notJoined => 'Attend',
      SpaceJoinCardState.attending => 'Attending',
    };

    void onPressed() => switch (state) {
      SpaceJoinCardState.ended ||
      SpaceJoinCardState.cancelled ||
      SpaceJoinCardState.closed ||
      SpaceJoinCardState.full => onExplore(),
      SpaceJoinCardState.joinable =>
        event.meetingProvider == MeetingProviderEnum.livekit
            ? onJoinLivekit()
            : onJoinGoogleMeet(),
      SpaceJoinCardState.notJoined => onAttend(),
      SpaceJoinCardState.attending => onAddToCalendar(),
    };

    final child = loading
        ? const LoadingIndicator(color: Colors.white, size: 16)
        : Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          );

    if (state == SpaceJoinCardState.joinable ||
        state == SpaceJoinCardState.notJoined) {
      return ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.mauve,
          foregroundColor: Colors.white,
          shape: pill,
          padding: pad,
          minimumSize: minSize,
          tapTargetSize: tap,
          elevation: 0,
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: outlinedStyle,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Upcoming Similar Sessions section
// ─────────────────────────────────────────────────────────────

class _UpcomingSessionsSection extends StatelessWidget {
  const _UpcomingSessionsSection({
    required this.space,
    required this.currentEventSlug,
  });

  final MobileSpaceDetailSchema space;
  final String? currentEventSlug;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcomingSessions = space.nextEvents
        .where((e) => e.slug != currentEventSlug)
        .toList();

    if (upcomingSessions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Text(
            'Upcoming Similar Sessions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          for (final session in upcomingSessions)
            _UpcomingSessionCard(
              space: space,
              session: session,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Horizontal upcoming session card
// ─────────────────────────────────────────────────────────────

class _UpcomingSessionCard extends StatelessWidget {
  const _UpcomingSessionCard({
    required this.space,
    required this.session,
  });

  final MobileSpaceDetailSchema space;
  final NextSessionSchema session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push(
        RouteNames.spaceSession(space.slug, session.slug),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // ── Image ──────────────────────────────────────────
            SizedBox(
              width: 130,
              height: double.infinity,
              child: (space.imageLink != null && space.imageLink!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: getFullUrl(space.imageLink!),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => ColoredBox(
                        color: Colors.black.withValues(alpha: 0.3),
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

            // ── Info ───────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date / time / seats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MiniInfoChip(
                          icon: TotemIcons.calendar,
                          label: formatShortDate(session.start),
                        ),
                        _MiniInfoChip(
                          icon: TotemIcons.clockCircle,
                          label: formatTimeOnly(session.start),
                          suffix: formatTimePeriod(session.start),
                        ),
                        _MiniInfoChip(
                          icon: TotemIcons.seats,
                          label: '${session.seatsLeft}',
                          suffix: ' seats',
                        ),
                      ],
                    ),

                    // Space category
                    if (space.shortDescription.trim().isNotEmpty)
                      Text(
                        space.shortDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.slate.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // Session title
                    Text(
                      session.title ?? '',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.slate,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Author + Attend button
                    Row(
                      children: [
                        UserAvatar.fromUserSchema(space.author, radius: 14),
                        const SizedBox(width: 4),
                        Text(
                          'with ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            space.author.name ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppTheme.slate,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => context.push(
                            RouteNames.spaceSession(space.slug, session.slug),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.mauve,
                            side: const BorderSide(color: AppTheme.mauve),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  const _MiniInfoChip({
    required this.icon,
    required this.label,
    this.suffix,
  });

  final String icon;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        TotemIcon(icon, size: 10, color: AppTheme.slate),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate,
                ),
              ),
              if (suffix != null)
                TextSpan(
                  text: suffix,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.gray,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// About Space Sheet (full content)
// ─────────────────────────────────────────────────────────────

class AboutSpaceSheet extends StatelessWidget {
  const AboutSpaceSheet({required this.space, super.key});

  final MobileSpaceDetailSchema space;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              automaticallyImplyLeading: true,
              leading: CloseButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
              centerTitle: false,
              toolbarHeight: 72,
              titleSpacing: 0,
              title: Text('About', style: theme.textTheme.titleLarge),
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
                  SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            CompactInfoText(
                              const TotemIcon(TotemIcons.subscribers),
                              Text('${space.subscribers} subscribers'),
                            ),
                            CompactInfoText(
                              const TotemIcon(TotemIcons.priceTag),
                              Text(
                                space.price == 0
                                    ? 'No cost'
                                    : NumberFormat.currency(
                                        locale: 'en_US',
                                        symbol: r'USD $',
                                      ).format(space.price),
                              ),
                            ),
                            if (space.recurring != null &&
                                space.recurring!.isNotEmpty)
                              CompactInfoText(
                                const TotemIcon(TotemIcons.recurring),
                                Text(space.recurring!.uppercaseFirst()),
                              ),
                          ],
                        ),
                        Html(
                          data: space.content,
                          style: {...AppTheme.compactHtmlStyle},
                          extensions: [TotemImageHtmlExtension()],
                          shrinkWrap: true,
                          onLinkTap: (url, _, _) =>
                              _handleHtmlLinkTap(url, context),
                          onAnchorTap: (url, _, _) =>
                              _handleHtmlLinkTap(url, context),
                        ),
                      ],
                    ),
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

// ─────────────────────────────────────────────────────────────
// Attending confirmation dialog
// ─────────────────────────────────────────────────────────────

class AttendingDialog extends StatefulWidget {
  const AttendingDialog({
    required this.onAddToCalendar,
    required this.eventSlug,
    super.key,
  });

  final String eventSlug;
  final VoidCallback onAddToCalendar;

  @override
  State<AttendingDialog> createState() => _AttendingDialogState();
}

class _AttendingDialogState extends State<AttendingDialog> {
  var _addedToCalendar = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 14,
          vertical: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Row(
              children: [
                Builder(
                  builder: (context) {
                    return Container(
                      height: 30,
                      width: 30,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: IconButton(
                        padding: EdgeInsetsDirectional.zero,
                        iconSize: 18,
                        color: AppTheme.gray,
                        onPressed: () async {
                          final box = context.findRenderObject() as RenderBox?;
                          await SharePlus.instance.share(
                            ShareParams(
                              uri: Uri.parse(AppConfig.mobileApiUrl)
                                  .resolve(
                                    '/spaces/event/${widget.eventSlug}',
                                  )
                                  .resolve('?utm_source=app&utm_medium=share'),
                              sharePositionOrigin: box != null
                                  ? box.localToGlobal(Offset.zero) & box.size
                                  : null,
                            ),
                          );
                        },
                        icon: Icon(Icons.adaptive.share),
                      ),
                    );
                  },
                ),
                const Spacer(),
                Container(
                  height: 30,
                  width: 30,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: IconButton(
                    padding: EdgeInsetsDirectional.zero,
                    iconSize: 18,
                    color: AppTheme.gray,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
            const TotemIcon(
              TotemIcons.greenCheckbox,
              size: 95,
              color: Color(0xFF98BD44),
            ),
            Text(
              "You're going!",
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const Text.rich(
              TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text:
                        "We'll send you a notification before the session "
                        'starts.',
                  ),
                  TextSpan(text: '\n\n'),
                  TextSpan(
                    text:
                        'When you join, you\u2019ll be in a Space where we take '
                        'turns speaking while holding the virtual Totem \u2014 '
                        'feel free to share when it\u2019s your turn, or simply '
                        'listen if you prefer.',
                  ),
                  TextSpan(text: '\n\n'),
                  TextSpan(
                    text: 'Totem is better with friends!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        " Share this link with your friends and they'll be "
                        'able to join as well.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              onPressed: () {
                if (!_addedToCalendar) {
                  widget.onAddToCalendar();
                  setState(() => _addedToCalendar = true);
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Text(_addedToCalendar ? 'Added!' : 'Add to Calendar'),
            ),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'In the meantime, review our '),
                  TextSpan(
                    text: 'Community Guidelines',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                        AppConfig.communityGuidelinesUrl,
                        mode: LaunchMode.externalApplication,
                      ),
                  ),
                  const TextSpan(
                    text: ' to learn more about how to participate.',
                  ),
                ],
              ),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

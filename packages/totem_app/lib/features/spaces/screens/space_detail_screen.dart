import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:totem_app/features/spaces/widgets/attending_dialog.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/core/services/analytics_service.dart';
import 'package:totem_core/features/keeper/screens/meet_user_card.dart';
import 'package:totem_core/shared/date.dart';
import 'package:totem_core/shared/extensions.dart';
import 'package:totem_core/shared/html.dart';
import 'package:totem_core/shared/logger.dart';
import 'package:totem_core/shared/network.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/routing.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/utils.dart';
import 'package:totem_core/shared/widgets/circle_icon_button.dart';
import 'package:totem_core/shared/widgets/confirmation_dialog.dart';
import 'package:totem_core/shared/widgets/error_screen.dart';
import 'package:totem_core/shared/widgets/loading_indicator.dart';
import 'package:totem_core/shared/widgets/notifications.dart';
import 'package:totem_core/shared/widgets/totem_image.dart';
import 'package:totem_core/shared/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/conflicting_sessions_dialog.dart';
import '../widgets/info_text.dart';
import '../widgets/keeper_message_participants_card.dart';

enum SpaceJoinCardState {
  ended,
  cancelled,
  closed,
  joinable,
  full,
  attending,
  notJoined,
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
  String? _selectedSessionSlug;

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
    final String? effectiveSessionSlug =
        _selectedSessionSlug ??
        widget.sessionSlug ??
        spaceAsync.maybeWhen(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          data: (space) => space.nextEvents.firstOrNull?.slug,
          orElse: () => null,
        );

    // Only watch session provider if we have a valid slug
    final bool hasValidSessionSlug =
        effectiveSessionSlug != null && effectiveSessionSlug.isNotEmpty;

    final AsyncValue<SessionDetailSchema>? sessionAsync = hasValidSessionSlug
        ? ref.watch(sessionProvider(effectiveSessionSlug))
        : null;

    final currentUserSlug = ref.watch(
      authControllerProvider.select((auth) => auth.user?.slug),
    );

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
                        sessionAsync?.maybeWhen(
                          data: (session) => session.title,
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
                          background: SizedBox.expand(
                            child: TotemImage(
                              imageUrl: space.imageLink,
                              loadingPlaceholder: ColoredBox(
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        leading: CircleIconButton(
                          margin: const EdgeInsetsDirectional.only(start: 20),
                          icon: TotemIcons.arrowBack,
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          onPressed: () =>
                              TotemRouter.instance.popOrHome(context),
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
                                      uri: Uri.parse(AppConfig.instance.apiUrl)
                                          .resolve(
                                            '/spaces/event/${space.slug}',
                                          )
                                          .resolve(
                                            '?utm_source=app'
                                            '&utm_medium=share',
                                          ),
                                      sharePositionOrigin: box != null
                                          ? box.localToGlobal(Offset.zero) &
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
                        if (hasValidSessionSlug)
                          ref.refresh(
                            sessionProvider(effectiveSessionSlug).future,
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
                                if (sessionAsync != null &&
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
                                  sessionAsync?.maybeWhen(
                                        data: (session) => session.title,
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
                              sessionAsync: sessionAsync,
                            ),
                          ),

                          // ── Message Participants (keeper only) ─────────
                          // Staging-only until the messaging backend ships.
                          if (AppConfig.instance.environment ==
                                  Environment.staging &&
                              currentUserSlug != null &&
                              space.author.slug == currentUserSlug)
                            if (sessionAsync?.value
                                case final SessionDetailSchema event) ...[
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: 20,
                                ),
                                child: KeeperMessageParticipantsCard(
                                  session: event,
                                ),
                              ),
                            ],

                          const SizedBox(height: 24),

                          // ── About this Session ─────────────────────────
                          if (sessionAsync != null)
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
                                  sessionAsync.when(
                                    data: (session) => Html(
                                      data: session.content,
                                      shrinkWrap: true,
                                      style: {
                                        ...AppTheme.compactHtmlStyle,
                                        'body': Style(margin: Margins.zero),
                                      },
                                      extensions: [TotemImageHtmlExtension()],
                                      onLinkTap: (url, _, _) =>
                                          RoutingUtils.handleLinkTap(
                                            context,
                                            url,
                                          ),
                                      onAnchorTap: (url, _, _) =>
                                          RoutingUtils.handleLinkTap(
                                            context,
                                            url,
                                          ),
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
                            currentSessionSlug: effectiveSessionSlug,
                            onRefresh: () {
                              if (!mounted) return;
                              ref.invalidate(spacesSummaryProvider);
                              ref.invalidate(spaceProvider(widget.slug));
                              if (effectiveSessionSlug != null) {
                                ref.invalidate(
                                  sessionProvider(effectiveSessionSlug),
                                );
                              }
                            },
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
                                MeetKeeperCard(
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
// Session info card — state-aware attend button
// ─────────────────────────────────────────────────────────────

class _SessionInfoCard extends ConsumerStatefulWidget {
  const _SessionInfoCard({required this.space, required this.sessionAsync});

  final MobileSpaceDetailSchema space;
  final AsyncValue<SessionDetailSchema>? sessionAsync;

  @override
  ConsumerState<_SessionInfoCard> createState() => _SessionInfoCardState();
}

class _SessionInfoCardState extends ConsumerState<_SessionInfoCard> {
  MobileSpaceDetailSchema get space => widget.space;
  final _notificationController = NotificationController();

  bool _attending = false;
  bool _loading = false;
  bool _joined = false;
  String? _syncedSessionSlug;
  bool? _syncedAttending;
  DateTime? _syncedStart;
  String _currentTimeago = '';
  Timer? _timer;

  void _syncFromSession(SessionDetailSchema session) {
    final sessionChanged = _syncedSessionSlug != session.slug;
    final attendanceChanged = _syncedAttending != session.attending;
    final startChanged = _syncedStart != session.start;
    if (!sessionChanged && !attendanceChanged && !startChanged) return;

    _syncedSessionSlug = session.slug;
    _syncedAttending = session.attending;
    _syncedStart = session.start;
    _attending = session.attending;
    if (sessionChanged) _joined = false;

    if (!sessionChanged && !startChanged) return;
    _currentTimeago = timeago.format(session.start, allowFromNow: true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = timeago.format(session.start, allowFromNow: true);
      if (_currentTimeago != next) setState(() => _currentTimeago = next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  SpaceJoinCardState _computeState(
    SessionDetailSchema session,
    UserSchema? user,
  ) {
    final ended =
        session.ended ||
        session.start
            .add(Duration(minutes: session.duration))
            .isBefore(DateTime.now());
    return switch (session) {
      _ when session.cancelled => SpaceJoinCardState.cancelled,
      _ when ended => SpaceJoinCardState.ended,
      _ when _joined || (session.canJoinNow(user) && session.joinable) =>
        SpaceJoinCardState.joinable,
      _ when _attending => SpaceJoinCardState.attending,
      _ when session.seatsLeft <= 0 => SpaceJoinCardState.full,
      _ when !session.open => SpaceJoinCardState.closed,
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

    widget.sessionAsync?.whenData(_syncFromSession);

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
              if (widget.sessionAsync != null)
                ...widget.sessionAsync!.maybeWhen(
                  data: (session) => [
                    CompactInfoText(
                      const TotemIcon(TotemIcons.clockCircle),
                      Text('${session.duration} min'),
                    ),
                    CompactInfoText(
                      const TotemIcon(TotemIcons.seats),
                      SeatsLeftText(seatsLeft: session.seatsLeft),
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
          if (widget.sessionAsync != null) ...[
            const SizedBox(height: 17),
            widget.sessionAsync!.when(
              data: (session) {
                final state = _computeState(session, user);
                return _DateAttendRow(
                  session: session,
                  state: state,
                  currentTimeago: _currentTimeago,
                  loading: _loading,
                  onAttend: () => _attend(session),
                  onGiveUpSpot: () => _giveUpSpot(session),
                  onAddToCalendar: () => addSessionToCalendar(context, session),
                  onJoinLivekit: () => _joinLivekit(session),
                  onJoinGoogleMeet: () => _joinGoogleMeet(session),
                  onExplore: () =>
                      TotemRouter.instance.toHome(HomeRoutes.spaces),
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

  Future<void> _attend(SessionDetailSchema session) async {
    if (_attending || _loading || !mounted) {
      return;
    }
    setState(() => _loading = true);
    try {
      final attending = await ref.read(
        rsvpConfirmProvider(session.slug).future,
      );
      if (attending) {
        await _onAttendSuccess(session);
      } else {
        if (mounted) {
          _notificationController.showError(
            context,
            icon: TotemIcons.spaces,
            title: 'Failed to attend this circle',
            message: 'Please try again later',
          );
        }
      }
    } on RsvpConflictException catch (error) {
      if (!mounted) return;
      final switched = await showConflictingSessionsDialog(
        context,
        error.conflict,
        session,
        () => _switchSession(session, error.conflict),
      );
      if (switched == true) {
        await _onAttendSuccess(session);
      }
    } catch (_) {
      if (mounted) {
        _notificationController.showError(
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

  Future<bool> _switchSession(
    SessionDetailSchema newSession,
    SessionConflictSchema conflict,
  ) async {
    final attending = await ref.read(
      rsvpForceConfirmProvider(
        newSession.slug,
        conflict.conflictingSessions.map((e) => e.slug).toList(),
      ).future,
    );
    _refresh(newSession);
    if (!attending && mounted) {
      _notificationController.showError(
        context,
        icon: TotemIcons.spaces,
        title: 'Failed to switch sessions',
        message: 'Please try again later',
      );
    }
    return attending;
  }

  Future<void> _onAttendSuccess(SessionDetailSchema session) async {
    if (!mounted) return;
    setState(() => _attending = true);
    await showAttendingDialog(context, session);
    await _refresh(session);
  }

  Future<void> _giveUpSpot(SessionDetailSchema session) async {
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
      final attending = await ref.read(rsvpCancelProvider(session.slug).future);
      if (mounted) setState(() => _loading = false);

      if (!attending) {
        if (mounted) setState(() => _attending = false);

        if (mounted) {
          _notificationController.showError(
            context,
            icon: TotemIcons.seats,
            title: 'You gave up your spot',
            message: 'You can always attend again if a spot opens up.',
          );
        }
        await _refresh(session);
      } else {
        if (mounted) {
          _notificationController.showError(
            context,
            icon: TotemIcons.seats,
            title: 'Failed to give up your spot',
            message: 'Please try again later',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _notificationController.showError(
          context,
          icon: TotemIcons.seats,
          title: 'Failed to give up your spot',
          message: 'Please try again later',
        );
      }
    }
  }

  void _joinLivekit(SessionDetailSchema session) {
    logger.d('Joining livekit session: ${session.slug}');
    if (mounted) setState(() => _joined = true);
    context.go(RouteNames.session(session.slug));
  }

  Future<void> _joinGoogleMeet(SessionDetailSchema session) async {
    setState(() => _joined = true);
    await launchUrl(
      Uri.parse(getFullUrl(session.calLink)),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _refresh(SessionDetailSchema session) async {
    if (!mounted) return;
    ref.invalidate(spacesSummaryProvider);
    // ignore: unused_result
    await ref.refresh(sessionProvider(session.slug).future);
    if (!mounted) return;
    // ignore: unused_result
    await ref.refresh(spaceProvider(space.slug).future);
  }
}

// ─────────────────────────────────────────────────────────────
// Date + attend button row (pure display)
// ─────────────────────────────────────────────────────────────

class _DateAttendRow extends StatelessWidget {
  const _DateAttendRow({
    required this.session,
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

  final SessionDetailSchema session;
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
      SpaceJoinCardState.notJoined => formatSessionDate(session.start),
    };
    final timeLabel = switch (state) {
      SpaceJoinCardState.attending || SpaceJoinCardState.notJoined =>
        formatSessionTime(session.start, session.userTimezone),
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
        session.meetingProvider == MeetingProviderEnum.livekit
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
    required this.onRefresh,
    required this.currentSessionSlug,
  });

  final MobileSpaceDetailSchema space;
  final String? currentSessionSlug;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcomingSessions = space.nextEvents
        .where((e) => e.slug != currentSessionSlug)
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
              onRefresh: onRefresh,
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
    required this.onRefresh,
  });

  final MobileSpaceDetailSchema space;
  final NextSessionSchema session;
  final VoidCallback onRefresh;

  Future<void> _openSession(BuildContext context) async {
    await context.push(RouteNames.spaceSession(space.slug, session.slug));
    if (context.mounted) onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _openSession(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Image ──────────────────────────────────────────
              SizedBox(
                height: double.infinity,
                width: 130,
                child: TotemImage(
                  imageUrl: space.imageLink,
                  loadingPlaceholder: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
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
                            onPressed: () => _openSession(context),
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
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  const _MiniInfoChip({required this.icon, required this.label, this.suffix});

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
                  style: const TextStyle(fontSize: 10, color: AppTheme.gray),
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
                              RoutingUtils.handleLinkTap(context, url),
                          onAnchorTap: (url, _, _) =>
                              RoutingUtils.handleLinkTap(context, url),
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

import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/shared/extensions.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/circle_icon_button.dart';
import 'package:totem_core/shared/widgets/confetti.dart';
import 'package:totem_core/shared/widgets/space_card.dart';
import 'package:totem_core/shared/widgets/user_feedback.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';
import 'package:url_launcher/url_launcher.dart';

// TODO(totem): This should live at the state resolver
/// Resolves the [SessionDisconnectedReason] from the given
/// [disconnectReason] and [sessionState].
@visibleForTesting
SessionDisconnectedReason resolveDisconnectedReason({
  DisconnectReason? disconnectReason,
  SessionRoomState? sessionState,
}) {
  if (disconnectReason == DisconnectReason.duplicateIdentity) {
    return SessionDisconnectedReason.movedToAnotherDevice;
  }

  if (sessionState?.removed ?? false) {
    final removeReason = sessionState?.participants.removeReason;
    switch (removeReason) {
      case RemoveReason.ban:
        return SessionDisconnectedReason.banned;
      case RemoveReason.remove:
      default:
        return SessionDisconnectedReason.removed;
    }
  }

  if (sessionState?.roomState.status == RoomStatus.ended &&
      sessionState?.roomState.statusDetail is RoomStateStatusDetailEnded) {
    final detail =
        sessionState!.roomState.statusDetail as RoomStateStatusDetailEnded;
    return switch (detail.endedDetail.reason) {
      EndReason.keeperAbsent => SessionDisconnectedReason.keeperAbsent,
      EndReason.roomEmpty => SessionDisconnectedReason.roomEmpty,
      EndReason.keeperEnded || _ => SessionDisconnectedReason.keeperEnded,
    };
  }

  return SessionDisconnectedReason.keeperEnded;
}

class SessionDisconnectedScreen extends ConsumerStatefulWidget {
  const SessionDisconnectedScreen({
    this.session,
    this.disconnectReason,
    this.sessionDisconnectedReason,
    super.key,
  });

  final SessionDetailSchema? session;
  final DisconnectReason? disconnectReason;
  final SessionDisconnectedReason? sessionDisconnectedReason;

  @override
  ConsumerState<SessionDisconnectedScreen> createState() =>
      _SessionDisconnectedScreenState();

  @visibleForTesting
  static const reviewRequestedKey = 'session_review_requested';
  @visibleForTesting
  static const sessionLikedCountKey = 'session_liked_count';

  /// Displays the in-app review prompt after the user has liked 5 sessions
  @visibleForTesting
  static Future<void> incrementSessionLikedCount({
    SharedPreferences? prefs,
    InAppReview? inAppReview,
  }) async {
    try {
      final effectivePrefs = prefs ?? await SharedPreferences.getInstance();
      final effectiveInAppReview = inAppReview ?? InAppReview.instance;

      final alreadyRequested =
          effectivePrefs.getBool(
            SessionDisconnectedScreen.reviewRequestedKey,
          ) ??
          false;
      if (alreadyRequested) return;

      final count =
          (effectivePrefs.getInt(
                SessionDisconnectedScreen.sessionLikedCountKey,
              ) ??
              0) +
          1;
      await effectivePrefs.setInt(
        SessionDisconnectedScreen.sessionLikedCountKey,
        count,
      );
      if (count >= 5) {
        if (await effectiveInAppReview.isAvailable()) {
          await effectiveInAppReview.requestReview();
          await effectivePrefs.setBool(
            SessionDisconnectedScreen.reviewRequestedKey,
            true,
          );
        }
      }
    } catch (_) {
      // Fine if fail
    }
  }
}

class _SessionDisconnectedScreenState
    extends ConsumerState<SessionDisconnectedScreen> {
  Timer? _confettiTimer;
  Timer? _spacesSummaryRefreshTimer;

  @override
  void initState() {
    super.initState();
    _shutDownCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.context.mounted) ref.invalidate(spacesSummaryProvider);
    });
    _spacesSummaryRefreshTimer = Timer(const Duration(milliseconds: 2750), () {
      if (mounted) ref.invalidate(spacesSummaryProvider);
    });
  }

  void _shutDownCamera() {
    final session = ref.read(currentSessionProvider);
    session?.room?.localParticipant?.setCameraEnabled(false);
    session?.room?.localParticipant?.setMicrophoneEnabled(false);
  }

  @override
  void dispose() {
    _confettiTimer?.cancel();
    _spacesSummaryRefreshTimer?.cancel();
    super.dispose();
  }

  void _refreshHome() {
    ref.invalidate(spacesSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final sessionReason =
        widget.sessionDisconnectedReason ??
        ref.watch(
          currentSessionStateProvider.select(
            (sessionState) => resolveDisconnectedReason(
              disconnectReason:
                  widget.disconnectReason ?? sessionState?.disconnectReason,
              sessionState: sessionState,
            ),
          ),
        )!;

    final isBanned = sessionReason == SessionDisconnectedReason.banned;

    return PopScope(
      canPop: false,
      child: SafeArea(
        child: ViewportResolver(
          builder: (context, viewportKind) {
            return switch (viewportKind) {
              ViewportKind.smallPortrait => _PortraitLayout(
                session: widget.session,
                reason: sessionReason,
                isBanned: isBanned,
                onRefreshHome: _refreshHome,
              ),
              ViewportKind.smallLandscape => _LandscapeLayout(
                session: widget.session,
                reason: sessionReason,
                isBanned: isBanned,
                onRefreshHome: _refreshHome,
              ),
              ViewportKind.mediumSmall => _MediumSmallLayout(
                session: widget.session,
                reason: sessionReason,
                isBanned: isBanned,
                onRefreshHome: _refreshHome,
              ),
              ViewportKind.mediumPlus => _MediumPlusLayout(
                session: widget.session,
                reason: sessionReason,
                isBanned: isBanned,
                onRefreshHome: _refreshHome,
              ),
            };
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LAYOUTS
// -----------------------------------------------------------------------------

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({
    required this.session,
    required this.reason,
    required this.isBanned,
    required this.onRefreshHome,
  });

  final SessionDetailSchema? session;
  final SessionDisconnectedReason reason;
  final bool isBanned;
  final VoidCallback onRefreshHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            _SessionHeader(reason: reason),
            _SessionSubheader(reason: reason),
            if (session != null &&
                reason == SessionDisconnectedReason.keeperEnded)
              _InteractiveFeedbackWidget(session: session!),
            if (!isBanned)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 254),
                  child: _NextSessionsSection(
                    session: session,
                    isBanned: isBanned,
                    onRefreshHome: onRefreshHome,
                  ),
                ),
              ),
            _ActionButtons(onRefreshHome: onRefreshHome),
          ],
        ),
      ),
    );
  }
}

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({
    required this.session,
    required this.reason,
    required this.isBanned,
    required this.onRefreshHome,
  });
  final SessionDetailSchema? session;
  final SessionDisconnectedReason reason;
  final bool isBanned;
  final VoidCallback onRefreshHome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.all(40.0),
      child: Row(
        spacing: 20,
        children: [
          Expanded(
            child: Column(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SessionHeader(reason: reason),
                _SessionSubheader(reason: reason),
                if (session != null &&
                    reason == SessionDisconnectedReason.keeperEnded)
                  _InteractiveFeedbackWidget(session: session!),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              if (!isBanned)
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: _NextSessionsSection(
                      session: session,
                      isBanned: isBanned,
                      onRefreshHome: onRefreshHome,
                    ),
                  ),
                ),
              _ActionButtons(onRefreshHome: onRefreshHome),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediumSmallLayout extends StatelessWidget {
  const _MediumSmallLayout({
    required this.session,
    required this.reason,
    required this.isBanned,
    required this.onRefreshHome,
  });

  final SessionDetailSchema? session;
  final SessionDisconnectedReason reason;
  final bool isBanned;
  final VoidCallback onRefreshHome;

  Widget _wrapConstrained(Widget child) {
    return FractionallySizedBox(widthFactor: 0.75, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16.0,
              vertical: 56,
            ),
            child: FractionallySizedBox(
              widthFactor: 0.75,
              child: Column(
                spacing: 30,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _wrapConstrained(_MediumStatusIcon(reason: reason)),
                  _wrapConstrained(_SessionHeader(reason: reason)),
                  _wrapConstrained(_SessionSubheader(reason: reason)),
                  const Divider(color: Color(0x0FFFFFFF)),
                  ?switch (reason) {
                    SessionDisconnectedReason.keeperEnded => _wrapConstrained(
                      _InteractiveFeedbackWidget(session: session!),
                    ),
                    _ => null,
                  },
                  if (!isBanned)
                    Flexible(
                      child: _wrapConstrained(
                        _NextSessionsSection(
                          session: session,
                          isBanned: isBanned,
                          onRefreshHome: onRefreshHome,
                        ),
                      ),
                    ),
                  _ActionButtons(onRefreshHome: onRefreshHome),
                ],
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 48,
          start: 48,
          child: CircleIconButton(
            icon: TotemIcons.close,
            onPressed: onRefreshHome,
            color: AppTheme.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _MediumPlusLayout extends StatelessWidget {
  const _MediumPlusLayout({
    required this.session,
    required this.reason,
    required this.isBanned,
    required this.onRefreshHome,
  });
  final SessionDetailSchema? session;
  final SessionDisconnectedReason reason;
  final bool isBanned;
  final VoidCallback onRefreshHome;

  Widget _wrapConstrained(Widget child) {
    return FractionallySizedBox(widthFactor: 0.75, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 10,
      children: [
        Expanded(
          child: FractionallySizedBox(
            widthFactor: 0.75,
            child: Column(
              spacing: 30,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _wrapConstrained(_MediumStatusIcon(reason: reason)),
                _wrapConstrained(_SessionHeader(reason: reason)),
                _wrapConstrained(_SessionSubheader(reason: reason)),
                const Divider(color: Color(0x0FFFFFFF)),
                if (session != null &&
                    reason == SessionDisconnectedReason.keeperEnded)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _InteractiveFeedbackWidget(session: session!),
                  ),
                if (!isBanned)
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 500,
                        maxHeight: 362,
                      ),
                      child: _NextSessionsSection(
                        session: session,
                        isBanned: isBanned,
                        onRefreshHome: onRefreshHome,
                      ),
                    ),
                  ),
                _ActionButtons(onRefreshHome: onRefreshHome),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// COMPONENTS
// -----------------------------------------------------------------------------

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.reason});

  final SessionDisconnectedReason reason;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        switch (reason) {
          SessionDisconnectedReason.keeperAbsent =>
            'Session will be rescheduled',
          SessionDisconnectedReason.movedToAnotherDevice =>
            'Session moved to another device',
          SessionDisconnectedReason.removed =>
            "You've been removed from this session.",
          SessionDisconnectedReason.roomEmpty ||
          SessionDisconnectedReason.keeperEnded => 'Session Ended',
          SessionDisconnectedReason.banned => "You've Been Banned",
          SessionDisconnectedReason.other => 'Disconnected',
        },
        style: Theme.of(context).textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SessionSubheader extends StatefulWidget {
  const _SessionSubheader({required this.reason});
  final SessionDisconnectedReason reason;

  @override
  State<_SessionSubheader> createState() => _SessionSubheaderState();
}

class _SessionSubheaderState extends State<_SessionSubheader> {
  late final TapGestureRecognizer _communityGuidelinesRecognizer;
  late final TapGestureRecognizer _helpEmailRecognizer;

  @override
  void initState() {
    super.initState();
    _communityGuidelinesRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        final url = AppConfig.instance.communityGuidelinesUrl;
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      };
    _helpEmailRecognizer = TapGestureRecognizer()
      ..onTap = () {
        launchUrl(Uri.parse('mailto:help@totem.org'));
      };
  }

  @override
  void dispose() {
    _communityGuidelinesRecognizer.dispose();
    _helpEmailRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(color: Colors.blue.shade200);
    final removedSpan = TextSpan(
      text: 'Please take a moment to review our ',
      children: [
        // TODO(totem): Use LinkSpan when available https://github.com/flutter/flutter/issues/91600
        TextSpan(
          text: 'Community Guidelines',
          style: linkStyle,
          recognizer: _communityGuidelinesRecognizer,
        ),
        const TextSpan(text: '. '),
        const TextSpan(
          text: 'If you believe this was a mistake, reach out to us at ',
        ),
        TextSpan(
          text: 'help@totem.org',
          style: linkStyle,
          recognizer: _helpEmailRecognizer,
        ),
        const TextSpan(text: '.'),
      ],
    );
    return Text.rich(switch (widget.reason) {
      SessionDisconnectedReason.keeperAbsent => const TextSpan(
        text:
            'The session ended due to technical difficulties and couldn’t continue. We’ll notify you when it’s rescheduled.',
      ),
      SessionDisconnectedReason.movedToAnotherDevice => const TextSpan(
        text:
            'This account joined the same session on another device. Continue there or rejoin from this device.',
      ),
      SessionDisconnectedReason.removed => removedSpan,
      SessionDisconnectedReason.keeperEnded ||
      SessionDisconnectedReason.roomEmpty => const TextSpan(
        text:
            'Thank you for joining!\nWe hope you found the session enjoyable.',
      ),
      SessionDisconnectedReason.banned => TextSpan(
        text:
            'You have been removed from this session due to a violation of our community guidelines.',
        children: [
          const TextSpan(text: '\n'),
          removedSpan,
        ],
      ),
      SessionDisconnectedReason.other => const TextSpan(text: ''),
    }, textAlign: TextAlign.center);
  }
}

class _InteractiveFeedbackWidget extends ConsumerStatefulWidget {
  const _InteractiveFeedbackWidget({required this.session});
  final SessionDetailSchema session;

  @override
  ConsumerState<_InteractiveFeedbackWidget> createState() =>
      _InteractiveFeedbackWidgetState();
}

class _InteractiveFeedbackWidgetState
    extends ConsumerState<_InteractiveFeedbackWidget> {
  ThumbState _thumbState = ThumbState.none;

  @override
  Widget build(BuildContext context) {
    return _SessionFeedbackWidget(
      state: _thumbState,
      onThumbUpPressed: () async {
        setState(() => _thumbState = ThumbState.up);
        ConfettiController.showConfetti(context);
        await ref.read(
          sessionFeedbackProvider(
            widget.session.slug,
            SessionFeedbackOptions.up,
          ).future,
        );
        await SessionDisconnectedScreen.incrementSessionLikedCount();
      },
      onThumbDownPressed: () async {
        await showUserFeedbackPopup(
          context,
          onFeedbackSubmitted: (message) {
            _thumbState = ThumbState.down;
            if (mounted) setState(() {});
            return ref.read(
              sessionFeedbackProvider(
                widget.session.slug,
                SessionFeedbackOptions.down,
                message,
              ).future,
            );
          },
        );
      },
    );
  }
}

class _NextSessionsSection extends ConsumerWidget {
  const _NextSessionsSection({
    required this.session,
    required this.isBanned,
    required this.onRefreshHome,
  });

  final SessionDetailSchema? session;
  final bool isBanned;
  final VoidCallback onRefreshHome;

  static const int count = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isBanned) return const SizedBox.shrink();

    final effectiveSession = session;
    final nextSessions =
        effectiveSession?.space.nextEvents
            .where((e) => e.slug != effectiveSession.slug)
            .take(count)
            .toList() ??
        const [];

    final recommendedSessions = ref.watch(
      getRecommendedSessionsProvider(limit: count),
    );

    String? titleText;
    Widget? card;

    if (nextSessions.isNotEmpty && effectiveSession != null) {
      titleText = 'Sign up for the next session';
      card = nextSessions.take(1).map((nextSession) {
        return SpaceCard(
          space: MobileSpaceDetailSchemaExtension.copyWith(
            effectiveSession.space,
            nextEvents: [nextSession],
          ),
          aspectRatio: null,
          onTap: () {
            onRefreshHome();
            TotemRouter.instance.toSpaceSession(
              context,
              effectiveSession.space.slug,
              nextSession.slug,
              true,
            );
          },
        );
      }).firstOrNull;
    } else if (recommendedSessions.hasValue &&
        recommendedSessions.value!.isNotEmpty) {
      titleText = 'You may enjoy this space';
      card = recommendedSessions.value!.take(count).map((recommendedSession) {
        return SpaceCard.fromSessionDetailSchema(
          recommendedSession,
          aspectRatio: null,
          onTap: () async {
            onRefreshHome();
            TotemRouter.instance.toSpaceSession(
              context,
              recommendedSession.space.slug,
              recommendedSession.slug,
              true,
            );
          },
        );
      }).firstOrNull;
    }

    if (card == null || titleText == null) return const SizedBox.shrink();

    final header = Text(
      titleText,
      style: Theme.of(context).textTheme.titleMedium,
      textAlign: TextAlign.start,
    );

    return Column(
      spacing: 20,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        Flexible(child: card),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onRefreshHome});

  final VoidCallback onRefreshHome;

  void onSeeAllSessions() {
    onRefreshHome();
    TotemRouter.instance.toHome();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        foregroundColor: Colors.white,
      ),
      onPressed: onSeeAllSessions,
      child: const Text(
        'See all upcoming sessions',
        style: TextStyle(fontFeatures: []),
      ),
    );
  }
}

class _MediumStatusIcon extends StatelessWidget {
  const _MediumStatusIcon({required this.reason});
  final SessionDisconnectedReason reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      width: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (reason) {
          SessionDisconnectedReason.movedToAnotherDevice => AppTheme.mauve,
          SessionDisconnectedReason.keeperEnded => AppTheme.paleGreen,
          SessionDisconnectedReason.keeperAbsent => AppTheme.mauve,
          SessionDisconnectedReason.roomEmpty => AppTheme.mauve,
          SessionDisconnectedReason.removed ||
          SessionDisconnectedReason.banned ||
          SessionDisconnectedReason.other => Colors.red,
        },
      ),
      alignment: AlignmentDirectional.center,
      child: TotemIcon(
        switch (reason) {
          SessionDisconnectedReason.movedToAnotherDevice => TotemIcons.info,
          SessionDisconnectedReason.keeperEnded => TotemIcons.checkmark,
          SessionDisconnectedReason.keeperAbsent => TotemIcons.clockCircle,
          SessionDisconnectedReason.roomEmpty => TotemIcons.seats,
          SessionDisconnectedReason.banned => TotemIcons.banned,
          SessionDisconnectedReason.removed ||
          SessionDisconnectedReason.other => TotemIcons.x,
        },
        color: AppTheme.white,
        size: 38,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// EXISTING WIDGETS
// -----------------------------------------------------------------------------

enum ThumbState { up, down, none }

class _SessionFeedbackWidget extends StatelessWidget {
  const _SessionFeedbackWidget({
    required this.state,
    required this.onThumbUpPressed,
    required this.onThumbDownPressed,
  });

  final ThumbState state;
  final VoidCallback onThumbUpPressed;
  final VoidCallback onThumbDownPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppTheme.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: AutoSizeText(
                switch (state) {
                  ThumbState.none => 'How was your experience?',
                  ThumbState.up => 'Thank you! Glad you enjoyed it.',
                  ThumbState.down => 'Thank you for your feedback!',
                },
                textAlign: TextAlign.start,
                maxLines: 2,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [
                _SessionFeedbackButton(
                  selected: state == ThumbState.up,
                  icon: const TotemIcon(TotemIcons.thumbUp),
                  onPressed: state == ThumbState.none ? onThumbUpPressed : null,
                ),
                _SessionFeedbackButton(
                  selected: state == ThumbState.down,
                  icon: const TotemIcon(TotemIcons.thumbDown),
                  onPressed: state == ThumbState.none
                      ? onThumbDownPressed
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionFeedbackButton extends StatelessWidget {
  const _SessionFeedbackButton({
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsetsDirectional.all(10),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.surface : null,
          shape: BoxShape.circle,
        ),
        child: IconTheme.merge(
          data: IconThemeData(
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onInverseSurface,
          ),
          child: icon,
        ),
      ),
    );
  }
}

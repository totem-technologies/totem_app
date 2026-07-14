import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/shared/extensions.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/confetti.dart';
import 'package:totem_core/shared/widgets/space_card.dart';
import 'package:totem_core/shared/widgets/totem_icon.dart';
import 'package:totem_core/shared/widgets/user_feedback.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _shutDownCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.context.mounted) ref.invalidate(spacesSummaryProvider);
    });
    Future.delayed(const Duration(milliseconds: 2750), () {
      if (ref.context.mounted) ref.invalidate(spacesSummaryProvider);
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
    super.dispose();
  }

  void _refreshHome() {
    ref.invalidate(spacesSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(currentSessionStateProvider);
    final disconnectReason =
        widget.disconnectReason ?? sessionState?.disconnectReason;
    final sessionReason =
        widget.sessionDisconnectedReason ??
        resolveDisconnectedReason(
          disconnectReason: disconnectReason,
          sessionState: sessionState,
        );

    final isBanned = sessionReason == SessionDisconnectedReason.banned;

    return RoomBackground(
      status: RoomStatus.ended,
      child: PopScope(
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
          vertical: 8,
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
                child: _NextSessionsSection(
                  session: session,
                  isBanned: isBanned,
                  direction: Axis.vertical,
                  onRefreshHome: onRefreshHome,
                ),
              ),
            _ActionButtons(isBanned: isBanned, onRefreshHome: onRefreshHome),
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
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 20,
              children: [
                if (!isBanned)
                  Flexible(
                    child: _NextSessionsSection(
                      session: session,
                      isBanned: isBanned,
                      direction: Axis.vertical,
                      onRefreshHome: onRefreshHome,
                    ),
                  ),
                _ActionButtons(
                  isBanned: isBanned,
                  onRefreshHome: onRefreshHome,
                ),
              ],
            ),
          ),
        ],
      ),
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
        const ListTile(
          contentPadding: EdgeInsetsDirectional.symmetric(horizontal: 40),
          leading: TotemLogo(color: Colors.white, size: 24),
          shape: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
        ),
        Expanded(
          child: FractionallySizedBox(
            widthFactor: 0.75,
            child: Column(
              spacing: 30,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _wrapConstrained(_MediumPlusStatusIcon(reason: reason)),
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
                    child: _wrapConstrained(
                      _NextSessionsSection(
                        session: session,
                        isBanned: isBanned,
                        direction: Axis.horizontal,
                        onRefreshHome: onRefreshHome,
                      ),
                    ),
                  ),
                _ActionButtons(
                  isBanned: isBanned,
                  onRefreshHome: onRefreshHome,
                ),
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
    final theme = Theme.of(context);
    final removedSpan = TextSpan(
      text: 'Please take a moment to review our ',
      children: [
        // TODO(totem): Use LinkSpan when available https://github.com/flutter/flutter/issues/91600
        TextSpan(
          text: 'Community Guidelines',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          recognizer: _communityGuidelinesRecognizer,
        ),
        const TextSpan(text: '. '),
        const TextSpan(
          text: 'If you believe this was a mistake, reach out to us at ',
        ),
        TextSpan(
          text: 'help@totem.org',
          style: TextStyle(color: Colors.blue.shade200),
          recognizer: _helpEmailRecognizer,
        ),
        const TextSpan(text: '.'),
      ],
    );
    return Text.rich(
      switch (widget.reason) {
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
      },
      textAlign: TextAlign.center,
    );
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
    required this.direction,
    required this.onRefreshHome,
  });
  final SessionDetailSchema? session;
  final bool isBanned;
  final Axis direction;
  final VoidCallback onRefreshHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isBanned) return const SizedBox.shrink();

    final nextSessions =
        session?.space.nextEvents
            .where((e) => e.slug != session?.slug)
            .take(2)
            .toList() ??
        const [];

    final recommended = ref.watch(getRecommendedSessionsProvider());

    List<Widget> cards = [];
    String? headerText;

    if (nextSessions.isNotEmpty) {
      headerText = nextSessions.length == 1
          ? 'Join this upcoming session'
          : 'Join these upcoming sessions';
      cards = nextSessions.map((nextSession) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.textScalerOf(context).scale(140),
          ),
          child: SmallSpaceCard(
            space: MobileSpaceDetailSchemaExtension.copyWith(
              session!.space,
              nextEvents: [nextSession],
            ),
            onTap: () async {
              onRefreshHome();
              return TotemRouter.instance.toSpaceSession(
                context,
                session!.space.slug,
                nextSession.slug,
                true,
              );
            },
          ),
        );
      }).toList();
    } else if (recommended.hasValue && recommended.value!.isNotEmpty) {
      headerText = 'You may enjoy these spaces';
      cards = recommended.value!.take(2).map((recSession) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.textScalerOf(context).scale(140),
          ),
          child: SmallSpaceCard.fromSessionDetailSchema(
            recSession,
            onTap: () async {
              onRefreshHome();
              return TotemRouter.instance.toSpaceSession(
                context,
                recSession.space.slug,
                recSession.slug,
                true,
              );
            },
          ),
        );
      }).toList();
    }

    if (cards.isEmpty || headerText == null) return const SizedBox.shrink();

    final header = Text(
      headerText,
      style: Theme.of(context).textTheme.titleMedium,
      textAlign: TextAlign.start,
    );

    if (direction == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 20,
        children: [
          header,
          ...cards.map((c) => Flexible(child: c)),
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 20,
        children: [
          header,
          Flexible(
            child: Row(
              spacing: 20,
              children: cards.map((c) => Expanded(child: c)).toList(),
            ),
          ),
        ],
      );
    }
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.isBanned,
    required this.onRefreshHome,
  });
  final bool isBanned;
  final VoidCallback onRefreshHome;

  @override
  Widget build(BuildContext context) {
    // if (isBanned) {
    //   return Link(
    //     uri: Uri.parse('mailto:help@totem.org'),
    //     builder: (context, followLink) => ElevatedButton(
    //       style: ElevatedButton.styleFrom(
    //         padding: const EdgeInsetsDirectional.symmetric(horizontal: 58),
    //         shape: RoundedRectangleBorder(
    //           borderRadius: BorderRadius.circular(26),
    //         ),
    //       ),
    //       onPressed: followLink,
    //       child: const Text('Contact us'),
    //     ),
    //   );
    // }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 58),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
      ),
      onPressed: () {
        onRefreshHome();
        TotemRouter.instance.toHome();
      },
      child: const Text('Explore More'),
    );
  }
}

class _MediumPlusStatusIcon extends StatelessWidget {
  const _MediumPlusStatusIcon({required this.reason});
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
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: AutoSizeText(
              switch (state) {
                ThumbState.none => 'How was your experience?',
                _ => 'Thank you for your feedback!',
              },
              textAlign: TextAlign.start,
              maxLines: 2,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              _SessionFeedbackButton(
                outlined: state == ThumbState.down,
                icon: TotemIcon(
                  state == ThumbState.up
                      ? TotemIcons.thumbUpFilled
                      : TotemIcons.thumbUp,
                ),
                onPressed: state == ThumbState.none ? onThumbUpPressed : null,
              ),
              _SessionFeedbackButton(
                outlined: state == ThumbState.up,
                icon: TotemIcon(
                  state == ThumbState.down
                      ? TotemIcons.thumbDownFilled
                      : TotemIcons.thumbDown,
                ),
                onPressed: state == ThumbState.none ? onThumbDownPressed : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionFeedbackButton extends StatelessWidget {
  const _SessionFeedbackButton({
    required this.icon,
    required this.onPressed,
    this.outlined = false,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        padding: const EdgeInsetsDirectional.all(10),
        decoration: BoxDecoration(
          color: outlined ? null : theme.colorScheme.primary,
          border: outlined
              ? Border.all(color: theme.colorScheme.primary)
              : null,
          shape: BoxShape.circle,
        ),
        child: IconTheme.merge(
          data: IconThemeData(
            color: outlined
                ? theme.colorScheme.primary
                : theme.colorScheme.onPrimary,
          ),
          child: icon,
        ),
      ),
    );
  }
}

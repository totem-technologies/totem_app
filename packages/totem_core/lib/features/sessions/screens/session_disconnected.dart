import 'dart:async';
import 'dart:math' as math;

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
import 'package:totem_core/core/errors/error_handler.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.context.mounted) return;
      _releaseLocalMedia();
      ref.invalidate(spacesSummaryProvider);
    });
    _spacesSummaryRefreshTimer = Timer(const Duration(milliseconds: 2750), () {
      if (mounted) ref.invalidate(spacesSummaryProvider);
    });
  }

  void _releaseLocalMedia() {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;
    unawaited(
      session.localMedia.release().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to release local media after disconnecting',
        );
      }),
    );
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

  void _goHome() {
    _refreshHome();
    TotemRouter.instance.toHome();
  }

  /// The space's next session, or a recommended session when the space has
  /// none scheduled.
  NextSessionPromo? _resolveNextSession() {
    const count = 1;
    final session = widget.session;

    final nextSession = session?.space.nextEvents
        .where((e) => e.slug != session.slug)
        .firstOrNull;
    final recommendedSessions = ref.watch(
      getRecommendedSessionsProvider(limit: count),
    );

    if (session != null && nextSession != null) {
      return NextSessionPromo(
        space: MobileSpaceDetailSchemaExtension.copyWith(
          session.space,
          nextEvents: [nextSession],
        ),
        onTap: () {
          _refreshHome();
          TotemRouter.instance.toSpaceSession(
            context,
            session.space.slug,
            nextSession.slug,
            true,
          );
        },
      );
    }

    final recommendedSession = recommendedSessions.hasValue
        ? recommendedSessions.value!.firstOrNull
        : null;
    if (recommendedSession != null) {
      return NextSessionPromo(
        space: spaceDetailFromSessionDetailSchema(recommendedSession),
        recommended: true,
        onTap: () {
          _refreshHome();
          TotemRouter.instance.toSpaceSession(
            context,
            recommendedSession.space.slug,
            recommendedSession.slug,
            true,
          );
        },
      );
    }

    return null;
  }

  Future<void> _sendLike(SessionDetailSchema session) async {
    await ref.read(
      sessionFeedbackProvider(session.slug, SessionFeedbackOptions.up).future,
    );
    await SessionDisconnectedScreen.incrementSessionLikedCount();
  }

  Future<void> _sendDislike(SessionDetailSchema session, String message) {
    return ref.read(
      sessionFeedbackProvider(
        session.slug,
        SessionFeedbackOptions.down,
        message,
      ).future,
    );
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

    final session = widget.session;
    final canGiveFeedback =
        session != null &&
        sessionReason == SessionDisconnectedReason.keeperEnded;

    return PopScope(
      canPop: false,
      child: SessionDisconnectedView(
        reason: sessionReason,
        nextSession: sessionReason == SessionDisconnectedReason.banned
            ? null
            : _resolveNextSession(),
        onLike: canGiveFeedback ? () => _sendLike(session) : null,
        onDislike: canGiveFeedback
            ? (message) => _sendDislike(session, message)
            : null,
        onGoHome: _goHome,
      ),
    );
  }
}

/// The session to promote once the current one ends.
@immutable
class NextSessionPromo {
  const NextSessionPromo({
    required this.space,
    required this.onTap,
    this.recommended = false,
  });

  /// The space, with the promoted session as its only next event.
  final MobileSpaceDetailSchema space;

  /// Whether this comes from another space, rather than being the next
  /// session of the space that just ended.
  final bool recommended;

  final VoidCallback onTap;
}

/// What a participant sees once they leave a session.
///
/// Pure: [SessionDisconnectedScreen] reads the providers and supplies the
/// data and callbacks.
class SessionDisconnectedView extends StatefulWidget {
  const SessionDisconnectedView({
    required this.reason,
    required this.onGoHome,
    this.nextSession,
    this.onLike,
    this.onDislike,
    super.key,
  }) : assert(
         (onLike == null) == (onDislike == null),
         'Pass both feedback callbacks, or neither.',
       );

  final SessionDisconnectedReason reason;

  /// Promoted below the header, unless null.
  final NextSessionPromo? nextSession;

  /// Sends a thumbs up. The feedback bar shows only when [onLike] and
  /// [onDislike] are set.
  final Future<void> Function()? onLike;

  /// Sends a thumbs down with the message the participant wrote.
  final Future<void> Function(String message)? onDislike;

  /// Leaves the screen for home: the close button and "See all upcoming
  /// sessions".
  final VoidCallback onGoHome;

  @override
  State<SessionDisconnectedView> createState() =>
      _SessionDisconnectedViewState();
}

class _SessionDisconnectedViewState extends State<SessionDisconnectedView> {
  /// Keeps the feedback selection when a resize or rotation swaps layouts.
  final GlobalKey _feedbackKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final reason = widget.reason;
    final nextSession = widget.nextSession;
    final onLike = widget.onLike;
    final onDislike = widget.onDislike;
    final onGoHome = widget.onGoHome;
    final feedback = onLike != null && onDislike != null
        ? _InteractiveFeedbackWidget(
            key: _feedbackKey,
            onLike: onLike,
            onDislike: onDislike,
          )
        : null;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackedContentHeight = _stackedContentHeight(
            MediaQuery.textScalerOf(context),
            hasFeedback: feedback != null,
          );
          bool fitsStacked(ViewportKind viewportKind) {
            final (verticalChrome, copyWidth) = switch (viewportKind) {
              ViewportKind.mediumSmall => (
                _MediumSmallLayout.verticalChrome,
                _MediumSmallLayout.copyWidth(constraints.maxWidth),
              ),
              _ => (
                _MediumPlusLayout.verticalChrome,
                _MediumPlusLayout.copyWidth(constraints.maxWidth),
              ),
            };
            return constraints.maxHeight >=
                stackedContentHeight +
                    _extraCopyHeight(context, reason, copyWidth) +
                    verticalChrome;
          }

          return ViewportResolver(
            builder: (context, viewportKind) {
              return switch (viewportKind) {
                ViewportKind.smallPortrait => _PortraitLayout(
                  reason: reason,
                  feedback: feedback,
                  nextSession: nextSession,
                  onGoHome: onGoHome,
                ),
                ViewportKind.smallLandscape => _TwoColumnLayout(
                  reason: reason,
                  feedback: feedback,
                  nextSession: nextSession,
                  onGoHome: onGoHome,
                  compact: true,
                ),
                ViewportKind.mediumSmall || ViewportKind.mediumPlus
                    when nextSession != null &&
                        constraints.maxWidth >= _TwoColumnLayout.minWidth &&
                        !fitsStacked(viewportKind) =>
                  _TwoColumnLayout(
                    reason: reason,
                    feedback: feedback,
                    nextSession: nextSession,
                    onGoHome: onGoHome,
                    compact: false,
                  ),
                ViewportKind.mediumSmall => _MediumSmallLayout(
                  reason: reason,
                  feedback: feedback,
                  nextSession: nextSession,
                  onGoHome: onGoHome,
                ),
                ViewportKind.mediumPlus => _MediumPlusLayout(
                  reason: reason,
                  feedback: feedback,
                  nextSession: nextSession,
                  onGoHome: onGoHome,
                ),
              };
            },
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// LAYOUTS
// -----------------------------------------------------------------------------

/// Estimated height of the medium stacked layouts' content, from the status
/// icon to the actions, with a next session card. Below this height (plus the
/// layout's own padding) the card moves beside the header instead of
/// scrolling.
double _stackedContentHeight(
  TextScaler textScaler, {
  required bool hasFeedback,
}) {
  final cardHeight = math.max(
    _NextSessionsSection.maxWidth / _NextSessionsSection._cardAspectRatio,
    textScaler.scale(_NextSessionsSection._cardMinHeight),
  );
  return _stackedFixedHeight +
      textScaler.scale(_stackedTextHeight) +
      cardHeight -
      (hasFeedback ? 0 : _stackedFeedbackHeight);
}

/// The part of the stacked content that doesn't grow with text: icon,
/// divider, gaps and padding. Together with [_stackedTextHeight] it was fit
/// to the `keeperEnded` screen measured with Montserrat at several text
/// scales, plus a safety margin of about 5px; the split is approximate.
const double _stackedFixedHeight = 354;

/// The part of the stacked content that grows with text at 1x: the
/// `keeperEnded` header and subheader, section title, feedback and button.
const double _stackedTextHeight = 150;

/// The feedback bar and its gap.
const double _stackedFeedbackHeight = 100;

/// Medium stacked layouts narrow their content column, and the header and
/// subheader within it, by this factor.
const double _widthFactor = 0.75;

/// How much taller the header and subheader for [reason] are than the
/// `keeperEnded` copy that [_stackedContentHeight] assumes, at [width].
double _extraCopyHeight(
  BuildContext context,
  SessionDisconnectedReason reason,
  double width,
) {
  if (reason == SessionDisconnectedReason.keeperEnded) return 0;
  final headerStyle = Theme.of(context).textTheme.headlineMedium;
  double copyHeight(SessionDisconnectedReason reason) =>
      _measureTextHeight(
        context,
        _SessionHeader.textFor(reason),
        headerStyle,
        width,
      ) +
      _measureTextHeight(
        context,
        _SessionSubheader.spanFor(reason).toPlainText(),
        null,
        width,
      );
  return math.max(
    0,
    copyHeight(reason) - copyHeight(SessionDisconnectedReason.keeperEnded),
  );
}

/// Height of [text] in [style], wrapped at [maxWidth].
double _measureTextHeight(
  BuildContext context,
  String text,
  TextStyle? style,
  double maxWidth,
) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  );
  try {
    textPainter.layout(maxWidth: maxWidth);
    return textPainter.height;
  } finally {
    textPainter.dispose();
  }
}

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({
    required this.reason,
    required this.feedback,
    required this.nextSession,
    required this.onGoHome,
  });

  final SessionDisconnectedReason reason;
  final Widget? feedback;
  final NextSessionPromo? nextSession;
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    final nextSession = this.nextSession;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 20,
          children: [
            _SessionHeader(reason: reason),
            _SessionSubheader(reason: reason),
            ?feedback,
            if (nextSession != null) _NextSessionsSection(promo: nextSession),
            _ActionButtons(onPressed: onGoHome),
          ],
        ),
      ),
    );
  }
}

/// Places the header and feedback beside the next session card, for
/// viewports too short to stack them. The card shrinks to the column height
/// instead of being cut off.
class _TwoColumnLayout extends StatelessWidget {
  const _TwoColumnLayout({
    required this.reason,
    required this.feedback,
    required this.nextSession,
    required this.onGoHome,
    required this.compact,
  });

  /// Narrowest viewport that fits both columns side by side, at about 240
  /// logical pixels each. Medium viewports are wider than this unless safe
  /// area insets narrow them.
  static const double minWidth = 600;

  static const double _verticalPadding = 40;

  /// Below this height the vertical padding shrinks to
  /// [_shortVerticalPadding], leaving more room for the card.
  static const double _shortHeight = 480;
  static const double _shortVerticalPadding = 16;

  final SessionDisconnectedReason reason;
  final Widget? feedback;
  final NextSessionPromo? nextSession;
  final VoidCallback onGoHome;

  /// Phone landscape: no status icon or close button, and the actions sit
  /// under the feedback so the card keeps the full column height.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    final nextSession = this.nextSession;
    final actions = _ActionButtons(onPressed: onGoHome);

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final verticalPadding = constraints.maxHeight < _shortHeight
            ? _shortVerticalPadding
            : _verticalPadding;
        return Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: 40,
            vertical: verticalPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 40,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _InteractiveFeedbackWidget.maxWidth,
                  ),
                  child: _CenteredScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 20,
                      children: [
                        if (!compact) _MediumStatusIcon(reason: reason),
                        _SessionHeader(reason: reason),
                        _SessionSubheader(reason: reason),
                        ?feedback,
                        if (compact && nextSession != null) actions,
                      ],
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _NextSessionsSection.maxWidth,
                  ),
                  child: nextSession != null
                      ? _NextSessionsSection.fitted(
                          promo: nextSession,
                          footer: compact ? null : actions,
                        )
                      : _CenteredScrollView(child: Center(child: actions)),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (compact) return content;
    return Stack(
      children: [
        Positioned.fill(child: content),
        PositionedDirectional(
          top: 48,
          start: 48,
          child: _CloseButton(onPressed: onGoHome),
        ),
      ],
    );
  }
}

class _MediumSmallLayout extends StatelessWidget {
  const _MediumSmallLayout({
    required this.reason,
    required this.feedback,
    required this.nextSession,
    required this.onGoHome,
  });

  /// Vertical space the layout reserves around its content.
  static const double verticalChrome = 2 * _verticalPadding;
  static const double _verticalPadding = 56;
  static const double _horizontalPadding = 16;

  /// Width the header and subheader wrap at in a [maxWidth] wide layout.
  static double copyWidth(double maxWidth) =>
      (maxWidth - 2 * _horizontalPadding) * _widthFactor * _widthFactor;

  final SessionDisconnectedReason reason;
  final Widget? feedback;
  final NextSessionPromo? nextSession;
  final VoidCallback onGoHome;

  Widget _wrapConstrained(Widget child) {
    return FractionallySizedBox(widthFactor: _widthFactor, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    final nextSession = this.nextSession;
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: _horizontalPadding,
              vertical: _verticalPadding,
            ),
            child: FractionallySizedBox(
              widthFactor: _widthFactor,
              child: _CenteredScrollView(
                child: Column(
                  spacing: 30,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _wrapConstrained(_MediumStatusIcon(reason: reason)),
                    _wrapConstrained(_SessionHeader(reason: reason)),
                    _wrapConstrained(_SessionSubheader(reason: reason)),
                    const Divider(color: Color(0x0FFFFFFF)),
                    if (feedback != null) _wrapConstrained(feedback),
                    if (nextSession != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _NextSessionsSection.maxWidth,
                        ),
                        child: _NextSessionsSection(promo: nextSession),
                      ),
                    _ActionButtons(onPressed: onGoHome),
                  ],
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 48,
          start: 48,
          child: _CloseButton(onPressed: onGoHome),
        ),
      ],
    );
  }
}

class _MediumPlusLayout extends StatelessWidget {
  const _MediumPlusLayout({
    required this.reason,
    required this.feedback,
    required this.nextSession,
    required this.onGoHome,
  });

  /// Vertical space the layout reserves below its content.
  static const double verticalChrome = _bottomSpacing + _bottomGap;
  static const double _bottomSpacing = 10;
  static const double _bottomGap = 40;

  /// Width the header and subheader wrap at in a [maxWidth] wide layout.
  static double copyWidth(double maxWidth) =>
      maxWidth * _widthFactor * _widthFactor;

  final SessionDisconnectedReason reason;
  final Widget? feedback;
  final NextSessionPromo? nextSession;
  final VoidCallback onGoHome;

  Widget _wrapConstrained(Widget child) {
    return FractionallySizedBox(widthFactor: _widthFactor, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    final nextSession = this.nextSession;
    return Column(
      spacing: _bottomSpacing,
      children: [
        Expanded(
          child: FractionallySizedBox(
            widthFactor: _widthFactor,
            child: _CenteredScrollView(
              child: Column(
                spacing: 30,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _wrapConstrained(_MediumStatusIcon(reason: reason)),
                  _wrapConstrained(_SessionHeader(reason: reason)),
                  _wrapConstrained(_SessionSubheader(reason: reason)),
                  const Divider(color: Color(0x0FFFFFFF)),
                  if (feedback != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _InteractiveFeedbackWidget.maxWidth,
                      ),
                      child: feedback,
                    ),
                  if (nextSession != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _NextSessionsSection.maxWidth,
                      ),
                      child: _NextSessionsSection(promo: nextSession),
                    ),
                  _ActionButtons(onPressed: onGoHome),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: _bottomGap),
      ],
    );
  }
}

/// A vertical scroll view whose content is at least as tall as the viewport,
/// so a centered [Column] stays centered until it overflows and scrolls.
class _CenteredScrollView extends StatelessWidget {
  const _CenteredScrollView({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          primary: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: TotemIcons.close,
      onPressed: onPressed,
      color: AppTheme.white.withValues(alpha: 0.8),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPONENTS
// -----------------------------------------------------------------------------

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.reason});

  final SessionDisconnectedReason reason;

  static String textFor(SessionDisconnectedReason reason) {
    return switch (reason) {
      SessionDisconnectedReason.keeperAbsent => 'Session will be rescheduled',
      SessionDisconnectedReason.movedToAnotherDevice =>
        'Session moved to another device',
      SessionDisconnectedReason.removed =>
        "You've been removed from this session.",
      SessionDisconnectedReason.roomEmpty ||
      SessionDisconnectedReason.keeperEnded => 'Session Ended',
      SessionDisconnectedReason.banned => "You've Been Banned",
      SessionDisconnectedReason.other => 'Disconnected',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        textFor(reason),
        style: Theme.of(context).textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SessionSubheader extends StatefulWidget {
  const _SessionSubheader({required this.reason});
  final SessionDisconnectedReason reason;

  /// The copy for [reason]. Links are tappable only when their recognizers
  /// are given.
  static TextSpan spanFor(
    SessionDisconnectedReason reason, {
    TapGestureRecognizer? communityGuidelinesRecognizer,
    TapGestureRecognizer? helpEmailRecognizer,
  }) {
    final linkStyle = TextStyle(color: Colors.blue.shade200);
    final removedSpan = TextSpan(
      text: 'Please take a moment to review our ',
      children: [
        // TODO(totem): Use LinkSpan when available https://github.com/flutter/flutter/issues/91600
        TextSpan(
          text: 'Community Guidelines',
          style: linkStyle,
          recognizer: communityGuidelinesRecognizer,
        ),
        const TextSpan(text: '. '),
        const TextSpan(
          text: 'If you believe this was a mistake, reach out to us at ',
        ),
        TextSpan(
          text: 'help@totem.org',
          style: linkStyle,
          recognizer: helpEmailRecognizer,
        ),
        const TextSpan(text: '.'),
      ],
    );
    return switch (reason) {
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
    };
  }

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
    return Text.rich(
      _SessionSubheader.spanFor(
        widget.reason,
        communityGuidelinesRecognizer: _communityGuidelinesRecognizer,
        helpEmailRecognizer: _helpEmailRecognizer,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _InteractiveFeedbackWidget extends StatefulWidget {
  const _InteractiveFeedbackWidget({
    required this.onLike,
    required this.onDislike,
    super.key,
  });

  final Future<void> Function() onLike;
  final Future<void> Function(String message) onDislike;

  /// Max width of the feedback bar in layouts wider than a phone in portrait.
  static const double maxWidth = 420;

  @override
  State<_InteractiveFeedbackWidget> createState() =>
      _InteractiveFeedbackWidgetState();
}

class _InteractiveFeedbackWidgetState
    extends State<_InteractiveFeedbackWidget> {
  ThumbState _thumbState = ThumbState.none;

  @override
  Widget build(BuildContext context) {
    return _SessionFeedbackWidget(
      state: _thumbState,
      onThumbUpPressed: () async {
        setState(() => _thumbState = ThumbState.up);
        ConfettiController.showConfetti(context);
        await widget.onLike();
      },
      onThumbDownPressed: () async {
        await showUserFeedbackPopup(
          context,
          onFeedbackSubmitted: (message) {
            _thumbState = ThumbState.down;
            if (mounted) setState(() {});
            return widget.onDislike(message);
          },
        );
      },
    );
  }
}

class _NextSessionsSection extends StatelessWidget {
  /// Sizes the card from its width. The surrounding page scrolls when the
  /// card doesn't fit.
  const _NextSessionsSection({required this.promo})
    : fitHeight = false,
      footer = null;

  /// Shrinks the card, down to its minimum height, to fit the available
  /// height alongside [footer]. Scrolls only when even the smallest card
  /// doesn't fit.
  const _NextSessionsSection.fitted({required this.promo, this.footer})
    : fitHeight = true;

  final NextSessionPromo promo;
  final bool fitHeight;

  /// Shown below the card in the fitted layout.
  final Widget? footer;

  /// Max width of the section in layouts wider than a phone in portrait.
  static const double maxWidth = 320;

  static const double _spacing = 20;

  static const double _cardAspectRatio = 1.32;

  /// Minimum card height (before text scaling) that fits the date chip,
  /// a two-line title, the next session line, the keeper row and seats.
  static const double _cardMinHeight = 220;

  @override
  Widget build(BuildContext context) {
    final title = promo.recommended
        ? 'You may enjoy this space'
        : 'Sign up for the next session';
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final header = Text(
      title,
      style: titleStyle,
      textAlign: TextAlign.start,
    );
    final minCardHeight = MediaQuery.textScalerOf(
      context,
    ).scale(_cardMinHeight);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final card = SizedBox(
          width: width,
          height: math.max(width / _cardAspectRatio, minCardHeight),
          child: SpaceCard(
            space: promo.space,
            aspectRatio: null,
            onTap: promo.onTap,
          ),
        );

        if (!fitHeight) {
          return Column(
            spacing: _spacing,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [header, card],
          );
        }

        final footer = this.footer;
        final minHeight =
            _measureTextHeight(context, title, titleStyle, width) +
            _spacing +
            minCardHeight +
            (footer != null
                ? _spacing + _ActionButtons.height(context, width)
                : 0);
        return SingleChildScrollView(
          primary: false,
          child: SizedBox(
            height: math.max(constraints.maxHeight, minHeight),
            child: Column(
              spacing: _spacing,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                Flexible(child: card),
                if (footer != null) Center(child: footer),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onPressed});

  final VoidCallback onPressed;

  static const String _label = 'See all upcoming sessions';
  static const double _horizontalPadding = 58;

  /// Estimated height of the button laid out in [maxWidth].
  static double height(BuildContext context, double maxWidth) {
    final textHeight = _measureTextHeight(
      context,
      _label,
      Theme.of(context).textTheme.labelLarge,
      math.max(0, maxWidth - 2 * _horizontalPadding),
    );
    return math.max(kMinInteractiveDimension, textHeight + 16);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: _horizontalPadding,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      child: const Text(
        _label,
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

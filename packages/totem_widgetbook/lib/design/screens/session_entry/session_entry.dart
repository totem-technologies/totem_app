import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/sessions/widgets/session_admission_list.dart';
import 'package:totem_core/features/sessions/widgets/session_browsing_view.dart';
import 'package:totem_core/features/sessions/widgets/session_declined_view.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_info_card.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_notice.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_queue_button.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_view.dart';

import '../../components/button/button.dart';
import '../../components/participant_card/participant_card.dart';
import '../../components/session_controls/session_controls.dart';
import '../../paint.dart';
import '../../tokens/tokens.dart';
import 'entry_layer.dart';
import 'session_details.dart';

typedef EntryPhase = DetailsPhase;

enum EntryStatus { browsing, lobby, waitingRoom, inSession, declined }

enum EntryRole { participant, keeper }

enum DeclineVariant { nextSession, related }

@immutable
class AdmissionRequest {
  const AdmissionRequest({
    required this.id,
    required this.name,
    required this.expiresLabel,
  });

  final String id;
  final String name;
  final String expiresLabel;
}

const _circle = [
  (name: 'Noah', feature: true),
  (name: 'Maya', feature: false),
  (name: 'Sam', feature: false),
  (name: 'Jules', feature: false),
  (name: 'Priya', feature: false),
];

typedef _Tone = ({Color bg, Color fg});

const List<_Tone> _tones = [
  (bg: TotemColors.coreMauve, fg: TotemColors.coreWhite),
  (bg: TotemColors.extendedSteel, fg: TotemColors.coreWhite),
  (bg: TotemColors.extendedBerry, fg: TotemColors.coreWhite),
  (bg: TotemColors.extendedSky, fg: TotemColors.coreSlate),
  (bg: TotemColors.extendedGold, fg: TotemColors.coreSlate),
];

_Tone _toneFor(String name) =>
    _tones[name.codeUnits.fold(0, (a, b) => a + b) % _tones.length];

String _initial(String name) =>
    name.isEmpty ? '' : name.substring(0, 1).toUpperCase();

typedef _Media = ({
  bool micOn,
  bool cameraOn,
  VoidCallback onMic,
  VoidCallback onCamera,
});

/// The screen's own size class, shared by everything inside it.
class _Breakpoints extends InheritedWidget {
  const _Breakpoints({
    required this.wide,
    required this.web,
    required super.child,
  });

  /// 640 and up: a window, not a phone.
  final bool wide;

  /// 1100 and up: Figma web Session (3800:10532).
  final bool web;

  static _Breakpoints of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Breakpoints>()!;

  @override
  bool updateShouldNotify(_Breakpoints oldWidget) =>
      wide != oldWidget.wide || web != oldWidget.web;
}

// Type used across the screen.

TextStyle _kicker(BuildContext context) => TotemText.overlineBold.copyWith(
  letterSpacing: 0.8,
  color: TotemTheme.of(context).accent,
);

TextStyle _title(BuildContext context) => TotemText.h2.copyWith(
  letterSpacing: -0.42,
  color: TotemTheme.of(context).textPrimary,
);

TextStyle _muted(BuildContext context) =>
    TotemText.bodySmall.copyWith(color: TotemTheme.of(context).textSecondary);

/// Joining a Session: Google Meet's join behavior, Totem's materials.
///
/// A participant never sees the room until a Keeper admits them. Join is
/// the only action — the admission request is a side effect. The Keeper
/// sees the same moment from the other side: a waiting pill, then the
/// admission panel.
///
/// Layout follows the screen's own width. Narrow is a phone with bottom
/// sheets. From 640 it reads as a window: side panel and centered modal.
/// From 1100 it is the web Session layout (Figma 3800:10532).
class SessionEntry extends StatefulWidget {
  const SessionEntry({
    super.key,
    required this.role,
    required this.phase,
    required this.status,
    this.spaceName = '',
    this.sessionName = '',
    this.keeperName = '',
    this.startDateLabel = '',
    this.startTime = '',
    this.joinTime = '',
    this.participantName = 'You',
    this.previewPhoto,
    this.heroPhoto,
    this.keeperPhoto,
    this.about,
    this.similarSession,
    this.keeperLocation,
    this.keeperBio,
    this.onShare,
    this.onKeeperProfile,
    this.facts = const [],
    this.prompt,
    this.nextOffer,
    this.relatedOffer,
    this.requests = const [],
    this.panelOpen = false,
    this.showOrientation = false,
    this.declineVariant = DeclineVariant.nextSession,
    this.onJoin,
    this.onLeaveLobby,
    this.onAdmit,
    this.onAdmitAll,
    this.onDeclineRequest,
    this.onDismissPanel,
    this.onOpenPanel,
    this.onDismissOrientation,
    this.onBackToSpace,
    this.onSignUp,
    this.expiresLabel,
  });

  final EntryRole role;
  final EntryPhase phase;
  final EntryStatus status;
  final String spaceName;
  final String sessionName;
  final String keeperName;
  final String startDateLabel;
  final String startTime;
  final String joinTime;
  final String participantName;
  final ImageProvider? previewPhoto;
  final ImageProvider? heroPhoto;
  final ImageProvider? keeperPhoto;
  final String? about;
  final Widget? similarSession;
  final String? keeperLocation;
  final String? keeperBio;
  final VoidCallback? onShare;
  final VoidCallback? onKeeperProfile;
  final List<SessionEntryFact> facts;
  final String? prompt;
  final Widget? nextOffer;
  final Widget? relatedOffer;
  final List<AdmissionRequest> requests;
  final bool panelOpen;
  final bool showOrientation;
  final DeclineVariant declineVariant;
  final VoidCallback? onJoin;
  final VoidCallback? onLeaveLobby;
  final ValueChanged<String>? onAdmit;
  final VoidCallback? onAdmitAll;
  final ValueChanged<String>? onDeclineRequest;
  final VoidCallback? onDismissPanel;
  final VoidCallback? onOpenPanel;
  final VoidCallback? onDismissOrientation;
  final VoidCallback? onBackToSpace;
  final VoidCallback? onSignUp;

  /// Countdown on the waiting card. Comes from the join request.
  final String? expiresLabel;

  @override
  State<SessionEntry> createState() => _SessionEntryState();
}

class _SessionEntryState extends State<SessionEntry> {
  bool _micOn = true;
  bool _cameraOn = true;

  /// A sheet or dialog is covering the Session details (early arrival
  /// or Community Guidelines). Hides the home indicator, same as the
  /// admission panel.
  bool _browsingCover = false;

  /// Closes whichever details layer is on top. Registered by the
  /// browsing screen so Escape reaches it.
  VoidCallback? _closeBrowsingLayer;

  _Media get _media => (
    micOn: _micOn,
    cameraOn: _cameraOn,
    onMic: () => setState(() => _micOn = !_micOn),
    onCamera: () => setState(() => _cameraOn = !_cameraOn),
  );

  bool get _keeper => widget.role == EntryRole.keeper;

  int get _waitingCount =>
      _keeper && !widget.panelOpen ? widget.requests.length : 0;

  /// The room is on screen, so the home indicator turns cream.
  bool get _darkScreen => _keeper
      ? widget.phase == EntryPhase.inProgress
      : widget.status == EntryStatus.inSession;

  String get _liveMessage {
    if (_keeper) {
      final count = widget.requests.length;
      if (count == 0) return 'No one is waiting to join.';
      return count == 1
          ? '1 person is waiting to join.'
          : '$count people are waiting to join.';
    }
    final early = widget.phase == EntryPhase.tooEarly;
    final late = widget.phase == EntryPhase.inProgress;
    return switch (widget.status) {
      EntryStatus.browsing when early =>
        "You're all set for ${widget.sessionName}. Join session is available at ${widget.joinTime}.",
      EntryStatus.browsing => 'Join session is available.',
      EntryStatus.lobby when late =>
        "This session is already in progress. You're waiting to be admitted.",
      EntryStatus.lobby =>
        "We're getting the room ready. You're waiting to be admitted.",
      EntryStatus.waitingRoom => "You're in the waiting room.",
      EntryStatus.inSession => "You're in the session.",
      EntryStatus.declined =>
        'This session is no longer available for admission.',
    };
  }

  void _onEscape() {
    if (_browsingCover) {
      _closeBrowsingLayer?.call();
    } else if (widget.showOrientation) {
      widget.onDismissOrientation?.call();
    } else if (widget.panelOpen) {
      widget.onDismissPanel?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = TotemTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final web = constraints.maxWidth >= 1100;
        final coverOpen =
            widget.panelOpen || widget.showOrientation || _browsingCover;

        // Figma frames were 812 / 760. Inside Widgetbook the viewport
        // is the device (iPhone 13 is 844 tall), so a fixed height
        // leaves a strip of canvas at the bottom. Fill when bounded.
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : (wide ? 760.0 : 812.0);
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : double.infinity;

        return _Breakpoints(
          wide: wide,
          web: web,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): _onEscape,
            },
            child: Focus(
              autofocus: true,
              child: Container(
                width: width,
                height: height,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.canvas,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  boxShadow: Shadows.elevation2,
                ),
                child: DefaultTextStyle(
                  style: TotemText.body.copyWith(color: theme.textPrimary),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _keeper ? _keeperScreen() : _participantScreen(),
                      Semantics(
                        liveRegion: true,
                        label: _liveMessage,
                        child: const SizedBox.shrink(),
                      ),
                      // Phone home indicator. Hidden once the frame reads as a
                      // window, and while a sheet is covering the bottom.
                      if (!wide && !coverOpen)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                width: Spacing.homebarWidth,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: _darkScreen
                                      ? fade(TotemColors.coreCream, 0.4)
                                      : fade(TotemColors.coreSlate, 0.28),
                                  borderRadius: BorderRadius.circular(
                                    Radii.full,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _keeperScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.phase == EntryPhase.inProgress)
          _Room(
            participantName: widget.participantName,
            showAlex: widget.status == EntryStatus.inSession,
            media: _media,
            waitingCount: _waitingCount,
            onWaiting: widget.onOpenPanel,
          )
        else
          _KeeperPrep(
            startTime: widget.startTime,
            joinTime: widget.joinTime,
            keeperName: widget.keeperName,
            phase: widget.phase,
            requestCount: widget.requests.length,
            media: _media,
            waitingCount: _waitingCount,
            onWaiting: widget.onOpenPanel,
          ),
        _Admission(
          open: widget.panelOpen,
          requests: widget.requests,
          onAdmit: widget.onAdmit,
          onAdmitAll: widget.onAdmitAll,
          onDeclineRequest: widget.onDeclineRequest,
          onDismiss: widget.onDismissPanel,
        ),
      ],
    );
  }

  Widget _participantScreen() {
    return switch (widget.status) {
      EntryStatus.browsing => _PreSession(
        spaceName: widget.spaceName,
        sessionName: widget.sessionName,
        keeperName: widget.keeperName,
        startDateLabel: widget.startDateLabel,
        startTime: widget.startTime,
        joinTime: widget.joinTime,
        facts: widget.facts,
        heroPhoto: widget.heroPhoto,
        keeperPhoto: widget.keeperPhoto,
        about: widget.about,
        similarSession: widget.similarSession,
        keeperLocation: widget.keeperLocation,
        keeperBio: widget.keeperBio,
        onShare: widget.onShare,
        onKeeperProfile: widget.onKeeperProfile,
        phase: widget.phase,
        onJoin: widget.onJoin,
        onBack: widget.onBackToSpace,
        onCoverChanged: (open) {
          if (!mounted) return;
          setState(() => _browsingCover = open);
        },
        onBindDismiss: (close) => _closeBrowsingLayer = close,
      ),
      EntryStatus.lobby => _Lobby(
        participantName: widget.participantName,
        previewPhoto: widget.previewPhoto,
        late: widget.phase == EntryPhase.inProgress,
        expiresLabel: widget.expiresLabel,
        media: _media,
        onLeave: widget.onLeaveLobby,
      ),
      EntryStatus.waitingRoom => _WaitingRoom(
        media: _media,
        participantName: widget.participantName,
        previewPhoto: widget.previewPhoto,
        sessionName: widget.sessionName,
        startTime: widget.startTime,
      ),
      EntryStatus.inSession => Stack(
        fit: StackFit.expand,
        children: [
          _Room(
            participantName: widget.participantName,
            showAlex: true,
            media: _media,
            waitingCount: 0,
          ),
          _Orientation(
            prompt: widget.prompt,
            open: widget.showOrientation,
            onDismiss: widget.onDismissOrientation,
          ),
        ],
      ),
      EntryStatus.declined => _Declined(
        offer: widget.declineVariant == DeclineVariant.nextSession
            ? widget.nextOffer
            : widget.relatedOffer,
        variant: widget.declineVariant,
        onSignUp: widget.onSignUp,
        onBackToSpace: widget.onBackToSpace,
      ),
    };
  }
}

// ------------------------------------------------------------------
// Small pieces
// ------------------------------------------------------------------

/// Stroke icons drawn from the Figma paths. Color follows [IconTheme].
class _StrokeIcon extends StatelessWidget {
  const _StrokeIcon._(this.size, this.viewBox, this.paint);

  factory _StrokeIcon.cameraOff() => const _StrokeIcon._(22, 24, _cameraOff);

  final double size;
  final double viewBox;
  final void Function(Canvas canvas, Paint paint) paint;

  static void _cameraOff(Canvas canvas, Paint paint) {
    paint.strokeWidth = 1.7;
    canvas.drawRRect(
      RRect.fromLTRBR(2.4, 8.5, 14.8, 18, const Radius.circular(1.1)),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(14.8, 11.2)
        ..lineTo(20.2, 8.4)
        ..quadraticBezierTo(21.3, 7.9, 21.3, 9.1)
        ..lineTo(21.3, 15.9)
        ..quadraticBezierTo(21.3, 17.1, 20.2, 16.6)
        ..lineTo(14.8, 13.8),
      paint,
    );
    paint.strokeWidth = 1.8;
    canvas.drawLine(const Offset(4, 5), const Offset(20, 19), paint);
  }

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? TotemColors.coreSlate;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _StrokePainter(color, viewBox, paint)),
    );
  }
}

class _StrokePainter extends CustomPainter {
  const _StrokePainter(this.color, this.viewBox, this.draw);

  final Color color;
  final double viewBox;
  final void Function(Canvas canvas, Paint paint) draw;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / viewBox);
    draw(
      canvas,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.draw != draw;
}

/// Pops in from a little below, once, when it first appears.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: const Cubic(0.22, 1.2, 0.36, 1),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
        ),
      ),
      child: child,
    );
  }
}

// ------------------------------------------------------------------
// Admission
// ------------------------------------------------------------------

/// Overlay in both seats. Phone: sheet from the bottom. Window: drawer
/// from the right. Same list either way.
class _Admission extends StatelessWidget {
  const _Admission({
    required this.open,
    required this.requests,
    this.onAdmit,
    this.onAdmitAll,
    this.onDeclineRequest,
    this.onDismiss,
  });

  final bool open;
  final List<AdmissionRequest> requests;
  final ValueChanged<String>? onAdmit;
  final VoidCallback? onAdmitAll;
  final ValueChanged<String>? onDeclineRequest;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final wide = _Breakpoints.of(context).wide;
    return EntryLayer(
      key: ValueKey(wide),
      open: open,
      kind: wide ? LayerKind.panel : LayerKind.sheet,
      label: 'Waiting to join',
      scrim: LayerScrim.soft,
      dismissOnScrim: true,
      onDismiss: onDismiss,
      child: SessionAdmissionList(
        guests: [
          for (final request in requests)
            SessionAdmissionGuest(
              id: request.id,
              name: request.name,
              expiresLabel: request.expiresLabel,
            ),
        ],
        onAdmit: onAdmit,
        onAdmitAll: onAdmitAll,
        onDecline: onDeclineRequest,
        onClose: onDismiss,
      ),
    );
  }
}

// ------------------------------------------------------------------
// Media bar
// ------------------------------------------------------------------

/// The shared Session Controls bar, plus what hangs off it here: the gold
/// waiting pill for Keepers and the device menu behind More.
///
/// [inCircle] turns on reactions and chat. Nobody gets those before
/// they've been admitted to the room.
class _MediaBar extends StatefulWidget {
  const _MediaBar({
    required this.media,
    this.waitingCount = 0,
    this.onWaiting,
    this.inCircle = false,
    this.tone = SessionControlsTone.solid,
  });

  final _Media media;
  final int waitingCount;
  final VoidCallback? onWaiting;
  final bool inCircle;
  final SessionControlsTone tone;

  @override
  State<_MediaBar> createState() => _MediaBarState();
}

class _MediaBarState extends State<_MediaBar> {
  bool _devicesOpen = false;
  bool _reactionsOpen = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.waitingCount;
    final media = widget.media;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Spacing.s8,
          children: [
            if (count > 0)
              _PopIn(
                child: SessionWaitingQueueButton(
                  count: count,
                  onPressed: widget.onWaiting,
                ),
              ),
            SessionControls(
              micOn: media.micOn,
              cameraOn: media.cameraOn,
              onMic: media.onMic,
              onCamera: media.onCamera,
              showSessionActions: widget.inCircle,
              reactionsOpen: _reactionsOpen,
              onReactions: () =>
                  setState(() => _reactionsOpen = !_reactionsOpen),
              moreLabel: 'Device settings',
              moreExpanded: _devicesOpen,
              onMore: () => setState(() => _devicesOpen = !_devicesOpen),
              tone: widget.tone,
            ),
          ],
        ),
        if (_devicesOpen)
          // Sits just above the bar, its bottom edge 4px into the controls.
          Positioned(
            top: Spacing.s4,
            left: -100,
            right: -100,
            child: FractionalTranslation(
              translation: const Offset(0, -1),
              child: Center(child: _deviceMenu(context)),
            ),
          ),
      ],
    );
  }

  Widget _deviceMenu(BuildContext context) {
    final theme = TotemTheme.of(context);
    final line = _muted(context);
    return Semantics(
      container: true,
      label: 'Devices',
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.s12,
          horizontal: Spacing.s16,
        ),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: Shadows.elevation2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Spacing.s4,
          children: [
            Text(
              'Devices',
              style: TotemText.captionBold.copyWith(color: theme.textPrimary),
            ),
            Text('Microphone · Default', style: line),
            Text('Camera · Default', style: line),
            Text('Speaker · Default', style: line),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Session room
// ------------------------------------------------------------------

String _cardLabel(String name, String participantName) =>
    name == participantName ? '$participantName (you)' : name;

/// Same arrangement as the live call. Narrow: the speaker sits on top,
/// everyone else in two columns. Wide: the speaker fills the left, the rest
/// fill the grid on the right. Web: Figma 3800:10532 — speaker 391 × 461,
/// gallery 4 × 2 with 20px gutters, 40px from the speaker.
/// Names stay at the bottom of each card. No stats overlay.
class _Room extends StatelessWidget {
  const _Room({
    required this.participantName,
    required this.showAlex,
    required this.media,
    required this.waitingCount,
    this.onWaiting,
  });

  final String participantName;
  final bool showAlex;
  final _Media media;
  final int waitingCount;
  final VoidCallback? onWaiting;

  @override
  Widget build(BuildContext context) {
    final sizes = _Breakpoints.of(context);
    final people = [
      ..._circle,
      if (showAlex) (name: participantName, feature: false),
    ];
    final feature = people.where((person) => person.feature).firstOrNull;
    final rest = [
      for (final person in people.where((person) => !person.feature))
        // Same tile as the waiting-room preview — the shared red → blue
        // wash when there's no picture.
        ParticipantCard(name: _cardLabel(person.name, participantName)),
    ];
    final speaker = feature == null
        ? null
        : ParticipantCard(
            name: _cardLabel(feature.name, participantName),
            feature: true,
            showTalkingPiece: true,
          );

    final next = Text(
      'Next up Maya',
      style: TotemText.caption.copyWith(
        color: fade(TotemColors.coreCream, 0.78),
      ),
    );
    final bar = _MediaBar(
      media: media,
      waitingCount: waitingCount,
      onWaiting: onWaiting,
      inCircle: true,
      tone: SessionControlsTone.glass,
    );

    return Semantics(
      container: true,
      label: 'session',
      child: ColoredBox(
        color: TotemColors.coreSlate,
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: TotemColors.coreCream),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: sizes.web
                    ? _webStage(speaker, rest)
                    : sizes.wide
                    ? _wideStage(speaker, rest)
                    : _narrowStage(speaker, rest),
              ),
              if (sizes.wide)
                Padding(
                  padding: sizes.web
                      ? const EdgeInsets.fromLTRB(10, 10, 10, 24)
                      : const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: next,
                        ),
                      ),
                      bar,
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 22),
                  child: Column(
                    spacing: 8,
                    children: [
                      Align(alignment: Alignment.centerLeft, child: next),
                      bar,
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _narrowStage(Widget? speaker, List<Widget> rest) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          if (speaker != null) Expanded(flex: 115, child: speaker),
          // A lone last card takes the row instead of sitting in a hole.
          Expanded(
            flex: 100,
            child: _TileGrid(tiles: rest, columns: 2, gap: 8),
          ),
        ],
      ),
    );
  }

  Widget _wideStage(Widget? speaker, List<Widget> rest) {
    // Three across when the row is full. A short last row shares the width,
    // so there is no empty card.
    final dense = rest.length > 4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          if (speaker != null) Expanded(flex: 112, child: speaker),
          Expanded(
            flex: 100,
            child: _TileGrid(
              tiles: rest,
              columns: dense ? 3 : 2,
              gap: 8,
              minRows: dense ? 2 : 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _webStage(Widget? speaker, List<Widget> rest) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 40, 10, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 40.0;
          final width = constraints.maxWidth;
          final height = math.min(461.0, constraints.maxHeight);
          var speakerWidth = math.min(391.0, width * 0.36);
          var galleryWidth = math.min(796.0, width * 0.62);
          // Both shrink together when the row runs out of room.
          final overflow = speakerWidth + galleryWidth + gap - width;
          if (overflow > 0) {
            final scale =
                (speakerWidth + galleryWidth - overflow) /
                (speakerWidth + galleryWidth);
            speakerWidth *= scale;
            galleryWidth *= scale;
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: gap,
            children: [
              if (speaker != null)
                SizedBox(width: speakerWidth, height: height, child: speaker),
              SizedBox(
                width: galleryWidth,
                height: height,
                // A leftover last tile keeps its cell. Don't stretch it across.
                child: _TileGrid(
                  tiles: rest,
                  columns: 4,
                  gap: 20,
                  minRows: 2,
                  stretchShortRow: false,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Equal rows of equal cells.
class _TileGrid extends StatelessWidget {
  const _TileGrid({
    required this.tiles,
    required this.columns,
    required this.gap,
    this.minRows = 0,
    this.stretchShortRow = true,
  });

  final List<Widget> tiles;
  final int columns;
  final double gap;
  final int minRows;

  /// A short last row shares the full width. Off, it keeps grid cells.
  final bool stretchShortRow;

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[
      for (var i = 0; i < tiles.length; i += columns)
        tiles.skip(i).take(columns).toList(),
    ];
    while (rows.length < minRows) {
      rows.add([]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        for (final row in rows)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [
                for (final tile in row) Expanded(child: tile),
                if (!stretchShortRow && row.isNotEmpty)
                  for (var i = row.length; i < columns; i++)
                    const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------
// Sheets and modals
// ------------------------------------------------------------------

class _Orientation extends StatelessWidget {
  const _Orientation({required this.open, this.prompt, this.onDismiss});

  final String? prompt;
  final bool open;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final wide = _Breakpoints.of(context).wide;
    return EntryLayer(
      key: ValueKey(wide),
      open: open,
      kind: wide ? LayerKind.modal : LayerKind.sheet,
      label: "You're joining a session already in progress",
      scrim: wide ? LayerScrim.dim : LayerScrim.soft,
      onDismiss: onDismiss,
      child: SessionOrientationNotice(prompt: prompt, onDone: onDismiss),
    );
  }
}

// ------------------------------------------------------------------
// Participant screens
// ------------------------------------------------------------------

/// Before joining: the Session details screen. Community Guidelines and
/// the early-arrival note both open here — a sheet on the phone, a
/// dialog once the frame reads as a window.
class _PreSession extends StatefulWidget {
  const _PreSession({
    required this.spaceName,
    required this.sessionName,
    required this.keeperName,
    required this.startDateLabel,
    required this.startTime,
    required this.joinTime,
    required this.facts,
    required this.phase,
    this.heroPhoto,
    this.keeperPhoto,
    this.about,
    this.similarSession,
    this.keeperLocation,
    this.keeperBio,
    this.onShare,
    this.onKeeperProfile,
    this.onJoin,
    this.onBack,
    this.onCoverChanged,
    this.onBindDismiss,
  });

  final String spaceName;
  final String sessionName;
  final String keeperName;
  final String startDateLabel;
  final String startTime;
  final String joinTime;
  final List<SessionEntryFact> facts;
  final EntryPhase phase;
  final ImageProvider? heroPhoto;
  final ImageProvider? keeperPhoto;
  final String? about;
  final Widget? similarSession;
  final String? keeperLocation;
  final String? keeperBio;
  final VoidCallback? onShare;
  final VoidCallback? onKeeperProfile;
  final VoidCallback? onJoin;
  final VoidCallback? onBack;

  /// True while a sheet or dialog is covering the details.
  final ValueChanged<bool>? onCoverChanged;

  /// Hands the parent a way to dismiss the top layer (Escape).
  /// Null clears it.
  final ValueChanged<VoidCallback?>? onBindDismiss;

  @override
  State<_PreSession> createState() => _PreSessionState();
}

class _PreSessionState extends State<_PreSession> {
  bool _guideOpen = false;
  bool _earlyOpen = false;

  @override
  void initState() {
    super.initState();
    widget.onBindDismiss?.call(_closeTop);
  }

  @override
  void didUpdateWidget(covariant _PreSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The note only belongs to early arrival. Leaving that phase
    // drops it so a later Join goes straight into the room.
    if (widget.phase != EntryPhase.tooEarly && _earlyOpen) {
      _earlyOpen = false;
      // Parent is mid-build. Tell it on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publishCover();
      });
    }
    if (widget.onBindDismiss != oldWidget.onBindDismiss) {
      widget.onBindDismiss?.call(_closeTop);
    }
  }

  @override
  void dispose() {
    widget.onBindDismiss?.call(null);
    final notify = widget.onCoverChanged;
    if ((_earlyOpen || _guideOpen) && notify != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notify(false));
    }
    super.dispose();
  }

  void _publishCover() {
    widget.onCoverChanged?.call(_earlyOpen || _guideOpen);
  }

  void _setGuide(bool open) {
    setState(() => _guideOpen = open);
    _publishCover();
  }

  void _setEarly(bool open) {
    setState(() => _earlyOpen = open);
    _publishCover();
  }

  /// Guidelines sits above the early note, so it closes first.
  void _closeTop() {
    if (_guideOpen) {
      _setGuide(false);
    } else {
      _setEarly(false);
    }
  }

  /// Too early, Join explains the window instead of entering the room.
  void _onJoin() {
    if (widget.phase == EntryPhase.tooEarly) {
      _setEarly(true);
      return;
    }
    widget.onJoin?.call();
  }

  @override
  Widget build(BuildContext context) {
    final wide = _Breakpoints.of(context).wide;
    final bullet = TotemText.body.copyWith(
      color: TotemTheme.of(context).textPrimary,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        SessionBrowsingView(
          spaceName: widget.spaceName,
          sessionName: widget.sessionName,
          keeperName: widget.keeperName,
          dateLabel: widget.startDateLabel,
          timeLabel: widget.startTime,
          facts: widget.facts,
          heroPhoto: widget.heroPhoto,
          keeperPhoto: widget.keeperPhoto,
          about: widget.about,
          similarSession: widget.similarSession,
          keeperLocation: widget.keeperLocation,
          keeperBio: widget.keeperBio,
          onShare: widget.onShare,
          onKeeperProfile: widget.onKeeperProfile,
          onJoin: _onJoin,
          onBack: widget.onBack,
        ),
        _EarlyArrival(
          sessionName: widget.sessionName,
          joinTime: widget.joinTime,
          open: _earlyOpen,
          onDismiss: () => _setEarly(false),
          onGuidelines: () => _setGuide(true),
        ),
        EntryLayer(
          key: ValueKey(wide),
          open: _guideOpen,
          kind: wide ? LayerKind.modal : LayerKind.sheet,
          label: 'Community Guidelines',
          scrim: wide ? LayerScrim.dim : LayerScrim.soft,
          onDismiss: () => _setGuide(false),
          child: SessionEntryNotice(
            kicker: 'Before you enter',
            title: 'Community Guidelines',
            onDone: () => _setGuide(false),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Spacing.s8,
                  children: [
                    for (final line in const [
                      'Listen while someone else has the piece.',
                      "What's said here stays here.",
                      "You can pass. That's a full turn.",
                    ])
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 18, child: Text('•', style: bullet)),
                          Expanded(child: Text(line, style: bullet)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The early-arrival note from the card, lifted into its own surface.
///
/// Phone: a sheet you can drag down. Window and web: a centered dialog.
/// Same spring as the other layers — a flick carries, a grab mid-flight
/// takes over from the live position.
class _EarlyArrival extends StatelessWidget {
  const _EarlyArrival({
    required this.sessionName,
    required this.joinTime,
    required this.open,
    required this.onDismiss,
    required this.onGuidelines,
  });

  final String sessionName;
  final String joinTime;
  final bool open;
  final VoidCallback onDismiss;
  final VoidCallback onGuidelines;

  @override
  Widget build(BuildContext context) {
    final wide = _Breakpoints.of(context).wide;
    final theme = TotemTheme.of(context);
    final body = _muted(context);
    final strong = body.copyWith(
      color: theme.textPrimary,
      fontWeight: FontWeight.w600,
    );

    return EntryLayer(
      key: ValueKey('early-$wide'),
      open: open,
      kind: wide ? LayerKind.modal : LayerKind.sheet,
      label:
          "You're all set for $sessionName. You can join beginning at $joinTime.",
      scrim: wide ? LayerScrim.dim : LayerScrim.soft,
      dismissOnScrim: true,
      onDismiss: onDismiss,
      child: SessionEntryNotice(
        kicker: 'Before you join',
        title: "You're all set for $sessionName.",
        onDone: onDismiss,
        children: [
          Text.rich(
            TextSpan(
              style: body,
              children: [
                const TextSpan(text: 'You can join beginning at '),
                TextSpan(text: joinTime, style: strong),
                const TextSpan(
                  text:
                      '. In the meantime, grab some water, get comfortable, or review our ',
                ),
                Button.inlineSpan(
                  text: 'Community Guidelines',
                  style: body,
                  onPressed: onGuidelines,
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Waiting room: preview and copy first, media bar last. Phone puts the
/// bar in the thumb zone. Wide frames keep the three pieces as one centered
/// group with more air.
class _WaitShell extends StatelessWidget {
  const _WaitShell({
    required this.participantName,
    this.previewPhoto,
    this.onBack,
    required this.media,
    required this.card,
  });

  final String participantName;
  final ImageProvider? previewPhoto;
  final VoidCallback? onBack;
  final _Media media;
  final Widget card;

  @override
  Widget build(BuildContext context) => SessionWaitingView(
    onLeave: onBack,
    preview: ParticipantCard(
      name: participantName,
      photo: media.cameraOn ? previewPhoto : null,
      showTalkingPiece: true,
      showMore: false,
    ),
    card: card,
    controls: _MediaBar(media: media),
  );
}

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.participantName,
    this.previewPhoto,
    required this.late,
    required this.expiresLabel,
    required this.media,
    this.onLeave,
  });

  final String participantName;
  final ImageProvider? previewPhoto;
  final bool late;
  final String? expiresLabel;
  final _Media media;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final label = expiresLabel;
    final Widget body;
    if (!late) {
      body = const Text('Check your camera and microphone while you wait.');
    } else if (label == null) {
      body = const Text('Join and your Keeper will bring you in.');
    } else {
      body = Text.rich(
        TextSpan(
          text: 'Please wait,\nwe will let you know in ',
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: ' min'),
          ],
        ),
      );
    }

    return _WaitShell(
      participantName: participantName,
      previewPhoto: previewPhoto,
      onBack: onLeave,
      media: media,
      card: SessionWaitingCard(
        title: late
            ? 'Keeper is reviewing your request to join'
            : "We're getting the room ready for you",
        body: body,
        actionLabel: 'Cancel request and leave',
        onAction: onLeave,
      ),
    );
  }
}

class _WaitingRoom extends StatelessWidget {
  const _WaitingRoom({
    required this.media,
    required this.participantName,
    this.previewPhoto,
    required this.sessionName,
    required this.startTime,
  });

  final _Media media;
  final String participantName;
  final ImageProvider? previewPhoto;
  final String sessionName;
  final String startTime;

  @override
  Widget build(BuildContext context) {
    return _WaitShell(
      participantName: participantName,
      previewPhoto: previewPhoto,
      media: media,
      card: SessionWaitingCard(
        title: "You're in.",
        body: Text(
          '$sessionName begins at $startTime. Settle in. The circle opens then.',
        ),
      ),
    );
  }
}

class _Declined extends StatefulWidget {
  const _Declined({
    required this.variant,
    this.offer,
    this.onSignUp,
    this.onBackToSpace,
  });

  final DeclineVariant variant;
  final Widget? offer;
  final VoidCallback? onSignUp;
  final VoidCallback? onBackToSpace;

  @override
  State<_Declined> createState() => _DeclinedState();
}

class _DeclinedState extends State<_Declined> {
  bool _signedUp = false;

  @override
  Widget build(BuildContext context) {
    final next = widget.variant == DeclineVariant.nextSession;

    return SessionDeclinedView(
      message: next
          ? "The next one is open."
          : "Nothing else is on the calendar yet. This one sits close to what you came for.",
      offer: widget.offer,
      actionLabel: next ? "Join the next session" : "Sign up for this session",
      signedUp: _signedUp,
      onSignUp: () {
        setState(() => _signedUp = true);
        widget.onSignUp?.call();
      },
      onBackToSpace: widget.onBackToSpace,
    );
  }
}

// ------------------------------------------------------------------
// Keeper prep
// ------------------------------------------------------------------

class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.name,
    required this.cameraOn,
    required this.micOn,
  });

  final String name;
  final bool cameraOn;
  final bool micOn;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(name);
    // min(220px, 70%), portrait 3:4.
    return FractionallySizedBox(
      widthFactor: 0.7,
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.lg),
                boxShadow: Shadows.elevation2,
                color: cameraOn ? null : TotemColors.coreSlate,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cameraOn) ...[
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            TotemColors.coreMauve,
                            TotemColors.extendedSteel,
                          ],
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: CssRadialGradient(
                          radius: const Size(0.8, 0.55),
                          center: const Offset(0.5, 0.22),
                          colors: [
                            TotemColors.extendedGold,
                            TotemColors.extendedGold.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.68],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tone.bg,
                          shape: BoxShape.circle,
                          boxShadow: Shadows.elevation1,
                        ),
                        child: Text(
                          _initial(name),
                          style: TotemText.h1.copyWith(
                            height: 1,
                            color: tone.fg,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Center(
                      child: IconTheme(
                        data: const IconThemeData(color: TotemColors.coreCream),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: Spacing.s8,
                          children: [
                            _StrokeIcon.cameraOff(),
                            Text(
                              'Camera is off',
                              style: TotemText.caption.copyWith(
                                color: TotemColors.coreCream,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!micOn)
                    Positioned(
                      left: Spacing.s12,
                      bottom: Spacing.s12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: Spacing.s4,
                          horizontal: Spacing.s8,
                        ),
                        decoration: BoxDecoration(
                          color: TotemColors.overlaySlate70,
                          borderRadius: BorderRadius.circular(Radii.full),
                        ),
                        child: Text(
                          'Muted',
                          style: TotemText.captionBold.copyWith(
                            color: TotemColors.coreCream,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeeperPrep extends StatelessWidget {
  const _KeeperPrep({
    required this.startTime,
    required this.joinTime,
    required this.keeperName,
    required this.phase,
    required this.requestCount,
    required this.media,
    required this.waitingCount,
    this.onWaiting,
  });

  final String startTime;
  final String joinTime;
  final String keeperName;
  final EntryPhase phase;
  final int requestCount;
  final _Media media;
  final int waitingCount;
  final VoidCallback? onWaiting;

  @override
  Widget build(BuildContext context) {
    final wide = _Breakpoints.of(context).wide;
    final roomIsEmpty = phase != EntryPhase.tooEarly && requestCount == 0;
    final copyWidth = BoxConstraints(maxWidth: wide ? 420 : double.infinity);

    return Semantics(
      container: true,
      label: 'Prepare the room',
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: wide
                  ? const EdgeInsets.all(Spacing.s48)
                  : const EdgeInsets.fromLTRB(
                      Spacing.s20,
                      72,
                      Spacing.s20,
                      Spacing.s20,
                    ),
              child: Column(
                spacing: Spacing.s16,
                children: [
                  Text('KEEPER', style: _kicker(context)),
                  ConstrainedBox(
                    constraints: copyWidth,
                    child: Semantics(
                      header: true,
                      child: Text(
                        'The room is yours until $startTime.',
                        textAlign: TextAlign.center,
                        style: _title(context),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: copyWidth,
                    child: Text(
                      'People can join from $joinTime. Nothing is shared with them until you admit them.',
                      textAlign: TextAlign.center,
                      style: _muted(context),
                    ),
                  ),
                  if (roomIsEmpty)
                    ConstrainedBox(
                      constraints: copyWidth,
                      child: Text(
                        "You'll see people here when they join.",
                        textAlign: TextAlign.center,
                        style: _muted(context),
                      ),
                    ),
                  _Portrait(
                    name: keeperName,
                    cameraOn: media.cameraOn,
                    micOn: media.micOn,
                  ),
                  // The bar sinks to the bottom; the copy stays up top.
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.s16),
                        child: _MediaBar(
                          media: media,
                          waitingCount: waitingCount,
                          onWaiting: onWaiting,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../components/button/button.dart';
import '../../components/participant_card/participant_card.dart';
import '../../components/session_card/session_card.dart';
import '../../components/session_controls/session_controls.dart';
import '../../components/waiting_card/waiting_card.dart';
import '../../paint.dart';
import '../../pressable.dart';
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

const _spaceName = 'Shame & Self-Worth';
const _sessionName = 'Letting Shame Fall Away';
const _keeperName = 'Vanessa';
const _startDateLabel = 'Wednesday, February 11th';
const _startTime = '6:30 PM GMT';
const _joinTime = '6:20 PM GMT';
const _prompt = 'What are you ready to set down?';
const _youName = 'Alex';

const _details = 'assets/design/session_entry';
const _previewPhoto = AssetImage('assets/design/participant_card/preview.jpg');

typedef _Offer = ({
  String name,
  String space,
  String keeper,
  ImageProvider? keeperPhoto,
  ImageProvider photo,
  String time,
  String meridiem,
  int seatsLeft,
});

const _Offer _nextSession = (
  name: 'After the Storm',
  space: _spaceName,
  keeper: 'Vanessa',
  keeperPhoto: AssetImage('$_details/avatar-vanessa.png'),
  photo: AssetImage('assets/design/session_card/photo.jpg'),
  time: '6:30',
  meridiem: 'PM',
  seatsLeft: 5,
);

const _Offer _relatedSession = (
  name: 'Holding the Hard Thing',
  space: _spaceName,
  keeper: 'Jonah',
  keeperPhoto: null,
  photo: AssetImage('$_details/similar.jpg'),
  time: '7:00',
  meridiem: 'PM',
  seatsLeft: 3,
);

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

TextStyle _subtitle(BuildContext context) => TotemText.h3.copyWith(
  letterSpacing: -0.27,
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
        "You're all set for $_sessionName. Join Session is available at $_joinTime.",
      EntryStatus.browsing => 'Join Session is available.',
      EntryStatus.lobby when late =>
        "This Session is already in progress. You're waiting to be admitted.",
      EntryStatus.lobby =>
        "We're getting the room ready. You're waiting to be admitted.",
      EntryStatus.waitingRoom => "You're in the waiting room.",
      EntryStatus.inSession => "You're in the Session.",
      EntryStatus.declined =>
        'This Session is no longer available for admission.',
    };
  }

  void _onEscape() {
    if (widget.showOrientation) {
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
        final coverOpen = widget.panelOpen || widget.showOrientation;

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
            showAlex: widget.status == EntryStatus.inSession,
            media: _media,
            waitingCount: _waitingCount,
            onWaiting: widget.onOpenPanel,
          )
        else
          _KeeperPrep(
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
        phase: widget.phase,
        onJoin: widget.onJoin,
        onBack: widget.onBackToSpace,
      ),
      EntryStatus.lobby => _Lobby(
        late: widget.phase == EntryPhase.inProgress,
        expiresLabel: widget.expiresLabel,
        media: _media,
        onLeave: widget.onLeaveLobby,
      ),
      EntryStatus.waitingRoom => _WaitingRoom(media: _media),
      EntryStatus.inSession => Stack(
        fit: StackFit.expand,
        children: [
          _Room(showAlex: true, media: _media, waitingCount: 0),
          _Orientation(
            open: widget.showOrientation,
            onDismiss: widget.onDismissOrientation,
          ),
        ],
      ),
      EntryStatus.declined => _Declined(
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

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.label,
    required this.onTap,
    required this.icon,
    required this.size,
    this.background,
    this.shadow,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget icon;
  final double size;
  final Color? background;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final theme = TotemTheme.of(context);
    return Pressable(
      onTap: onTap ?? () {},
      pressedScale: 0.97,
      focusColor: theme.accent,
      focusRadius: BorderRadius.circular(Radii.full),
      semanticLabel: label,
      builder: (context, states) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          boxShadow: shadow,
        ),
        child: IconTheme(
          data: IconThemeData(color: theme.textPrimary),
          child: icon,
        ),
      ),
    );
  }
}

/// Stroke icons drawn from the Figma paths. Color follows [IconTheme].
class _StrokeIcon extends StatelessWidget {
  const _StrokeIcon._(this.size, this.viewBox, this.paint);

  factory _StrokeIcon.chevron() => const _StrokeIcon._(18, 18, _chevron);
  factory _StrokeIcon.close() => const _StrokeIcon._(16, 16, _close);
  factory _StrokeIcon.cameraOff() => const _StrokeIcon._(22, 24, _cameraOff);

  final double size;
  final double viewBox;
  final void Function(Canvas canvas, Paint paint) paint;

  static void _chevron(Canvas canvas, Paint paint) {
    paint.strokeWidth = 1.8;
    canvas.drawPath(
      Path()
        ..moveTo(11.5, 3.5)
        ..lineTo(6, 9)
        ..lineTo(11.5, 14.5),
      paint,
    );
  }

  static void _close(Canvas canvas, Paint paint) {
    paint.strokeWidth = 1.8;
    canvas.drawLine(const Offset(3.5, 3.5), const Offset(12.5, 12.5), paint);
    canvas.drawLine(const Offset(12.5, 3.5), const Offset(3.5, 12.5), paint);
  }

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

class _Avatar extends StatelessWidget {
  const _Avatar(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(name);
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
        child: Text(
          _initial(name),
          style: TotemText.bodyBold.copyWith(height: 1, color: tone.fg),
        ),
      ),
    );
  }
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

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.requests,
    this.onAdmit,
    this.onAdmitAll,
    this.onDeclineRequest,
    this.onDismiss,
  });

  final List<AdmissionRequest> requests;
  final ValueChanged<String>? onAdmit;
  final VoidCallback? onAdmitAll;
  final ValueChanged<String>? onDeclineRequest;
  final VoidCallback? onDismiss;

  String get _countLabel => switch (requests.length) {
    0 => 'No one is waiting',
    1 => '1 person',
    final count => '$count people',
  };

  @override
  Widget build(BuildContext context) {
    final wide = _Breakpoints.of(context).wide;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.s16,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Spacing.s12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Waiting to join', style: _subtitle(context)),
                  ),
                  Text(_countLabel, style: _muted(context)),
                ],
              ),
            ),
            _IconButton(
              label: 'Close admission',
              onTap: onDismiss,
              size: 36,
              background: fade(TotemColors.coreSlate, 0.08),
              icon: _StrokeIcon.close(),
            ),
          ],
        ),
        if (requests.isEmpty)
          Text("You're clear. No one is waiting.", style: _muted(context))
        else ...[
          // One person is a single decision. A group gets one action that
          // lets everyone in, without hiding the per-person buttons.
          if (requests.length > 1)
            Button(
              onPressed: onAdmitAll ?? () {},
              block: true,
              child: const Text('Admit all'),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Spacing.s12,
            children: [
              for (final request in requests) _request(context, request, wide),
            ],
          ),
        ],
      ],
    );
  }

  Widget _request(BuildContext context, AdmissionRequest request, bool wide) {
    final decline = Button(
      variant: ButtonVariant.secondary,
      size: ButtonSize.compact,
      block: !wide,
      onPressed: () => onDeclineRequest?.call(request.id),
      child: const Text('Decline'),
    );
    final admit = Button(
      size: ButtonSize.compact,
      block: !wide,
      onPressed: () => onAdmit?.call(request.id),
      child: const Text('Admit'),
    );
    final person = [
      _Avatar(request.name),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.name,
              style: TotemText.bodyBold.copyWith(
                color: TotemTheme.of(context).textPrimary,
              ),
            ),
            Text('Expires in ${request.expiresLabel}', style: _muted(context)),
          ],
        ),
      ),
    ];

    // Wide rows fit the actions beside the name. Narrow stacks them below.
    if (wide) {
      return Row(
        spacing: Spacing.s12,
        children: [
          ...person,
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Spacing.s8,
            children: [decline, admit],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Spacing.s8,
      children: [
        Row(spacing: Spacing.s12, children: person),
        Row(
          spacing: Spacing.s8,
          children: [
            Expanded(child: decline),
            Expanded(child: admit),
          ],
        ),
      ],
    );
  }
}

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
      child: _RequestList(
        requests: requests,
        onAdmit: onAdmit,
        onAdmitAll: onAdmitAll,
        onDeclineRequest: onDeclineRequest,
        onDismiss: onDismiss,
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
    final theme = TotemTheme.of(context);
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
                child: Pressable(
                  onTap: widget.onWaiting ?? () {},
                  pressedScale: 0.97,
                  focusColor: theme.accent,
                  focusRadius: BorderRadius.circular(Radii.full),
                  builder: (context, states) => Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: Spacing.s8,
                      horizontal: Spacing.s16,
                    ),
                    decoration: BoxDecoration(
                      color: TotemColors.extendedGold,
                      borderRadius: BorderRadius.circular(Radii.full),
                      boxShadow: Shadows.elevation1,
                    ),
                    child: Text(
                      count == 1 ? '1 person waiting' : '$count people waiting',
                      style: TotemText.buttonSmall.copyWith(
                        color: TotemColors.coreSlate,
                      ),
                    ),
                  ),
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

String _cardLabel(String name) => name == _youName ? '$_youName (you)' : name;

/// Same arrangement as the live call. Narrow: the speaker sits on top,
/// everyone else in two columns. Wide: the speaker fills the left, the rest
/// fill the grid on the right. Web: Figma 3800:10532 — speaker 391 × 461,
/// gallery 4 × 2 with 20px gutters, 40px from the speaker.
/// Names stay at the bottom of each card. No stats overlay.
class _Room extends StatelessWidget {
  const _Room({
    required this.showAlex,
    required this.media,
    required this.waitingCount,
    this.onWaiting,
  });

  final bool showAlex;
  final _Media media;
  final int waitingCount;
  final VoidCallback? onWaiting;

  @override
  Widget build(BuildContext context) {
    final sizes = _Breakpoints.of(context);
    final people = [..._circle, if (showAlex) (name: _youName, feature: false)];
    final feature = people.where((person) => person.feature).firstOrNull;
    final rest = [
      for (final person in people.where((person) => !person.feature))
        // Same tile as the waiting-room preview — the shared red → blue
        // wash when there's no picture.
        ParticipantCard(name: _cardLabel(person.name)),
    ];
    final speaker = feature == null
        ? null
        : ParticipantCard(
            name: _cardLabel(feature.name),
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
      label: 'Session',
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

/// Title, copy, and one full-width "Got it". Wide frames hug the button.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.kicker,
    required this.title,
    required this.children,
    this.onDone,
  });

  final String kicker;
  final String title;
  final List<Widget> children;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final wide = _Breakpoints.of(context).wide;
    final done = Button(
      onPressed: onDone ?? () {},
      block: !wide,
      child: const Text('Got it'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Spacing.s12,
      children: [
        Text(kicker.toUpperCase(), style: _kicker(context)),
        Semantics(header: true, child: Text(title, style: _subtitle(context))),
        ...children,
        if (wide)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140),
            child: done,
          )
        else
          SizedBox(width: double.infinity, child: done),
      ],
    );
  }
}

class _Orientation extends StatelessWidget {
  const _Orientation({required this.open, this.onDismiss});

  final bool open;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = TotemTheme.of(context);
    final wide = _Breakpoints.of(context).wide;
    return EntryLayer(
      key: ValueKey(wide),
      open: open,
      kind: wide ? LayerKind.modal : LayerKind.sheet,
      label: "You're joining a Session already in progress",
      scrim: wide ? LayerScrim.dim : LayerScrim.soft,
      onDismiss: onDismiss,
      child: _Notice(
        kicker: 'Joining',
        title: "You're joining a Session already in progress.",
        onDone: onDismiss,
        children: [
          Text(
            'CURRENT PROMPT',
            style: TotemText.captionBold.copyWith(
              letterSpacing: 0.48,
              color: theme.textSecondary,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.s16),
            decoration: BoxDecoration(
              color: theme.canvas,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Text(_prompt, style: _subtitle(context)),
          ),
          Text(
            "You'll receive the talking piece when it's your turn to share.",
            style: _muted(context),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Participant screens
// ------------------------------------------------------------------

/// Before joining: the Session details screen, plus the Community
/// Guidelines sheet (narrow) or modal (wide) it can open.
class _PreSession extends StatefulWidget {
  const _PreSession({required this.phase, this.onJoin, this.onBack});

  final EntryPhase phase;
  final VoidCallback? onJoin;
  final VoidCallback? onBack;

  @override
  State<_PreSession> createState() => _PreSessionState();
}

class _PreSessionState extends State<_PreSession> {
  bool _guideOpen = false;

  void _close() => setState(() => _guideOpen = false);

  @override
  Widget build(BuildContext context) {
    final wide = _Breakpoints.of(context).wide;
    final bullet = TotemText.body.copyWith(
      color: TotemTheme.of(context).textPrimary,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        SessionDetails(
          phase: widget.phase,
          spaceName: _spaceName,
          sessionName: _sessionName,
          keeperName: _keeperName,
          dateLabel: _startDateLabel,
          timeLabel: _startTime,
          joinTime: _joinTime,
          onJoin: widget.onJoin,
          onBack: widget.onBack,
          onGuidelines: () => setState(() => _guideOpen = true),
        ),
        EntryLayer(
          key: ValueKey(wide),
          open: _guideOpen,
          kind: wide ? LayerKind.modal : LayerKind.sheet,
          label: 'Community Guidelines',
          scrim: wide ? LayerScrim.dim : LayerScrim.soft,
          onDismiss: _close,
          child: _Notice(
            kicker: 'Before you enter',
            title: 'Community Guidelines',
            onDone: _close,
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

/// Waiting room: preview and copy first, media bar last. Phone puts the
/// bar in the thumb zone. Wide frames keep the three pieces as one centered
/// group with more air.
class _WaitShell extends StatelessWidget {
  const _WaitShell({this.onBack, required this.media, required this.card});

  /// Back stays pinned above the group. Leave off to hide it.
  final VoidCallback? onBack;
  final _Media media;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    final wide = _Breakpoints.of(context).wide;
    final gap = wide ? Spacing.s24 : Spacing.s16;
    final onBack = this.onBack;

    return Semantics(
      container: true,
      label: 'Waiting room',
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              TotemColors.coreCream,
              TotemColors.coreCream,
              TotemColors.coreMauve,
            ],
            stops: [0, 0.42, 1],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: wide
                    ? const EdgeInsets.symmetric(
                        vertical: Spacing.s24,
                        horizontal: Spacing.s40,
                      )
                    : const EdgeInsets.fromLTRB(
                        Spacing.s16,
                        Spacing.s12,
                        Spacing.s16,
                        28,
                      ),
                child: Column(
                  spacing: wide ? Spacing.s16 : Spacing.s12,
                  children: [
                    if (onBack != null)
                      SizedBox(
                        height: 35,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.s8,
                          ),
                          // Drawn 30px in Figma; 44pt is the HIG floor.
                          child: OverflowBox(
                            maxHeight: 44,
                            alignment: Alignment.centerLeft,
                            child: _IconButton(
                              label: 'Leave',
                              onTap: onBack,
                              size: 44,
                              background: TotemColors.coreWhite,
                              shadow: Shadows.elevation1,
                              icon: _StrokeIcon.chevron(),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: gap,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: wide ? 420 : double.infinity,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                spacing: gap,
                                children: [
                                  // Same tile as the circle, locked to the Figma
                                  // 234 × 280.8 waiting-for-approval still. Talking
                                  // piece on, more off — this is your camera, not a
                                  // per-person menu.
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 234,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 280.8,
                                      child: ParticipantCard(
                                        name: _youName,
                                        photo: media.cameraOn
                                            ? _previewPhoto
                                            : null,
                                        showTalkingPiece: true,
                                        showMore: false,
                                      ),
                                    ),
                                  ),
                                  card,
                                ],
                              ),
                            ),
                            _MediaBar(media: media),
                          ],
                        ),
                      ),
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

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.late,
    required this.expiresLabel,
    required this.media,
    this.onLeave,
  });

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
      onBack: onLeave ?? () {},
      media: media,
      card: WaitingCard(
        title: late
            ? 'Keeper is reviewing your request to join'
            : "We're getting the room ready for you",
        body: body,
        action: Button(
          variant: ButtonVariant.secondary,
          // Same as design CSS: the waiting-card action is a 300-wide pill.
          block: true,
          onPressed: onLeave ?? () {},
          child: const Text('Cancel request and leave'),
        ),
      ),
    );
  }
}

class _WaitingRoom extends StatelessWidget {
  const _WaitingRoom({required this.media});

  final _Media media;

  @override
  Widget build(BuildContext context) {
    return _WaitShell(
      media: media,
      card: const WaitingCard(
        title: "You're in.",
        body: Text(
          '$_sessionName begins at $_startTime. Settle in. The circle opens then.',
        ),
      ),
    );
  }
}

class _Declined extends StatefulWidget {
  const _Declined({required this.variant, this.onSignUp, this.onBackToSpace});

  final DeclineVariant variant;
  final VoidCallback? onSignUp;
  final VoidCallback? onBackToSpace;

  @override
  State<_Declined> createState() => _DeclinedState();
}

class _DeclinedState extends State<_Declined> {
  bool _signedUp = false;

  @override
  Widget build(BuildContext context) {
    final wide = _Breakpoints.of(context).wide;
    final next = widget.variant == DeclineVariant.nextSession;
    final offer = next ? _nextSession : _relatedSession;

    final signUp = Button(
      block: !wide,
      onPressed: _signedUp
          ? null
          : () {
              setState(() => _signedUp = true);
              widget.onSignUp?.call();
            },
      child: Text(
        _signedUp
            ? "You're signed up"
            : next
            ? 'Join the Next Session'
            : 'Sign up for this Session',
      ),
    );

    return Semantics(
      container: true,
      label: 'Session unavailable',
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Spacing.s32,
                horizontal: Spacing.s20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: Spacing.s16,
                    children: [
                      Text('SESSION', style: _kicker(context)),
                      Semantics(
                        header: true,
                        child: Text(
                          "We're sorry, this Session is no longer available for admission, "
                          "but we'd love to see you soon.",
                          style: _title(context),
                        ),
                      ),
                      Text(
                        next
                            ? 'The next one is open.'
                            : 'Nothing else is on the calendar yet. This one sits close to what you came for.',
                        style: _muted(context),
                      ),
                      SessionCard(
                        photo: offer.photo,
                        spaceName: offer.space,
                        sessionName: offer.name,
                        keeperName: offer.keeper,
                        keeperPhoto: offer.keeperPhoto,
                        time: offer.time,
                        meridiem: offer.meridiem,
                        seatsLeft: offer.seatsLeft,
                      ),
                      Column(
                        spacing: Spacing.s8,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (wide)
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 240,
                                ),
                                child: signUp,
                              ),
                            )
                          else
                            signUp,
                          Center(
                            child: Button(
                              variant: ButtonVariant.text,
                              onPressed: widget.onBackToSpace ?? () {},
                              child: const Text('Return to the Space'),
                            ),
                          ),
                        ],
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
    required this.phase,
    required this.requestCount,
    required this.media,
    required this.waitingCount,
    this.onWaiting,
  });

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
                        'The room is yours until $_startTime.',
                        textAlign: TextAlign.center,
                        style: _title(context),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: copyWidth,
                    child: Text(
                      'People can join from $_joinTime. Nothing is shared with them until you admit them.',
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
                    name: _keeperName,
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

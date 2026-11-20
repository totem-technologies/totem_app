import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:totem_core/core/config/theme.dart';

/// Rotating grounding tips shown while a participant waits for a session,
/// both before the Keeper admits them and in the room's waiting state.
///
/// The first tip shows at once. It stays for [tipDuration] and fades out.
/// After [tipDelay], the next tip fades in and stays for [tipDuration].
/// With reduced motion, tips swap in place without fading, on the same
/// cadence.
///
/// Rotation pauses on the current tip while it's hovered or focused. It
/// doesn't rotate at all while a screen reader or switch control is in use.
///
/// The marquee always reserves the height of its tallest tip, so rotating
/// between shorter and longer tips never moves the controls around it.
class GroundingMarquee extends StatefulWidget {
  const GroundingMarquee({this.initialIndex, this.maxLines, super.key});

  /// Every tip, in rotation order. Phones show all of them; other devices
  /// skip [phoneOnlyTips]. See [tipsFor].
  static const tips = <String>[
    'Now is a good time to get settled, whatever that looks like for you.',
    'We listen without interrupting and speak without being interrupted.',
    'Put on headphones if background noise is distracting.',
    _phoneBatteryTip,
    'Stretch or shift positions whenever you need to.',
    'No small talk is required here.',
    'Close any tabs or apps that might interrupt you.',
    'Your perspective matters here.',
    'Healing happens in community.',
    'Come as you are, not as you think you should be.',
    'Totem is community-led.',
    'You don’t need to calm yourself perfectly.',
    'You can turn your camera off if needed.',
    'Share what feels right.',
    'It’s always acceptable to pass.',
  ];

  static const _phoneBatteryTip =
      'Keep your phone plugged in if your battery is low.';

  /// Tips that only make sense on a phone.
  static const phoneOnlyTips = <String>{_phoneBatteryTip};

  /// The tips shown on [platform], in rotation order.
  ///
  /// Web reports the browser's OS, so mobile browsers count as phones and
  /// desktop browsers don't.
  static List<String> tipsFor(TargetPlatform platform) {
    final isPhone =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    if (isPhone) return tips;
    return [
      for (final tip in tips)
        if (!phoneOnlyTips.contains(tip)) tip,
    ];
  }

  /// How long each tip stays fully visible.
  static const tipDuration = Duration(seconds: 5);

  /// Pause between one tip fading out and the next one fading in.
  static const tipDelay = Duration(seconds: 3);

  /// Length of each fade in and fade out.
  static const fadeDuration = Duration(milliseconds: 350);

  /// The first tip shown, wrapped into the platform's tips. Defaults to a
  /// random tip.
  final int? initialIndex;

  /// Lines each tip may take before it's cut with an ellipsis. Also caps
  /// the reserved height. Unlimited by default.
  final int? maxLines;

  @override
  State<GroundingMarquee> createState() => _GroundingMarqueeState();
}

class _GroundingMarqueeState extends State<GroundingMarquee>
    with SingleTickerProviderStateMixin {
  /// Time from one tip starting to appear until the next one does.
  static final Duration _cycle =
      GroundingMarquee.fadeDuration * 2 +
      GroundingMarquee.tipDuration +
      GroundingMarquee.tipDelay;

  late final List<String> _tips;
  late final AnimationController _fadeController;
  late final CurvedAnimation _opacity;
  late int _index;
  Timer? _timer;
  bool _started = false;
  bool _reduceMotion = false;
  bool _accessibleNavigation = false;
  bool _hovered = false;
  bool _focused = false;

  bool get _paused => _hovered || _focused || _accessibleNavigation;

  @override
  void initState() {
    super.initState();
    _tips = GroundingMarquee.tipsFor(defaultTargetPlatform);
    _index =
        (widget.initialIndex ?? Random().nextInt(_tips.length)) % _tips.length;
    _fadeController = AnimationController(
      vsync: this,
      duration: GroundingMarquee.fadeDuration,
      // The first tip is already visible instead of fading in from blank.
      value: 1,
    );
    _opacity = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final accessibleNavigation = MediaQuery.accessibleNavigationOf(context);
    if (_started &&
        reduceMotion == _reduceMotion &&
        accessibleNavigation == _accessibleNavigation) {
      return;
    }
    _started = true;
    _reduceMotion = reduceMotion;
    _accessibleNavigation = accessibleNavigation;
    // Starts the first tip, or restarts the current one in the new mode.
    _holdCurrentTip();
  }

  /// Shows the current tip in full and, unless rotation is paused, schedules
  /// the rest of its cycle.
  void _holdCurrentTip() {
    _timer?.cancel();
    _timer = null;
    var fadeIn = Duration.zero;
    if (_reduceMotion) {
      _fadeController.value = 1;
    } else if (!_fadeController.isCompleted) {
      _fadeController.forward();
      fadeIn = GroundingMarquee.fadeDuration;
    }
    if (_paused) return;
    _timer = _reduceMotion
        // Fades and the gap are spent showing the tip instead.
        ? Timer(_cycle, _nextTip)
        : Timer(fadeIn + GroundingMarquee.tipDuration, _hideTip);
  }

  void _hideTip() {
    if (!mounted) return;
    _fadeController.reverse();
    _timer = Timer(
      GroundingMarquee.fadeDuration + GroundingMarquee.tipDelay,
      _nextTip,
    );
  }

  void _nextTip() {
    if (!mounted) return;
    setState(() => _index = (_index + 1) % _tips.length);
    if (!_reduceMotion) _fadeController.value = 0;
    _holdCurrentTip();
  }

  void _setHovered(bool hovered) {
    if (!mounted || hovered == _hovered) return;
    final wasPaused = _paused;
    _hovered = hovered;
    if (_paused != wasPaused) _holdCurrentTip();
  }

  void _setFocused(bool focused) {
    if (!mounted || focused == _focused) return;
    final wasPaused = _paused;
    setState(() => _focused = focused);
    if (_paused != wasPaused) _holdCurrentTip();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _opacity.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tip = _tips[_index];
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        // Every tip is laid out but never painted or announced, so the
        // marquee is always as tall as its longest tip.
        ExcludeSemantics(
          child: Opacity(
            opacity: 0,
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                for (final text in _tips)
                  _Tip(text: text, maxLines: widget.maxLines),
              ],
            ),
          ),
        ),
        // Not a live region: screen readers read the current tip on focus
        // instead of being interrupted by every rotation.
        Semantics(
          container: true,
          label: 'Tip: $tip',
          // Focusable so keyboard users can hold a tip, like hovering does.
          child: Focus(
            onFocusChange: _setFocused,
            child: ExcludeSemantics(
              child: FadeTransition(
                opacity: _opacity,
                child: _Tip(
                  text: tip,
                  maxLines: widget.maxLines,
                  focused: _focused,
                  onHoverChanged: _setHovered,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({
    required this.text,
    this.maxLines,
    this.focused = false,
    this.onHoverChanged,
  });

  final String text;
  final int? maxLines;
  final bool focused;
  final ValueChanged<bool>? onHoverChanged;

  static const _outline = Color(0xFF987AA5);
  static const _radius = BorderRadius.all(Radius.circular(25));

  @override
  Widget build(BuildContext context) {
    Widget pill = Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F1E9),
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(color: _outline, blurRadius: 2),
          BoxShadow(color: Color(0x80F3F1E9), blurRadius: 11, spreadRadius: 5),
        ],
      ),
      // Painted over the pill so the focus ring never changes its size.
      foregroundDecoration: focused
          ? BoxDecoration(
              borderRadius: _radius,
              border: Border.all(color: _outline, width: 2),
            )
          : null,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w300,
          color: AppTheme.black,
        ),
      ),
    );
    final onHoverChanged = this.onHoverChanged;
    if (onHoverChanged != null) {
      pill = MouseRegion(
        onEnter: (_) => onHoverChanged(true),
        onExit: (_) => onHoverChanged(false),
        child: pill,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
        child: pill,
      ),
    );
  }
}

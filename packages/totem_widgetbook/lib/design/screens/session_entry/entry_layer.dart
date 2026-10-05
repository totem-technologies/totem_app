import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../paint.dart';
import '../../tokens/tokens.dart';

/// Sheet rises from the bottom and can be dragged down.
/// Panel is a drawer — it covers the Session, with a scrim, slides in from
/// the right, and can be dragged back out.
/// Modal scales in on a dimmed field.
enum LayerKind { sheet, panel, modal }

enum LayerScrim {
  /// Reads on cream and on the dark Session. Slate-on-slate was invisible.
  soft,
  dim,
  none,
}

/// Sheet spring. Damping 0.8, response 0.3s — a flick should carry, then
/// settle without a hard stop. A grab mid-flight restarts from the live value.
final _spring = () {
  const response = 0.3;
  const dampingRatio = 0.8;
  const omega = 2 * math.pi / response;
  return const SpringDescription(
    mass: 1,
    stiffness: omega * omega,
    damping: 2 * dampingRatio * omega,
  );
}();

/// The further past the edge, the less the sheet follows.
double rubberband(double overshoot, double dimension) {
  const constant = 0.55;
  final limit = math.max(dimension, 1.0);
  return (overshoot * limit * constant) / (limit + constant * overshoot.abs());
}

/// One presence animation for the three surfaces. Stays mounted while it
/// animates out, then removes itself.
class EntryLayer extends StatefulWidget {
  const EntryLayer({
    super.key,
    required this.open,
    required this.kind,
    required this.label,
    required this.scrim,
    this.dismissOnScrim = false,
    this.onDismiss,
    required this.child,
  });

  final bool open;
  final LayerKind kind;
  final String label;
  final LayerScrim scrim;
  final bool dismissOnScrim;
  final VoidCallback? onDismiss;
  final Widget child;

  @override
  State<EntryLayer> createState() => _EntryLayerState();
}

class _EntryLayerState extends State<EntryLayer>
    with SingleTickerProviderStateMixin {
  /// Pixels off the resting spot for the sheet and panel. Progress for the
  /// modal, where 1 is fully in.
  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
    value: widget.kind == LayerKind.modal ? 0 : 900,
  );
  final _slideKey = GlobalKey();

  bool _present = false;
  bool _wasOpen = false;
  double _handoffVelocity = 0;
  double _dragOrigin = 0;
  double _dragTravel = 0;

  bool get _isModal => widget.kind == LayerKind.modal;
  double get _resting => _isModal ? 1 : 0;

  double _parkedExtent = 480;

  /// Where the surface hides: its own size plus a little, so the shadow
  /// clears the edge too. Measured after layout by [_measure].
  double get _parked => _isModal ? 0 : _parkedExtent;

  void _measure() {
    final box = _slideKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final extent = widget.kind == LayerKind.panel
        ? box.size.width
        : box.size.height;
    _parkedExtent = extent > 0 ? extent + 28 : 480;
  }

  @override
  void initState() {
    super.initState();
    if (widget.open) _show();
  }

  @override
  void didUpdateWidget(EntryLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open == oldWidget.open) return;
    if (widget.open) {
      _show();
    } else {
      _hide();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _show() {
    _motion.stop();
    setState(() => _present = true);
    // Wait a frame so the surface has a size to slide in from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.open) return;
      _measure();
      final start = _wasOpen ? _motion.value : _parked;
      _wasOpen = true;
      _springTo(start, _resting, 0);
    });
  }

  void _hide() {
    if (!_wasOpen) return;
    _motion.stop();
    final velocity = _handoffVelocity;
    _handoffVelocity = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.open) return;
      _measure();
      _springTo(
        _motion.value,
        _parked,
        velocity,
        onRest: () {
          _wasOpen = false;
          setState(() => _present = false);
        },
      );
    });
  }

  void _springTo(
    double from,
    double to,
    double velocity, {
    VoidCallback? onRest,
  }) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || !from.isFinite || !to.isFinite) {
      _motion.value = to;
      onRest?.call();
      return;
    }
    final tolerance = _isModal
        ? const Tolerance(distance: 0.002, velocity: 0.05)
        : const Tolerance(distance: 0.5, velocity: 12);
    _motion.value = from;
    _motion
        .animateWith(
          SpringSimulation(_spring, from, to, velocity, tolerance: tolerance),
        )
        .whenComplete(() {
          if (!mounted) return;
          _motion.value = to;
          onRest?.call();
        });
  }

  // Drag from the grabber only, so Admit still clicks.
  // Sheet: down. Drawer: toward the right. Same spring handoff.

  void _onDragStart(DragStartDetails details) {
    _motion.stop();
    _measure();
    _dragOrigin = _motion.value;
    _dragTravel = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragTravel += details.primaryDelta ?? 0;
    var next = _dragOrigin + _dragTravel;
    if (next < 0) next = -rubberband(-next, _parked);
    _motion.value = next;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldDismiss = _motion.value > _parked * 0.28 || velocity > 650;
    final onDismiss = widget.onDismiss;
    if (shouldDismiss && onDismiss != null) {
      _handoffVelocity = velocity;
      onDismiss();
      return;
    }
    _springTo(_motion.value, _resting, velocity);
  }

  @override
  Widget build(BuildContext context) {
    if (!_present) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _motion,
      builder: (context, _) {
        final offset = _motion.value;
        final scrimOpacity = _isModal
            ? offset.clamp(0.0, 1.0)
            : (_parked <= 0 ? 1.0 : (1 - offset / _parked).clamp(0.0, 1.0));

        return Stack(
          fit: StackFit.expand,
          children: [
            if (widget.scrim != LayerScrim.none)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.dismissOnScrim ? widget.onDismiss : null,
                child: Opacity(
                  opacity: scrimOpacity,
                  child: ColoredBox(
                    color: widget.scrim == LayerScrim.soft
                        ? const Color(0x66000000)
                        : TotemColors.overlaySlate60,
                  ),
                ),
              ),
            BlockSemantics(
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: widget.label,
                child: _placed(offset),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _placed(double offset) {
    final theme = TotemTheme.of(context);
    final ink = DefaultTextStyle.of(
      context,
    ).style.copyWith(color: theme.textPrimary);

    switch (widget.kind) {
      case LayerKind.sheet:
        return Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.78,
            alignment: Alignment.bottomCenter,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Container(
                  key: _slideKey,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Radii.lg),
                    ),
                    boxShadow: Shadows.elevation2,
                  ),
                  child: DefaultTextStyle(
                    style: ink,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.s20,
                        Spacing.s4,
                        Spacing.s20,
                        Spacing.s32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Grabber(
                            horizontal: false,
                            onStart: _onDragStart,
                            onUpdate: _onDragUpdate,
                            onEnd: _onDragEnd,
                          ),
                          widget.child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

      case LayerKind.panel:
        // Flush top and right — no floating inset. Leading corners only.
        const radius = BorderRadius.horizontal(left: Radius.circular(Radii.lg));
        return Align(
          alignment: Alignment.centerRight,
          child: Transform.translate(
            offset: Offset(offset, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: DecoratedBox(
                key: _slideKey,
                decoration: const BoxDecoration(
                  borderRadius: radius,
                  boxShadow: Shadows.elevation2,
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: Shadows.frostedGlassBlur / 2,
                      sigmaY: Shadows.frostedGlassBlur / 2,
                    ),
                    child: ColoredBox(
                      color: fade(theme.surface, 0.94),
                      child: DefaultTextStyle(
                        style: ink,
                        child: Stack(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(Spacing.s20),
                                child: widget.child,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 20,
                              child: _Grabber(
                                horizontal: true,
                                onStart: _onDragStart,
                                onUpdate: _onDragUpdate,
                                onEnd: _onDragEnd,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

      case LayerKind.modal:
        final progress = math.max(0.0, offset);
        return Padding(
          padding: const EdgeInsets.all(Spacing.s24),
          child: Center(
            child: Opacity(
              opacity: math.min(1, progress),
              child: Transform.scale(
                scale: 0.96 + math.min(progress, 1.15) * 0.04,
                child: Container(
                  key: _slideKey,
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(Spacing.s24),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    boxShadow: Shadows.elevation2,
                  ),
                  child: DefaultTextStyle(style: ink, child: widget.child),
                ),
              ),
            ),
          ),
        );
    }
  }
}

/// A pill to grab. The sheet's sits on top; the drawer's is a rail on the
/// leading edge. Both drag 1:1 with the pointer.
class _Grabber extends StatelessWidget {
  const _Grabber({
    required this.horizontal,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final bool horizontal;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      width: horizontal ? 5 : 36,
      height: horizontal ? 36 : 5,
      decoration: BoxDecoration(
        color: fade(TotemColors.coreSlate, 0.18),
        borderRadius: BorderRadius.circular(Radii.full),
      ),
    );

    return ExcludeSemantics(
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: horizontal ? null : onStart,
          onVerticalDragUpdate: horizontal ? null : onUpdate,
          onVerticalDragEnd: horizontal ? null : onEnd,
          onHorizontalDragStart: horizontal ? onStart : null,
          onHorizontalDragUpdate: horizontal ? onUpdate : null,
          onHorizontalDragEnd: horizontal ? onEnd : null,
          child: horizontal
              ? Center(child: pill)
              : Padding(
                  padding: const EdgeInsets.only(
                    top: Spacing.s8,
                    bottom: Spacing.s12,
                  ),
                  child: Center(child: pill),
                ),
        ),
      ),
    );
  }
}

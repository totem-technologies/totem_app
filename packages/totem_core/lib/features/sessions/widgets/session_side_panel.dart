import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

/// Width of the desktop panel column from the video-session design.
const double sessionSidePanelWidth = 412;

/// Video plus a panel needs at least this much horizontal room.
const double sessionSidePanelDockMinWidth = 1100;

const Duration sessionSidePanelDuration = Duration(milliseconds: 320);
const Duration sessionSidePanelReverseDuration = Duration(milliseconds: 260);
const Curve sessionSidePanelCurve = Curves.easeOutCubic;

/// Whether a video-session panel should dock beside the video.
bool shouldDockSessionSidePanel(BuildContext context) {
  final kind = ViewportResolver.getViewportKind(context);
  final isTabletOrDesktop =
      kind == ViewportKind.mediumSmall || kind == ViewportKind.mediumPlus;
  return isTabletOrDesktop &&
      MediaQuery.sizeOf(context).width >= sessionSidePanelDockMinWidth;
}

/// Opens a trailing panel above the room navigator on non-docked layouts.
Future<void> showSessionSidePanelDrawer(
  BuildContext context, {
  required RouteSettings settings,
  required Widget child,
}) {
  return Navigator.of(context, rootNavigator: false).push<void>(
    _SessionSidePanelDrawerRoute(
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      settings: settings,
      child: child,
    ),
  );
}

class _SessionSidePanelDrawerRoute extends RawDialogRoute<void> {
  _SessionSidePanelDrawerRoute({
    required String barrierLabel,
    required RouteSettings settings,
    required Widget child,
  }) : super(
         settings: settings,
         barrierLabel: barrierLabel,
         barrierDismissible: true,
         barrierColor: Colors.black26,
         transitionDuration: sessionSidePanelDuration,
         transitionBuilder: _holdChild,
         pageBuilder: (context, animation, secondaryAnimation) => Align(
           alignment: AlignmentDirectional.centerEnd,
           child: _slideFromTrailing(
             context: context,
             animation: animation,
             child: _SessionSidePanelSurface(child: child),
           ),
         ),
       );

  static Widget _holdChild(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }

  @override
  Duration get reverseTransitionDuration => sessionSidePanelReverseDuration;
}

Widget _slideFromTrailing({
  required BuildContext context,
  required Animation<double> animation,
  required Widget child,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return SlideTransition(
    textDirection: Directionality.of(context),
    position: animation.drive(
      Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: sessionSidePanelCurve)),
    ),
    child: child,
  );
}

/// A controlled trailing rail that makes room for a video-session panel.
class DockedSessionSidePanel extends StatefulWidget {
  const DockedSessionSidePanel({
    required this.open,
    required this.child,
    super.key,
  });

  final bool open;
  final Widget? child;

  @override
  State<DockedSessionSidePanel> createState() => _DockedSessionSidePanelState();
}

class _DockedSessionSidePanelState extends State<DockedSessionSidePanel>
    with SingleTickerProviderStateMixin {
  Widget? _activeChild;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: sessionSidePanelDuration,
    reverseDuration: sessionSidePanelReverseDuration,
    value: widget.open ? 1 : 0,
  );

  @override
  void initState() {
    _activeChild = widget.child;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant DockedSessionSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null &&
        (oldWidget.child != widget.child || !oldWidget.open)) {
      _activeChild = widget.child;
    }
    if (oldWidget.open == widget.open) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.open ? 1 : 0;
    } else if (widget.open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _activeChild;
    // Keep the AnimatedBuilder mounted even without a child: it first reads
    // the lazy controller, which must exist before the panel opens.
    return AnimatedBuilder(
      animation: _controller,
      // Built once per open: only the rail's width animates, so the video
      // column makes room while the fixed-size panel rides its leading edge.
      // The repaint boundary inside lets the slide move the recorded layer
      // instead of re-recording the shadow and content every frame.
      child: child == null ? null : _SessionSidePanelSurface(child: child),
      builder: (context, slot) {
        if (slot == null ||
            (_controller.value == 0 && !_controller.isAnimating)) {
          return const SizedBox.shrink();
        }
        final width =
            sessionSidePanelWidth *
            sessionSidePanelCurve.transform(_controller.value);
        return SizedBox(
          width: width,
          height: double.infinity,
          // The shadow spills onto the video only as far as the panel has
          // slid in, so it appears and leaves with the panel.
          child: ClipRect(
            clipper: _RailClipper(
              shadowExtent: math.min(width, _sessionSidePanelShadowExtent),
              textDirection: Directionality.of(context),
            ),
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: sessionSidePanelWidth,
              maxWidth: sessionSidePanelWidth,
              child: slot,
            ),
          ),
        );
      },
    );
  }
}

/// How far [AppTheme.sessionPanelShadow] reaches past the panel's edge.
const double _sessionSidePanelShadowExtent = 48;

/// Clips the rail to its own bounds, plus room for the shadow on the
/// leading side.
class _RailClipper extends CustomClipper<Rect> {
  const _RailClipper({required this.shadowExtent, required this.textDirection});

  final double shadowExtent;
  final TextDirection textDirection;

  @override
  Rect getClip(Size size) => switch (textDirection) {
    TextDirection.ltr => Rect.fromLTRB(
      -shadowExtent,
      0,
      size.width,
      size.height,
    ),
    TextDirection.rtl => Rect.fromLTRB(
      0,
      0,
      size.width + shadowExtent,
      size.height,
    ),
  };

  @override
  bool shouldReclip(_RailClipper oldClipper) =>
      oldClipper.shadowExtent != shadowExtent ||
      oldClipper.textDirection != textDirection;
}

/// Full-height panel surface. A soft shadow separates its leading edge from
/// the session; the room clips the shadow at the screen edges.
class _SessionSidePanelSurface extends StatelessWidget {
  const _SessionSidePanelSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(boxShadow: AppTheme.sessionPanelShadow),
        // A Material ancestor for drawer children's ink and text fields.
        child: Material(
          color: AppTheme.cream,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: sessionSidePanelWidth,
            height: double.infinity,
            child: child,
          ),
        ),
      ),
    );
  }
}

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
             child: Material(
               color: AppTheme.cream,
               elevation: 6,
               shadowColor: const Color.fromRGBO(0, 0, 0, 0.16),
               clipBehavior: Clip.antiAlias,
               child: SizedBox(
                 width: sessionSidePanelWidth,
                 height: MediaQuery.sizeOf(context).height,
                 child: child,
               ),
             ),
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
  final Widget child;

  @override
  State<DockedSessionSidePanel> createState() => _DockedSessionSidePanelState();
}

class _DockedSessionSidePanelState extends State<DockedSessionSidePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: sessionSidePanelDuration,
    reverseDuration: sessionSidePanelReverseDuration,
    value: widget.open ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant DockedSessionSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.value == 0 && !_controller.isAnimating) {
          return const SizedBox.shrink();
        }
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            widthFactor: sessionSidePanelCurve.transform(_controller.value),
            child: SizedBox(
              width: sessionSidePanelWidth,
              height: MediaQuery.sizeOf(context).height,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

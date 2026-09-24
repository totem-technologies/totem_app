import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/session_chat_panel.dart';
import 'package:totem_core/shared/widgets/responsive_modal.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

export 'keeper_profile_sheet.dart';
export 'session_chat_panel.dart' show SessionChatPanel;

const String sessionChatRouteName = 'session-chat';

/// Width of the Figma desktop chat column.
const double sessionChatPanelWidth = 412;

/// Video plus 412px sidebar needs at least this much horizontal room.
const double sessionChatDockMinWidth = 1100;

/// Tap-to-open drawer timing. Ease-out cubic over ~0.3s approximates a
/// critically damped spring (no bounce — this isn't a flicked sheet).
const Duration sessionChatDrawerDuration = Duration(milliseconds: 320);

/// Slightly snappier on the way out so dismiss feels decisive.
const Duration sessionChatDrawerReverseDuration = Duration(milliseconds: 260);

const Curve sessionChatDrawerCurve = Curves.easeOutCubic;

/// Dock the panel on wide tablet/desktop. Phones and narrow tablets use a modal.
bool shouldDockSessionChat(BuildContext context) {
  final kind = ViewportResolver.getViewportKind(context);
  final isTabletOrDesktop =
      kind == ViewportKind.mediumSmall || kind == ViewportKind.mediumPlus;
  return isTabletOrDesktop &&
      MediaQuery.sizeOf(context).width >= sessionChatDockMinWidth;
}

Future<void> showSessionChat(BuildContext context) {
  switch (ViewportResolver.getViewportKind(context)) {
    case ViewportKind.smallPortrait:
    case ViewportKind.smallLandscape:
      // Phones already get the platform sheet slide; leave that path alone.
      return showResponsiveModal<void>(
        context: context,
        useRootNavigator: false,
        routeSettings: const RouteSettings(name: sessionChatRouteName),
        showDragHandle: false,
        useSafeArea: false,
        bottomSheetBackgroundColor: AppTheme.cream,
        dialogBackgroundColor: AppTheme.cream,
        dialogBarrierColor: Colors.black26,
        bottomSheetBuilder: (context) {
          return DraggableScrollableSheet(
            maxChildSize: 0.9,
            initialChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return SessionChatPanel(
                scrollController: scrollController,
                showDragHandle: true,
              );
            },
          );
        },
        largeScreenBuilder: (_) => const SizedBox.shrink(),
      );
    case ViewportKind.mediumSmall:
    case ViewportKind.mediumPlus:
      // Overlay drawer on the room navigator so it sits above the circle,
      // not the app shell, and dismisses with the room back gesture.
      return Navigator.of(context, rootNavigator: false).push<void>(
        _SessionChatDrawerRoute(
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          settings: const RouteSettings(name: sessionChatRouteName),
        ),
      );
  }
}

/// Trailing-edge overlay: the panel slides in from `Offset(1, 0)`, which
/// [SlideTransition] flips in RTL so it always arrives from the end edge.
///
/// The route's default fade is stripped — a drawer should materialize by
/// moving, not by dissolving. The barrier still fades with [animation].
class _SessionChatDrawerRoute extends RawDialogRoute<void> {
  _SessionChatDrawerRoute({
    required String barrierLabel,
    required RouteSettings settings,
  }) : super(
         settings: settings,
         barrierLabel: barrierLabel,
         barrierDismissible: true,
         barrierColor: Colors.black26,
         transitionDuration: sessionChatDrawerDuration,
         transitionBuilder: _holdChild,
         pageBuilder: _buildPage,
       );

  /// Identity transition so [RawDialogRoute] doesn't fade the page on top
  /// of the slide we apply in [_buildPage].
  static Widget _holdChild(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }

  static Widget _buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final panel = Material(
      color: AppTheme.cream,
      elevation: 6,
      shadowColor: const Color.fromRGBO(0, 0, 0, 0.16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: sessionChatPanelWidth,
        height: MediaQuery.sizeOf(context).height,
        child: const SessionChatPanel(),
      ),
    );

    // Slide the 412px panel, not a full-screen Dialog: Offset(1, 0) is then
    // one panel-width, so the drawer tucks in from the window edge.
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: _slideFromTrailing(
        context: context,
        animation: animation,
        child: panel,
      ),
    );
  }

  @override
  Duration get reverseTransitionDuration => sessionChatDrawerReverseDuration;
}

/// Shared drive: ease-out on the way in, and the same curve played backward
/// on dismiss so the path out mirrors the path in.
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
      ).chain(CurveTween(curve: sessionChatDrawerCurve)),
    ),
    child: child,
  );
}

/// Wide-window rail that grows from the trailing edge so the video yields
/// space instead of the drawer covering it. Stays mounted at width 0 while
/// closed so the close animation can play.
class DockedSessionChatRail extends ConsumerStatefulWidget {
  const DockedSessionChatRail({super.key});

  @override
  ConsumerState<DockedSessionChatRail> createState() =>
      _DockedSessionChatRailState();
}

class _DockedSessionChatRailState extends ConsumerState<DockedSessionChatRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final open = ref.read(sessionChatOpenProvider);
    _controller = AnimationController(
      vsync: this,
      duration: sessionChatDrawerDuration,
      reverseDuration: sessionChatDrawerReverseDuration,
      value: open ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(bool open) {
    // Reduce Motion: skip the slide and snap, matching Apple's cross-fade
    // guidance for vestibular safety.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = open ? 1 : 0;
      return;
    }
    if (open) {
      _controller.forward();
      return;
    }
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(sessionChatOpenProvider, (previous, next) {
      _animateTo(next);
    });

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Drop the panel once the close finishes so the composer isn't
        // sitting in an invisible 0-width rail.
        if (_controller.value == 0 && !_controller.isAnimating) {
          return const SizedBox.shrink();
        }

        // widthFactor + trailing alignment clips from the leading edge, so
        // the rail appears to slide in from the window's end while the Row
        // actually shrinks the video.
        final t = sessionChatDrawerCurve.transform(_controller.value);
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            widthFactor: t,
            child: const SizedBox(
              width: sessionChatPanelWidth,
              child: SessionChatPanel(embedded: true),
            ),
          ),
        );
      },
    );
  }
}

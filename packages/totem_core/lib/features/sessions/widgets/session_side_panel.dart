import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/shared/widgets/viewport_resolver.dart';

/// Width of the desktop panel column from the video-session design.
const double sessionSidePanelWidth = 412;

/// Docks the panel as a card over the room from this width up. Narrower,
/// the card would hide most of the session, so it opens as a drawer instead.
const double sessionSidePanelDockMinWidth = 1100;

/// Gap between the docked panel card and the room's top, trailing and bottom
/// edges.
const double sessionSidePanelInset = 12;

/// Matches the app's card radius.
const BorderRadius sessionSidePanelRadius = BorderRadius.all(
  Radius.circular(20),
);

const Duration sessionSidePanelDuration = Duration(milliseconds: 320);
const Duration sessionSidePanelReverseDuration = Duration(milliseconds: 260);
const Curve sessionSidePanelCurve = Curves.easeOutCubic;

/// Whether a video-session panel should dock as a card over the room.
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

/// A floating card for a video-session panel over the room's trailing edge.
///
/// Place it directly in a [Stack] above the room content, under the room's
/// routes so dialogs, menus and their barriers cover it. It positions itself
/// against the stack's top, trailing and bottom edges and covers whatever is
/// beneath; only the card itself takes pointers, so the room stays usable
/// around it and through the gaps.
///
/// The card slides in from the trailing edge while fading in. While it closes
/// it ignores input and drops focus, handing focus back to whatever held it
/// before the panel opened.
class DockedSessionSidePanel extends StatefulWidget {
  const DockedSessionSidePanel({
    required this.open,
    required this.child,
    this.onDismiss,
    super.key,
  });

  final bool open;
  final Widget? child;

  /// Called for Escape while focus is inside the panel.
  final VoidCallback? onDismiss;

  @override
  State<DockedSessionSidePanel> createState() => _DockedSessionSidePanelState();
}

class _DockedSessionSidePanelState extends State<DockedSessionSidePanel>
    with SingleTickerProviderStateMixin {
  Widget? _activeChild;

  /// Holds focus for the panel's subtree without taking it itself, so it
  /// tells whether focus is inside the panel.
  final FocusNode _panelFocus = FocusNode(
    debugLabel: 'DockedSessionSidePanel',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// Where focus goes back to once the panel closes.
  FocusNode? _returnFocus;

  late final AnimationController _controller;
  late final CurvedAnimation _progress;

  /// A full card width: the card starts just past the trailing edge.
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _activeChild = widget.child;
    // Created eagerly: a lazy controller first read after `open` flips would
    // start at its end value and skip the animation.
    _controller = AnimationController(
      vsync: this,
      duration: sessionSidePanelDuration,
      reverseDuration: sessionSidePanelReverseDuration,
      value: widget.open ? 1 : 0,
    )..addStatusListener(_handleStatus);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: sessionSidePanelCurve,
    );
    _slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(_progress);
  }

  @override
  void didUpdateWidget(covariant DockedSessionSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null &&
        (oldWidget.child != widget.child || !oldWidget.open)) {
      _activeChild = widget.child;
    }
    if (oldWidget.open == widget.open) return;
    if (widget.open) {
      _rememberReturnFocus();
    } else {
      _scheduleFocusReturn();
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.open ? 1 : 0;
    } else if (widget.open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _handleStatus(AnimationStatus status) {
    // Drop the card from the tree once it has slid away.
    if (status.isDismissed && mounted) setState(() {});
  }

  bool _isInsidePanel(FocusNode node) =>
      node == _panelFocus || node.ancestors.contains(_panelFocus);

  void _rememberReturnFocus() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && !_isInsidePanel(focus)) _returnFocus = focus;
  }

  void _scheduleFocusReturn() {
    if (!_panelFocus.hasFocus) return;
    final target = _returnFocus;
    _returnFocus = null;
    // After this frame: the closing card's ExcludeFocus unfocuses its
    // descendants during the rebuild, which would override an earlier
    // request.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (target == null || target.context == null) return;
      if (target.canRequestFocus) target.requestFocus();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _activeChild;
    final Widget card;
    if (child == null || _controller.isDismissed) {
      card = const SizedBox.shrink();
    } else {
      final closing = !widget.open;
      card = IgnorePointer(
        ignoring: closing,
        child: ExcludeFocus(
          excluding: closing,
          child: ExcludeSemantics(
            excluding: closing,
            // Transitions repaint the recorded card layer instead of
            // rebuilding it each frame.
            child: SlideTransition(
              position: _slide,
              textDirection: Directionality.of(context),
              child: FadeTransition(
                opacity: _progress,
                child: _FloatingSessionSidePanelCard(
                  focusNode: _panelFocus,
                  onDismiss: widget.onDismiss,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return PositionedDirectional(top: 0, end: 0, bottom: 0, child: card);
  }
}

/// The rounded, shadowed card inset from the room's top, trailing and bottom
/// edges and clear of the system bars.
class _FloatingSessionSidePanelCard extends StatelessWidget {
  const _FloatingSessionSidePanelCard({
    required this.focusNode,
    required this.onDismiss,
    required this.child,
  });

  final FocusNode focusNode;
  final VoidCallback? onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final endPadding = switch (Directionality.of(context)) {
      TextDirection.ltr => media.padding.right,
      TextDirection.rtl => media.padding.left,
    };
    final bottomGap = media.padding.bottom + sessionSidePanelInset;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: media.padding.top + sessionSidePanelInset,
        end: endPadding + sessionSidePanelInset,
        bottom: bottomGap,
      ),
      // The card already clears the system bars, and its bottom sits
      // [bottomGap] above where an on-screen keyboard starts.
      child: MediaQuery(
        data: media
            .removePadding(
              removeLeft: true,
              removeTop: true,
              removeRight: true,
              removeBottom: true,
            )
            .copyWith(
              viewInsets: media.viewInsets.copyWith(
                bottom: math.max(0, media.viewInsets.bottom - bottomGap),
              ),
            ),
        child: RepaintBoundary(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: sessionSidePanelRadius,
              boxShadow: AppTheme.sessionFloatingPanelShadow,
            ),
            // A Material ancestor for the panel's ink and text fields.
            child: Material(
              color: AppTheme.cream,
              borderRadius: sessionSidePanelRadius,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: sessionSidePanelWidth,
                height: double.infinity,
                // Read after the room, and Tab finishes the panel before
                // moving on. Not modal: the session stays usable.
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  sortKey: const OrdinalSortKey(1),
                  child: FocusTraversalGroup(
                    child: Focus(
                      focusNode: focusNode,
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.escape):
                              ?onDismiss,
                        },
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-height drawer surface below [sessionSidePanelDockMinWidth]. A soft
/// shadow separates its leading edge from the session.
///
/// Expects a bounded height from its parent (the drawer Align).
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

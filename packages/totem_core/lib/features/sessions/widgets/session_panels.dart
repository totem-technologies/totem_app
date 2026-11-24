import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/admission/session_admission_overlay.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_prompts_controller.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/screens/options/more_options_popup.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/session_keyboard_shortcuts.dart';
import 'package:totem_core/features/sessions/widgets/session_navigator_scope.dart';
import 'package:totem_core/features/sessions/widgets/session_prompts_modal.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/shared/router.dart';

class _SessionPanelRouteObserver extends NavigatorObserver {
  VoidCallback? onRoutesChanged;
  final List<Route<dynamic>> panelRoutes = [];
  final List<Route<dynamic>> transientRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) transientRoutes.add(route);
    switch (route.settings.name) {
      case sessionChatRouteName:
      case sessionPromptsRouteName:
      case sessionAdmissionRouteName:
        panelRoutes.add(route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    transientRoutes.remove(route);
    onRoutesChanged?.call();
    panelRoutes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    transientRoutes.remove(route);
    onRoutesChanged?.call();
    panelRoutes.remove(route);
  }
}

class _DockedSessionPanels extends ConsumerWidget {
  const _DockedSessionPanels({required this.sessionSlug, required this.panel});
  final SessionPanel panel;

  final String sessionSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatOpen = this.panel == SessionPanel.chat;
    final isKeeper = ref.watch(isCurrentUserKeeperProvider);
    final promptsOpen = isKeeper && this.panel == SessionPanel.prompts;
    final admissionOpen = isKeeper && this.panel == SessionPanel.admission;
    final Widget? panel = switch ((chatOpen, promptsOpen, admissionOpen)) {
      (true, _, _) => const SessionChatPanel(embedded: true),
      (false, true, _) => SessionPromptsModal(
        sessionSlug: sessionSlug,
        embedded: true,
      ),
      (false, false, true) => const SessionAdmissionPanel(docked: true),
      (false, false, false) => null,
    };

    return DockedSessionSidePanel(
      open: panel != null,
      onDismiss: () => closeDockedSessionPanel(ref),
      child: panel,
    );
  }
}

/// Closes the open session panel. Returns whether one was open.
bool closeDockedSessionPanel(WidgetRef ref) {
  if (ref.read(sessionPresentationProvider).panel == SessionPanel.none) {
    return false;
  }
  ref.read(sessionPresentationProvider.notifier).closePanel();
  return true;
}

/// Owns the room's nested routes and responsive panel presentation.
///
/// Keep this mounted around loading and ended views so pending presentation
/// callbacks and per-session panel state share the room's lifetime. Without an
/// active [session], [connectionState], and [roomStatus], only [child] is shown.
class SessionPanels extends ConsumerStatefulWidget {
  const SessionPanels({
    required this.sessionSlug,
    required this.child,
    this.session,
    this.connectionState,
    this.roomStatus,
    this.enableEmojiReactions = false,
    this.orientationBuilder,
    super.key,
  });

  final String sessionSlug;
  final Widget child;
  final SessionController? session;
  final RoomConnectionState? connectionState;
  final RoomStatus? roomStatus;
  final bool enableEmojiReactions;
  final Widget Function(BuildContext context, bool docked)? orientationBuilder;

  @override
  ConsumerState<SessionPanels> createState() => _SessionPanelsState();
}

class _SessionPanelsState extends ConsumerState<SessionPanels>
    with WidgetsBindingObserver {
  final _roomNavigatorKey = GlobalKey<NavigatorState>();
  final _roomNavigatorObserver = _SessionPanelRouteObserver();
  bool _dismissedForDisconnect = false;
  bool _overlayPresenting = false;

  /// Supersedes old presentation futures during layout handover or disconnect.
  int _presentationGeneration = 0;
  bool _presentationSyncScheduled = false;
  bool? _lastDocked;
  int? _lastViewportTier;
  SessionPresentationState? _resizeDismissal;
  SessionPanel? _presentedPanel;
  SessionPanel _renderedPanel = SessionPanel.none;
  bool _promptSaving = false;
  bool get _hasChildRoute => _roomNavigatorObserver.transientRoutes.any(
    (route) =>
        route.isActive && !_roomNavigatorObserver.panelRoutes.contains(route),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomNavigatorObserver.onRoutesChanged = _schedulePresentationSync;
    ref.listenManual(resolveCurrentScreenProvider, (previous, next) {
      if (next != RoomScreen.disconnected) {
        _dismissedForDisconnect = false;
      } else {
        _dismissSessionPresentation();
      }
    });
    ref.listenManual(
      currentSessionEventProvider.select((event) => event?.ended ?? false),
      (previous, next) {
        if (next) _dismissSessionPresentation();
      },
    );
    ref.listenManual(roomStatusProvider, (previous, next) {
      if (next == RoomStatus.ended) _dismissSessionPresentation();
    });
  }

  int _presentationTier(Size size) => size.shortestSide <= 600
      ? 0
      : size.width >= sessionSidePanelDockMinWidth
      ? 2
      : 1;

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final view = View.of(context);
    final tier = _presentationTier(view.physicalSize / view.devicePixelRatio);
    if (_lastViewportTier != null && tier != _lastViewportTier) {
      _resizeDismissal = ref.read(sessionPresentationProvider);
      // Metrics arrive before layout. Remove incompatible popup routes before
      // they can lay out in a different presentation tier.
      _syncPresentation();
    }
    _lastViewportTier = tier;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _roomNavigatorObserver.onRoutesChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final connectionState = widget.connectionState;
    final roomStatus = widget.roomStatus;
    if (session == null || connectionState == null || roomStatus == null) {
      _lastDocked = null;
      return widget.child;
    }

    final desired = ref.watch(
      sessionPresentationProvider.select((s) => s.panel),
    );
    _promptSaving = false;
    if (desired == SessionPanel.prompts ||
        _renderedPanel == SessionPanel.prompts) {
      final prompts = sessionPromptsControllerProvider(widget.sessionSlug);
      _promptSaving = ref.watch(prompts.select((state) => state.mutating));
      ref.listen(
        prompts.select((state) => state.mutating),
        (_, _) => _schedulePresentationSync(),
      );
    }
    // Changing presentation tier dismisses the current popup. Close it
    // rather than silently opening a different kind of overlay.
    final tier = _presentationTier(MediaQuery.sizeOf(context));
    if (_lastViewportTier != null && tier != _lastViewportTier) {
      _resizeDismissal = ref.read(sessionPresentationProvider);
      _schedulePresentationSync();
    }
    _lastViewportTier = tier;
    final blocked = _hasChildRoute || _promptSaving;
    if (!blocked) _renderedPanel = desired;
    final dockChatSlot = blocked
        ? (_lastDocked ?? shouldDockSessionChat(context))
        : shouldDockSessionChat(context);
    ref.listen(sessionPresentationProvider, (previous, next) {
      _schedulePresentationSync();
    });
    if (_lastDocked != dockChatSlot) {
      _lastDocked = dockChatSlot;
      _schedulePresentationSync();
    }

    return SessionNavigatorScope(
      navigatorKey: _roomNavigatorKey,
      child: SessionAdmissionOverlay(
        sessionSlug: widget.sessionSlug,
        child: SessionKeyboardShortcuts(
          navigatorKey: _roomNavigatorKey,
          onEscape: () =>
              shouldDockSessionChat(context) && closeDockedSessionPanel(ref),
          enableEmojiReactions: widget.enableEmojiReactions,
          child: RoomBackground(
            status: roomStatus,
            child: Navigator(
              key: _roomNavigatorKey,
              observers: [_roomNavigatorObserver],
              clipBehavior: Clip.none,
              onDidRemovePage: (page) {},
              pages: [
                MaterialPage(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: PopScope(
                            canPop: false,
                            onPopInvokedWithResult: (didPop, result) async {
                              if (!didPop) {
                                await _handleBackNavigation(
                                  session,
                                  connectionState,
                                );
                              }
                            },
                            // Read before the docked panel.
                            child: Semantics(
                              container: true,
                              explicitChildNodes: true,
                              sortKey: const OrdinalSortKey(0),
                              // Escape from a focused room control. A focused
                              // popup handles it first.
                              child: Focus(
                                canRequestFocus: false,
                                skipTraversal: true,
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey ==
                                          LogicalKeyboardKey.escape &&
                                      shouldDockSessionChat(context) &&
                                      closeDockedSessionPanel(ref)) {
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Overlay(key: EmojiReactions.emojiOverlayKey),
                        ),
                      ),
                      // The panel floats over the full-width room, inside the
                      // page so the room's dialogs, menus and notifications
                      // draw over it and their barriers block it. Kept
                      // mounted while closed for its exit animation.
                      if (dockChatSlot &&
                          !_roomNavigatorObserver.panelRoutes.any(
                            (route) => route.isActive,
                          ))
                        _DockedSessionPanels(
                          sessionSlug: widget.sessionSlug,
                          panel: _renderedPanel,
                        ),
                      if (widget.orientationBuilder case final builder?)
                        builder(context, dockChatSlot),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _schedulePresentationSync() {
    if (_presentationSyncScheduled) return;
    _presentationSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presentationSyncScheduled = false;
      if (!mounted || widget.session == null) return;
      // Read live values — a prior frame's captured flag/layout can be stale
      // (e.g. room-entry invalidate clearing the keepAlive flag).
      setState(() {});
      _syncPresentation();
    });
  }

  void _syncPresentation() {
    final resize = _resizeDismissal;
    if (resize != null) {
      // Keep an in-flight save mounted until its owner finishes the mutation.
      if (_promptSaving && !_dismissedForDisconnect) return;
      _resizeDismissal = null;
      if (ref.read(sessionPresentationProvider).revision == resize.revision) {
        _presentationGeneration++;
        _overlayPresenting = false;
        ref
            .read(sessionPresentationProvider.notifier)
            .closePanel(expectedRevision: resize.revision);
        _renderedPanel = SessionPanel.none;
        _removePanelRoutes(handover: false);
        _schedulePresentationSync();
        return;
      }
    }
    if ((_hasChildRoute || _promptSaving) && !_dismissedForDisconnect) {
      return;
    }
    final selected = ref.read(sessionPresentationProvider).panel;
    final chatOpen = selected != SessionPanel.none;
    final dockChatSlot = shouldDockSessionChat(context);
    final wantOverlay = chatOpen && !dockChatSlot;
    final hasOverlayRoute = _roomNavigatorObserver.panelRoutes.any(
      (route) => route.isActive,
    );

    if (hasOverlayRoute && _presentedPanel != selected) {
      _removePanelRoutes(handover: true);
      _schedulePresentationSync();
      return;
    }
    if (wantOverlay && !hasOverlayRoute && !_overlayPresenting) {
      unawaited(_presentOverlayPanel());
      return;
    }

    if (!wantOverlay && hasOverlayRoute) {
      // Hand over to the dock when chat stays open across a widen; otherwise
      // the flag was cleared and the overlay should go with it.
      _removePanelRoutes(handover: chatOpen && dockChatSlot);
    }
  }

  Future<void> _presentOverlayPanel() async {
    final navContext = _roomNavigatorKey.currentContext;
    if (navContext == null || _overlayPresenting) return;

    final selection = ref.read(sessionPresentationProvider);
    _presentedPanel = selection.panel;
    final generation = ++_presentationGeneration;
    _overlayPresenting = true;
    try {
      switch (selection.panel) {
        case SessionPanel.chat:
          await showSessionChat(navContext);
        case SessionPanel.prompts:
          await presentSessionPrompts(
            navContext,
            useDrawer: true,
            sessionSlug: widget.sessionSlug,
          );
        case SessionPanel.admission:
          await presentSessionAdmission(navContext);
        case SessionPanel.none:
          break;
      }
    } finally {
      // A layout handover (or a newer present) supersedes this call.
      if (generation == _presentationGeneration) {
        _overlayPresenting = false;
        // User dismissed the sheet/drawer (swipe, barrier, or close).
        if (mounted) {
          ref
              .read(sessionPresentationProvider.notifier)
              .closePanel(
                expectedPanel: selection.panel,
                expectedRevision: selection.revision,
              );
        }
      }
    }
  }

  void _removePanelRoutes({required bool handover}) {
    final navigator = _roomNavigatorKey.currentState;
    if (navigator == null) return;

    final routes = List<Route<dynamic>>.of(
      handover
          ? _roomNavigatorObserver.panelRoutes
          : _roomNavigatorObserver.transientRoutes,
    );
    if (routes.isEmpty) return;

    // Invalidate any in-flight showSessionChat before removing routes so a
    // handover cannot leave presenting=true if removeRoute does not complete
    // that future, and so a later dismiss finally cannot clear the open flag.
    if (handover) {
      _presentationGeneration++;
      _overlayPresenting = false;
    }

    for (final route in routes.reversed) {
      if (!route.isActive) continue;
      // Instant removal on layout handover avoids a brief dual-panel flash
      // while a pop animation and the dock slide run together. Instant on
      // flag-clear too — SessionChatPanel also pops itself when the flag
      // goes false, so this is usually a no-op cleanup.
      navigator.removeRoute(route);
    }
    if (mounted) setState(() {});
  }

  void _dismissSessionPresentation() {
    if (_dismissedForDisconnect) return;
    _dismissedForDisconnect = true;
    _presentationGeneration++;
    _overlayPresenting = false;
    ref.read(sessionPresentationProvider.notifier).closePanel();
    _removePanelRoutes(handover: false);
    final navigator = _roomNavigatorKey.currentState;
    for (final route in List<Route<dynamic>>.of(
      _roomNavigatorObserver.transientRoutes,
    ).reversed) {
      if (route.isActive) navigator?.removeRoute(route);
    }
  }

  Future<void> _handleBackNavigation(
    SessionController session,
    RoomConnectionState connectionState,
  ) async {
    // Checks if there is any other route above the first route.
    //   This route would be a modal sheet or a dialog.
    final navigator = _roomNavigatorKey.currentState;
    if (navigator?.canPop() ?? false) {
      navigator?.pop();
      return;
    }

    // Back closes a docked panel before offering to leave.
    if (shouldDockSessionChat(context) && closeDockedSessionPanel(ref)) {
      return;
    }

    // If there is no other route above the first route, the user is
    // trying to leave the session.

    // If the session is not connected or connecting, leave the session.
    if (connectionState != RoomConnectionState.connecting &&
        connectionState != RoomConnectionState.connected) {
      TotemRouter.instance.popOrHome(context);
      return;
    }

    // If the session is connected, show a dialog to confirm the action.
    final shouldPop =
        await MoreOptions.showLeaveDialog(
          _roomNavigatorKey.currentContext ?? context,
        ) ??
        false;
    if (mounted && shouldPop) {
      await session.leave();
      if (!mounted) return;
      TotemRouter.instance.popOrHome(context);
    }
  }
}

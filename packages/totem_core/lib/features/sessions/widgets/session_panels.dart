import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/admission/session_admission_overlay.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/screens/options/more_options_popup.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/session_keyboard_shortcuts.dart';
import 'package:totem_core/features/sessions/widgets/session_prompts_modal.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/shared/router.dart';

class _SessionChatRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> chatRoutes = [];
  final List<Route<dynamic>> admissionRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    switch (route.settings.name) {
      case sessionChatRouteName:
        chatRoutes.add(route);
      case sessionAdmissionRouteName:
        admissionRoutes.add(route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    chatRoutes.remove(route);
    admissionRoutes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    chatRoutes.remove(route);
    admissionRoutes.remove(route);
  }
}

class _DockedSessionPanelsRail extends ConsumerWidget {
  const _DockedSessionPanelsRail({required this.sessionSlug});

  final String sessionSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatOpen = ref.watch(sessionChatOpenProvider);
    final isKeeper = ref.watch(isCurrentUserKeeperProvider);
    final promptsOpen = isKeeper && ref.watch(sessionPromptsOpenProvider);
    final admissionOpen = isKeeper && ref.watch(sessionAdmissionOpenProvider);
    final Widget? panel = switch ((chatOpen, promptsOpen, admissionOpen)) {
      (true, _, _) => const SessionChatPanel(embedded: true),
      (false, true, _) => SessionPromptsModal(
        sessionSlug: sessionSlug,
        embedded: true,
      ),
      (false, false, true) => const SessionAdmissionPanel(docked: true),
      (false, false, false) => null,
    };

    return DockedSessionSidePanel(open: panel != null, child: panel);
  }
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

class _SessionPanelsState extends ConsumerState<SessionPanels> {
  final _roomNavigatorKey = GlobalKey<NavigatorState>();
  final _roomNavigatorObserver = _SessionChatRouteObserver();
  bool _hasDismissedChatForDisconnect = false;
  bool _overlayChatPresenting = false;

  /// Supersedes old presentation futures during layout handover or disconnect.
  int _overlayChatGeneration = 0;
  bool _chatPresentationSyncScheduled = false;
  bool? _lastSyncedDockChatSlot;

  @override
  void initState() {
    super.initState();
    // In-call chat UI state is per-session. Clearing it on entry keeps a
    // docked sidebar, or a private thread aimed at the previous circle's
    // keeper, from carrying into this one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
        ..invalidate(sessionChatOpenProvider)
        ..invalidate(sessionPromptsOpenProvider)
        ..invalidate(sessionAdmissionOpenProvider)
        ..invalidate(sessionChatThreadTargetProvider)
        ..invalidate(sessionChatUnreadThreadsProvider);
    });

    ref.listenManual(resolveCurrentScreenProvider, (previous, next) {
      if (next != RoomScreen.disconnected) {
        _hasDismissedChatForDisconnect = false;
      } else {
        _dismissSessionChat();
      }
    });
    ref.listenManual(
      currentSessionEventProvider.select((event) => event?.ended ?? false),
      (previous, next) {
        if (next) _dismissSessionChat();
      },
    );
    ref.listenManual(roomStatusProvider, (previous, next) {
      if (next == RoomStatus.ended) _dismissSessionChat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final connectionState = widget.connectionState;
    final roomStatus = widget.roomStatus;
    if (session == null || connectionState == null || roomStatus == null) {
      _lastSyncedDockChatSlot = null;
      return widget.child;
    }

    final dockChatSlot = shouldDockSessionChat(context);
    ref.listen(sessionChatOpenProvider, (previous, next) {
      _scheduleChatPresentationSync();
    });
    if (_lastSyncedDockChatSlot != dockChatSlot) {
      _lastSyncedDockChatSlot = dockChatSlot;
      _scheduleChatPresentationSync();
    }

    return SessionAdmissionOverlay(
      sessionSlug: widget.sessionSlug,
      child: SessionKeyboardShortcuts(
        navigatorKey: _roomNavigatorKey,
        enableEmojiReactions: widget.enableEmojiReactions,
        child: RoomBackground(
          status: roomStatus,
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: Navigator(
                        key: _roomNavigatorKey,
                        observers: [_roomNavigatorObserver],
                        clipBehavior: Clip.none,
                        onDidRemovePage: (page) => {},
                        pages: [
                          MaterialPage(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: PopScope(
                                      canPop: false,
                                      onPopInvokedWithResult:
                                          (didPop, result) async {
                                            await _handleBackNavigation(
                                              session,
                                              connectionState,
                                            );
                                          },
                                      child: widget.child,
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Overlay(
                                      key: EmojiReactions.emojiOverlayKey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Keep the rail mounted while closed for its exit animation.
                    if (dockChatSlot)
                      _DockedSessionPanelsRail(sessionSlug: widget.sessionSlug),
                  ],
                ),
              ),
              if (widget.orientationBuilder case final builder?)
                builder(context, dockChatSlot),
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleChatPresentationSync() {
    if (_chatPresentationSyncScheduled) return;
    _chatPresentationSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatPresentationSyncScheduled = false;
      if (!mounted || widget.session == null) return;
      // Read live values — a prior frame's captured flag/layout can be stale
      // (e.g. room-entry invalidate clearing the keepAlive flag).
      _syncChatPresentation();
    });
  }

  void _syncChatPresentation() {
    final chatOpen = ref.read(sessionChatOpenProvider);
    final dockChatSlot = shouldDockSessionChat(context);
    final wantOverlay = chatOpen && !dockChatSlot;
    final hasOverlayRoute = _roomNavigatorObserver.chatRoutes.any(
      (route) => route.isActive,
    );

    if (wantOverlay && !hasOverlayRoute && !_overlayChatPresenting) {
      unawaited(_presentOverlayChat());
      return;
    }

    if (!wantOverlay && hasOverlayRoute) {
      // Hand over to the dock when chat stays open across a widen; otherwise
      // the flag was cleared and the overlay should go with it.
      _removeChatOverlayRoutes(handover: chatOpen && dockChatSlot);
    }
  }

  Future<void> _presentOverlayChat() async {
    final navContext = _roomNavigatorKey.currentContext;
    if (navContext == null || _overlayChatPresenting) return;

    final generation = ++_overlayChatGeneration;
    _overlayChatPresenting = true;
    try {
      await showSessionChat(navContext);
    } finally {
      // A layout handover (or a newer present) supersedes this call.
      if (generation == _overlayChatGeneration) {
        _overlayChatPresenting = false;
        // User dismissed the sheet/drawer (swipe, barrier, or close).
        if (mounted && ref.read(sessionChatOpenProvider)) {
          ref.read(sessionChatOpenProvider.notifier).open = false;
        }
      }
    }
  }

  void _removeChatOverlayRoutes({required bool handover}) {
    final navigator = _roomNavigatorKey.currentState;
    if (navigator == null) return;

    final routes = List<Route<dynamic>>.of(
      _roomNavigatorObserver.chatRoutes,
    );
    if (routes.isEmpty) return;

    // Invalidate any in-flight showSessionChat before removing routes so a
    // handover cannot leave presenting=true if removeRoute does not complete
    // that future, and so a later dismiss finally cannot clear the open flag.
    if (handover) {
      _overlayChatGeneration++;
      _overlayChatPresenting = false;
    }

    for (final route in routes.reversed) {
      if (!route.isActive) continue;
      // Instant removal on layout handover avoids a brief dual-panel flash
      // while a pop animation and the dock slide run together. Instant on
      // flag-clear too — SessionChatPanel also pops itself when the flag
      // goes false, so this is usually a no-op cleanup.
      navigator.removeRoute(route);
    }
  }

  void _removeAdmissionOverlayRoutes() {
    final navigator = _roomNavigatorKey.currentState;
    if (navigator == null) return;

    final routes = List<Route<dynamic>>.of(
      _roomNavigatorObserver.admissionRoutes,
    );
    for (final route in routes.reversed) {
      if (!route.isActive) continue;
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
    }
  }

  void _dismissSessionChat() {
    if (_hasDismissedChatForDisconnect) return;
    _hasDismissedChatForDisconnect = true;
    _overlayChatGeneration++;
    _overlayChatPresenting = false;
    ref
      ..read(sessionChatOpenProvider.notifier).open = false
      ..read(sessionPromptsOpenProvider.notifier).open = false
      ..read(sessionAdmissionOpenProvider.notifier).open = false;
    _removeChatOverlayRoutes(handover: false);
    _removeAdmissionOverlayRoutes();
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

    // If there is no other route above the first route, the user is
    // trying to leave the session.

    // If the session is not connected or connecting, leave the session.
    if (connectionState != RoomConnectionState.connecting &&
        connectionState != RoomConnectionState.connected) {
      TotemRouter.instance.popOrHome(context);
      return;
    }

    // If the session is connected, show a dialog to confirm the action.
    final shouldPop = await MoreOptions.showLeaveDialog(context) ?? false;
    if (mounted && shouldPop) {
      await session.leave();
      if (!mounted) return;
      TotemRouter.instance.popOrHome(context);
    }
  }
}

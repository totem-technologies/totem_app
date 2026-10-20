import 'dart:async';
import 'dart:ui' as ui;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/theme.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/core/services/screen_protection_service.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_panel.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/listening_turn_screen.dart';
import 'package:totem_core/features/sessions/screens/more_options_popup.dart';
import 'package:totem_core/features/sessions/screens/receive_totem_screen.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/features/sessions/screens/speaking_turn_screen.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_notice.dart';
import 'package:totem_core/features/sessions/widgets/session_keyboard_shortcuts.dart';
import 'package:totem_core/features/sessions/widgets/session_prompts_modal.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';
import 'package:totem_core/features/sessions/widgets/session_waiting_queue_button.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

class VideoSessionScreen extends ConsumerStatefulWidget {
  const new({
    required this.sessionSlug,
    required this.loadingScreen,
    this.showAdmissionOrientation = false,
    this.now = DateTime.now,
    super.key,
  });

  final String sessionSlug;
  final Widget loadingScreen;
  final bool showAdmissionOrientation;
  final ValueGetter<DateTime> now;

  @override
  ConsumerState<VideoSessionScreen> createState() => _VideoSessionScreenState();
}

// Use shared helper to determine transient join disconnect reasons.

class _SessionChatRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> chatRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == sessionChatRouteName) chatRoutes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    chatRoutes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    chatRoutes.remove(route);
  }
}

class _DockedSessionPanelsRail extends ConsumerWidget {
  const new({required this.sessionSlug});

  final String sessionSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatOpen = ref.watch(sessionChatOpenProvider);
    final isKeeper = ref.watch(isCurrentUserKeeperProvider);
    final promptsOpen = isKeeper && ref.watch(sessionPromptsOpenProvider);
    final Widget? panel = switch ((chatOpen, promptsOpen)) {
      (true, _) => const SessionChatPanel(embedded: true),
      (false, true) => Material(
        color: AppTheme.cream,
        elevation: 6,
        shadowColor: const Color.fromRGBO(0, 0, 0, 0.16),
        child: SessionPromptsModal(sessionSlug: sessionSlug, embedded: true),
      ),
      (false, false) => null,
    };

    return DockedSessionSidePanel(open: panel != null, child: panel);
  }
}

class _VideoSessionScreenState extends ConsumerState<VideoSessionScreen> {
  static var _didWarmEmojiGlyphs = false;

  final _roomNavigatorKey = GlobalKey<NavigatorState>();
  final _roomNavigatorObserver = _SessionChatRouteObserver();
  final _notificationController = NotificationController();

  /// The page exit handler this screen registered, if any.
  VoidCallback? _pageExitHandler;
  NotificationRequest? _closeKeeperLeftNotification;
  NotificationRequest? _offlineNotification;
  Timer? _timeRemainingWarningTimer;
  String? _timeRemainingWarningSessionSlug;
  bool _hasShownTimeRemainingWarning = false;
  bool? _lastIsOffline;
  bool? _lastKeeperDisconnectedState;
  RoomStatus? _lastKeeperDisconnectedRoomStatus;
  bool _hasDismissedChatForDisconnect = false;
  LiveKitAdmissionTransport? _admissionTransport;
  KeeperAdmissionController? _keeperAdmission;
  late final PendingSessionParticipantIdentities _pendingIdentities;
  StreamSubscription<void>? _admissionChanges;
  String? _admissionKeeperIdentity;
  bool _admissionDismissed = false;
  bool _admissionBusy = false;
  bool _admissionOrientationDismissed = false;

  @override
  void initState() {
    super.initState();
    _pendingIdentities = ref.read(
      pendingSessionParticipantIdentitiesProvider.notifier,
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // In-call chat UI state is per-session. Clearing it on entry keeps a
    // docked sidebar, or a private thread aimed at the previous circle's
    // keeper, from carrying into this one.
    ref
      ..invalidate(sessionChatOpenProvider)
      ..invalidate(sessionPromptsOpenProvider)
      ..invalidate(sessionChatThreadTargetProvider)
      ..invalidate(sessionChatUnreadThreadsProvider);

    // Closing the tab skips the leave flow, so leave as the page unloads.
    ref.listenManual(currentSessionProvider, (_, session) {
      final handler = session?.leaveOnPageExit;
      if (handler == _pageExitHandler) return;
      _pageExitHandler = handler;
      TotemRouter.instance.setPageExitHandler(handler);
    }, fireImmediately: true);

    ref.listenManual(currentSessionStateProvider, (_, next) {
      _syncKeeperAdmission(next);
    }, fireImmediately: true);
    ref.listenManual(currentSessionEventProvider, (_, _) {
      _syncKeeperAdmission(ref.read(currentSessionStateProvider));
    });

    _listenToBatteryChanges();
    _warmEmojiGlyphs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyScreenCapturePolicy();
    });
  }

  @override
  void dispose() {
    _pendingIdentities.update({});
    unawaited(_detachKeeperAdmission(clearPending: false));
    _notificationController.dispose();
    _clearTimeRemainingWarningTimer();
    _setScreenProtection(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _batterySubscription?.cancel();
    TotemRouter.instance.setTabCloseConfirmationEnabled(false);
    if (_pageExitHandler case final handler?) {
      TotemRouter.instance.clearPageExitHandler(handler);
    }
    super.dispose();
  }

  void _syncKeeperAdmission(SessionRoomState? state) {
    final room = ref.read(currentSessionProvider)?.room;
    final keeperIdentity = state?.roomState.keeper;
    final canManage =
        state?.connection.state == RoomConnectionState.connected &&
        state?.roomState.status != RoomStatus.ended &&
        ref.read(currentSessionEventProvider)?.ended != true &&
        room?.localParticipant?.identity == keeperIdentity &&
        keeperIdentity != null &&
        keeperIdentity.isNotEmpty;
    if (!canManage || room == null) {
      if (_keeperAdmission != null) {
        unawaited(_detachKeeperAdmission());
        if (mounted) setState(() {});
      }
      return;
    }
    if (identical(_admissionTransport?.room, room) &&
        _admissionKeeperIdentity == keeperIdentity) {
      return;
    }
    unawaited(_detachKeeperAdmission());
    final transport = LiveKitAdmissionTransport(room);
    final controller = KeeperAdmissionController(
      channel: transport,
      keeperIdentity: () => mounted
          ? ref.read(currentSessionStateProvider)?.roomState.keeper ?? ''
          : '',
    );
    _admissionTransport = transport;
    _keeperAdmission = controller;
    _admissionKeeperIdentity = keeperIdentity;
    _admissionDismissed = false;
    _syncPendingParticipants(controller);
    _admissionChanges = controller.changes.listen((_) {
      if (!mounted || !identical(_keeperAdmission, controller)) return;
      _syncPendingParticipants(controller);
      setState(() {
        if (controller.requests.isEmpty) _admissionDismissed = false;
      });
    });
    if (mounted) setState(() {});
  }

  void _syncPendingParticipants(KeeperAdmissionController? controller) {
    if (!mounted) return;
    _pendingIdentities.update({
      for (final attempt in controller?.attempts ?? <KeeperAdmissionAttempt>[])
        if (attempt.status == KeeperAdmissionStatus.requested ||
            attempt.status == KeeperAdmissionStatus.joining)
          attempt.request.senderIdentity,
    });
  }

  Future<void> _detachKeeperAdmission({bool clearPending = true}) async {
    final controller = _keeperAdmission;
    if (clearPending) _syncPendingParticipants(null);
    final transport = _admissionTransport;
    unawaited(_admissionChanges?.cancel());
    _admissionChanges = null;
    _keeperAdmission = null;
    _admissionTransport = null;
    _admissionKeeperIdentity = null;
    _admissionBusy = false;
    await controller?.dispose();
    await transport?.dispose();
  }

  Future<void> _decideAdmission(AdmissionRequest request, bool approve) async {
    final controller = _keeperAdmission;
    if (controller == null || _admissionBusy) return;
    setState(() => _admissionBusy = true);
    try {
      await _sendAdmissionDecision(controller, request, approve);
    } finally {
      if (mounted && identical(_keeperAdmission, controller)) {
        setState(() => _admissionBusy = false);
      }
    }
  }

  Future<void> _admitAll() async {
    final controller = _keeperAdmission;
    if (controller == null || _admissionBusy) return;
    setState(() => _admissionBusy = true);
    try {
      for (final request in controller.requests) {
        if (!identical(_keeperAdmission, controller)) break;
        await _sendAdmissionDecision(controller, request, true);
      }
    } finally {
      if (mounted && identical(_keeperAdmission, controller)) {
        setState(() => _admissionBusy = false);
      }
    }
  }

  Future<void> _sendAdmissionDecision(
    KeeperAdmissionController controller,
    AdmissionRequest request,
    bool approve,
  ) async {
    try {
      if (approve) {
        await controller.approve(request.id, request.senderIdentity);
      } else {
        await controller.deny(request.id, request.senderIdentity);
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Could not send admission decision',
      );
      if (!mounted || !identical(_keeperAdmission, controller)) return;
      _notificationController.showError(
        context,
        icon: TotemIcons.errorOutlined,
        title: 'Could not update the queue',
        message: 'Please check your connection and try again.',
      );
    }
  }

  Widget _buildAdmissionOrientation(String? prompt, {required bool desktop}) {
    final size = MediaQuery.sizeOf(context);
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight: size.height * (desktop ? 0.65 : 0.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SessionOrientationNotice(
          prompt: prompt,
          onDone: () => setState(() => _admissionOrientationDismissed = true),
        ),
      ),
    );

    if (desktop) {
      return Positioned.fill(
        child: Stack(
          children: [
            const ModalBarrier(dismissible: false, color: Colors.black54),
            Center(child: Dialog(child: content)),
          ],
        ),
      );
    }
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: SafeArea(
        child: Center(child: Card(elevation: 8, child: content)),
      ),
    );
  }

  void _setScreenProtection(bool enabled) {
    try {
      ScreenProtectionService.setCaptureProtectionEnabled(enabled);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error setting screen capture policy to $enabled',
      );
    }
  }

  void _applyScreenCapturePolicy() {
    if (!mounted) return;

    try {
      final email = ref.read(authControllerProvider).user?.email;
      final shouldProtect =
          !ScreenProtectionService.shouldAllowScreenCaptureForEmail(email);
      _setScreenProtection(shouldProtect);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error applying screen capture policy',
      );
    }
  }

  void _warmEmojiGlyphs() {
    if (!kIsWeb) return;
    if (_didWarmEmojiGlyphs) return;
    _didWarmEmojiGlyphs = true;

    // On web, first-time emoji painting may show placeholders briefly while
    // glyphs are being resolved. Painting once off-screen warms the cache.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final textDirection =
          Directionality.maybeOf(context) ?? TextDirection.ltr;
      const style = TextStyle(
        fontSize: 24,
        textBaseline: TextBaseline.ideographic,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      var dy = 0.0;

      for (final emoji in EmojiBar.defaultEmojis) {
        final painter =
            TextPainter(
                text: TextSpan(text: emoji, style: style),
                textDirection: textDirection,
                maxLines: 1,
              )
              ..layout()
              ..paint(canvas, Offset(0, dy));
        dy += painter.height + 2;
        painter.dispose();
      }

      recorder.endRecording().dispose();
    });
  }

  void _onConnectivityChanged(bool isOffline, {bool? wasOffline}) {
    if (!mounted) return;

    final previousIsOffline = wasOffline ?? _lastIsOffline;
    _lastIsOffline = isOffline;

    if (!isOffline) {
      _dismissOfflineNotification();
      return;
    }

    if (previousIsOffline != false || _offlineNotification != null) {
      return;
    }

    _offlineNotification = _notificationController.showPermanent(
      context,
      icon: TotemIcons.wifiOff,
      title: "You're Offline",
      message: 'Check your Wi-Fi or mobile data to continue.',
    );
  }

  void _dismissOfflineNotification({bool immediately = false}) {
    if (immediately) {
      _offlineNotification?.dismissImmediately();
    } else {
      _offlineNotification?.dismissActive();
    }
    _offlineNotification = null;
  }

  void _dismissKeeperLeftNotification() {
    _closeKeeperLeftNotification?.dismissActive();
    _closeKeeperLeftNotification = null;
  }

  void _clearTimeRemainingWarningTimer() {
    _timeRemainingWarningTimer?.cancel();
    _timeRemainingWarningTimer = null;
  }

  void _scheduleTimeRemainingWarning(SessionDetailSchema sessionEvent) {
    if (_timeRemainingWarningSessionSlug != sessionEvent.slug) {
      _timeRemainingWarningSessionSlug = sessionEvent.slug;
      _hasShownTimeRemainingWarning = false;
      _clearTimeRemainingWarningTimer();
    }

    if (_hasShownTimeRemainingWarning ||
        _timeRemainingWarningTimer?.isActive == true) {
      return;
    }

    final endTime = sessionEvent.start.add(
      Duration(minutes: sessionEvent.duration),
    );
    final warningTime = endTime.subtract(const Duration(minutes: 5));
    final delay = warningTime.difference(widget.now());

    _timeRemainingWarningTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      _showTimeRemainingWarning,
    );
  }

  void _showTimeRemainingWarning() {
    _timeRemainingWarningTimer = null;
    if (!mounted || _hasShownTimeRemainingWarning) return;

    _hasShownTimeRemainingWarning = true;
    _notificationController.showTimed(
      context,
      icon: TotemIcons.clockCircle,
      title: 'Time Remaining 5 min',
      message: 'Thanks for your participation in this session today',
    );
  }

  final battery = Battery();
  bool _shouldShowLowBatteryWarning = false;
  StreamSubscription<BatteryState>? _batterySubscription;
  void _listenToBatteryChanges() {
    try {
      _batterySubscription = battery.onBatteryStateChanged.listen((
        state,
      ) async {
        if (!mounted) return;
        if (state == BatteryState.charging && _shouldShowLowBatteryWarning) {
          setState(() => _shouldShowLowBatteryWarning = false);
        } else if (state == BatteryState.discharging) {
          try {
            final level = await battery.batteryLevel;
            if (level <= 20 && !_shouldShowLowBatteryWarning) {
              _shouldShowLowBatteryWarning = true;
              if (mounted) {
                setState(() {});
                _notificationController.showTimed(
                  context,
                  icon: TotemIcons.person,
                  title: 'Your battery is running low',
                  message: 'You might want to plug in.',
                );
              }
            }
          } catch (_) {
            // Unable to get battery level
          }
        }
      });
    } catch (_) {
      // Battery monitoring not available
    }
  }

  void _onLivekitError(LiveKitException error) {
    if (error is ConnectException ||
        error is MediaConnectException ||
        error is UnexpectedStateException ||
        error is NegotiationError ||
        error is TrackCreateException ||
        error is TrackPublishException) {
      // These errors are shown in the error screen
    } else {
      if (mounted) {
        _notificationController.showError(
          context,
          icon: TotemIcons.errorOutlined,
          title: 'Something went wrong',
          message: 'Check your connection and try again.',
        );
      }
    }
  }

  void _onAudioRouteChanged(SessionDeviceState next) {
    final message = next.isSpeakerphoneEnabled
        ? 'Audio is now playing through speaker.'
        : 'Audio is now routed to another output device.';

    _notificationController.showTimed(
      context,
      icon: next.isSpeakerphoneEnabled
          ? TotemIcons.speakerOn
          : TotemIcons.speakerOff,
      title: 'Audio route changed',
      message: message,
    );
  }

  void _setKeeperDisconnectedNotification(
    bool hasKeeperDisconnected,
    RoomStatus roomStatus,
  ) {
    if (!mounted || !hasKeeperDisconnected || roomStatus != RoomStatus.active) {
      _dismissKeeperLeftNotification();
      return;
    }

    if (_closeKeeperLeftNotification != null) {
      // do not show again
      return;
    }

    _closeKeeperLeftNotification = _notificationController.showPermanent(
      context,
      icon: TotemIcons.pause,
      title: 'The session has been paused.',
      message: 'The keeper will be right back.',
    );
  }

  void _syncKeeperDisconnectedNotification(
    bool hasKeeperDisconnected,
    RoomStatus roomStatus,
  ) {
    if (_lastKeeperDisconnectedState == hasKeeperDisconnected &&
        _lastKeeperDisconnectedRoomStatus == roomStatus) {
      return;
    }

    _lastKeeperDisconnectedState = hasKeeperDisconnected;
    _lastKeeperDisconnectedRoomStatus = roomStatus;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(connectionStateProvider) != RoomConnectionState.connected) {
        return;
      }
      _setKeeperDisconnectedNotification(hasKeeperDisconnected, roomStatus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = ref.watch(currentSessionProvider);
    final currentRoomScreen = ref.watch(resolveCurrentScreenProvider);
    final currentSessionEvent = ref.watch(currentSessionEventProvider);

    if (currentSession == null ||
        currentRoomScreen == null ||
        currentSessionEvent == null) {
      return widget.loadingScreen;
    }

    final hasKeeperDisconnected = ref.watch(hasKeeperDisconnectedProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final roomStatus = ref.watch(roomStatusProvider);
    final disconnectReason = ref.watch(disconnectionReasonProvider);

    final cuesService = ref.read(sessionCuesServiceProvider);
    final emojiNotifier = ref.read(emojiReactionsProvider.notifier);

    // Early transient join recovery check: keep showing the loading screen
    // when a join attempt failed transiently (e.g. signaling hiccup). This
    // must be evaluated before honoring a room-ended state so the UI
    // doesn't prematurely show the disconnected screen while the client
    // is still attempting to recover a join.
    final isTransientJoinRecoveryEarly =
        currentRoomScreen == RoomScreen.loading &&
        connectionState == RoomConnectionState.disconnected &&
        isTransientJoinDisconnectReason(disconnectReason);

    if (isTransientJoinRecoveryEarly) {
      return widget.loadingScreen;
    }

    final showingDisconnectedScreen =
        currentSessionEvent.ended ||
        roomStatus == RoomStatus.ended ||
        currentRoomScreen == RoomScreen.disconnected ||
        currentRoomScreen == RoomScreen.error;
    _notificationController.blocked = showingDisconnectedScreen;
    TotemRouter.instance.setTabCloseConfirmationEnabled(
      roomStatus != RoomStatus.waitingRoom && !showingDisconnectedScreen,
    );

    if (connectionState == RoomConnectionState.connected &&
        roomStatus == RoomStatus.active &&
        !currentSessionEvent.ended) {
      _scheduleTimeRemainingWarning(currentSessionEvent);
    } else {
      _clearTimeRemainingWarningTimer();
    }

    if (connectionState == RoomConnectionState.connected &&
        roomStatus != RoomStatus.ended) {
      _syncKeeperDisconnectedNotification(hasKeeperDisconnected, roomStatus);
    } else {
      _dismissKeeperLeftNotification();
    }

    ref
      ..listen(emojiReactionsProvider, (previous, next) {
        if (!mounted) return;

        final isListeningTurnScreen = currentRoomScreen == RoomScreen.listening;

        for (final reaction in next.where((reaction) => !reaction.displayed)) {
          emojiNotifier.displayReaction(
            context,
            reaction,
            isListeningTurnScreen,
          );
        }
      })
      ..listen(sessionLivekitErrorProvider, (previous, next) {
        if (next == null) return;
        if (identical(previous, next)) return;
        _onLivekitError(next);
      })
      ..listen(resolveCurrentScreenProvider, (previous, next) {
        if (next != RoomScreen.disconnected) {
          _hasDismissedChatForDisconnect = false;
        }
        if (previous != RoomScreen.receiving && next == RoomScreen.receiving) {
          cuesService.playTotemReceivedCue();
        }

        if (next == RoomScreen.disconnected || next == RoomScreen.error) {
          _clearTimeRemainingWarningTimer();
          _dismissOfflineNotification(immediately: true);
        }
        if (next == RoomScreen.disconnected) _dismissSessionChat();
      })
      ..listen(
        currentSessionEventProvider.select((event) => event?.ended ?? false),
        (previous, next) {
          if (next) _dismissSessionChat();
        },
      )
      ..listen(roomStatusProvider, (previous, next) {
        final isRoomOpeningTransition =
            previous == RoomStatus.waitingRoom && next == RoomStatus.active;
        final isRoomClosingTransition =
            previous == RoomStatus.active && next == RoomStatus.ended;

        if (isRoomOpeningTransition || isRoomClosingTransition) {
          cuesService.playSessionTransitionCue();
        }

        switch (next) {
          case RoomStatus.waitingRoom:
          case RoomStatus.active:
            break;
          case RoomStatus.ended:
            _clearTimeRemainingWarningTimer();
        }
      })
      ..listen(connectionStateProvider, (previous, next) {
        if (next == RoomConnectionState.disconnected ||
            next == RoomConnectionState.error) {
          _clearTimeRemainingWarningTimer();
        }
      })
      ..listen(isOfflineProvider, (previous, next) {
        if (!next.hasValue) return;
        _onConnectivityChanged(next.value!, wasOffline: previous?.value);
      });

    final audioRouteNotifier = ref.read(
      sessionDeviceControllerProvider(currentSession).notifier,
    );

    ref.listen(
      sessionDeviceControllerProvider(currentSession).select(
        (state) => (
          speakerphone: state.isSpeakerphoneEnabled,
          outputDeviceId: state.selectedAudioOutputDeviceId,
        ),
      ),
      (previous, next) {
        if (!mounted || previous == null || previous == next) return;
        if (!audioRouteNotifier.audioRouteNotificationsEnabled) return;
        if (ref.read(connectionStateProvider) !=
            RoomConnectionState.connected) {
          return;
        }

        _onAudioRouteChanged(
          ref.read(sessionDeviceControllerProvider(currentSession)),
        );
      },
    );

    final isOffline = ref.watch(isOfflineProvider).value ?? _lastIsOffline;

    if (currentSessionEvent.ended || roomStatus == RoomStatus.ended) {
      return RoomBackground(
        status: RoomStatus.ended,
        child: SessionDisconnectedScreen(
          session: currentSessionEvent,
          disconnectReason: disconnectReason,
        ),
      );
    }

    // Keep the rail mounted on wide windows even while closed so the
    // close animation has a widget to slide out.
    final dockChatSlot = shouldDockSessionChat(context);
    final showOrientation =
        widget.showAdmissionOrientation &&
        !_admissionOrientationDismissed &&
        connectionState == RoomConnectionState.connected &&
        roomStatus == RoomStatus.active &&
        !showingDisconnectedScreen &&
        currentRoomScreen != RoomScreen.loading;
    final admissionPrompt = showOrientation
        ? ref.watch(currentSessionPromptProvider)
        : null;

    return SessionKeyboardShortcuts(
      navigatorKey: _roomNavigatorKey,
      enableEmojiReactions: currentRoomScreen == RoomScreen.listening,
      child: RoomBackground(
        status: roomStatus,
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
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
                                                  currentSession,
                                                  connectionState,
                                                );
                                              },
                                          child: _buildBody(
                                            currentSession,
                                            currentRoomScreen,
                                            currentSessionEvent,
                                            disconnectReason,
                                            isOffline: isOffline ?? false,
                                          ),
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
                        if (_keeperAdmission case final controller?
                            when controller.attempts.isNotEmpty)
                          Positioned(
                            top: dockChatSlot ? 16 : null,
                            right: 16,
                            left: dockChatSlot ? null : 16,
                            bottom: dockChatSlot ? null : 16,
                            child: SafeArea(
                              child: Align(
                                alignment: dockChatSlot
                                    ? Alignment.topRight
                                    : Alignment.bottomCenter,
                                child: _admissionDismissed
                                    ? SessionWaitingQueueButton(
                                        count: controller.requests.length,
                                        label:
                                            controller.requests.isEmpty &&
                                                controller.attempts.any(
                                                  (attempt) =>
                                                      attempt.status ==
                                                      KeeperAdmissionStatus
                                                          .joining,
                                                )
                                            ? 'Admission in progress'
                                            : null,
                                        onPressed: () => setState(
                                          () => _admissionDismissed = false,
                                        ),
                                      )
                                    : KeeperAdmissionPanel(
                                        requests: controller.requests,
                                        attempts: controller.attempts,
                                        busy: _admissionBusy,
                                        desktop: dockChatSlot,
                                        onDecision: _decideAdmission,
                                        onAdmitAll: () =>
                                            unawaited(_admitAll()),
                                        onClose: () => setState(
                                          () => _admissionDismissed = true,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (dockChatSlot)
                    _DockedSessionPanelsRail(sessionSlug: widget.sessionSlug),
                ],
              ),
            ),
            if (showOrientation)
              _buildAdmissionOrientation(
                admissionPrompt,
                desktop: dockChatSlot,
              ),
          ],
        ),
      ),
    );
  }

  void _dismissSessionChat() {
    if (_hasDismissedChatForDisconnect) return;
    _hasDismissedChatForDisconnect = true;
    ref.read(sessionChatOpenProvider.notifier).open = false;
    final navigator = _roomNavigatorKey.currentState;
    if (navigator == null) return;

    for (final route in _roomNavigatorObserver.chatRoutes.reversed.toList()) {
      if (!route.isActive) continue;
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
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

  Widget _buildBody(
    SessionController session,
    RoomScreen screen,
    SessionDetailSchema sessionEvent,
    DisconnectReason? disconnectReason, {
    required bool isOffline,
  }) {
    final isInternetDisconnect =
        isInternetDisconnectReason(disconnectReason) ||
        (isOffline &&
            canOfflineStateOverrideDisconnectReason(disconnectReason));
    final disconnectionError = disconnectReason == null
        ? null
        : RoomDisconnectionError(disconnectReason);

    switch (screen) {
      case RoomScreen.error:
        return SessionErrorScreen(
          onRetry: session.join,
          error: disconnectionError,
        );
      case RoomScreen.loading:
        return widget.loadingScreen;
      case RoomScreen.disconnected:
        if (isInternetDisconnect) {
          return SessionErrorScreen(
            onRetry: session.join,
            error: disconnectionError,
          );
        }
        return SessionDisconnectedScreen(
          session: sessionEvent,
          disconnectReason: disconnectReason,
        );
      case RoomScreen.receiving:
        return const ReceiveTotemScreen();
      case RoomScreen.speaking:
      case RoomScreen.passing:
        return Builder(
          builder: (context) {
            return SpeakingTurnScreen(session: session.session!);
          },
        );
      case RoomScreen.listening:
        return ListeningTurnScreen(session: session.session!);
    }
  }
}

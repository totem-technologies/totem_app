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
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/core/services/screen_protection_service.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/ui/recovery.dart';
import 'package:totem_core/features/permissions/ui/recovery_content.dart';
import 'package:totem_core/features/sessions/admission/session_admission_overlay.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/media_devices_provider.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/chat.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/listening_turn_screen.dart';
import 'package:totem_core/features/sessions/screens/options/more_options_popup.dart';
import 'package:totem_core/features/sessions/screens/receive_totem_screen.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/features/sessions/screens/speaking_turn_screen.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_core/features/sessions/widgets/session_entry_notice.dart';
import 'package:totem_core/features/sessions/widgets/session_keyboard_shortcuts.dart';
import 'package:totem_core/features/sessions/widgets/session_prompts_modal.dart';
import 'package:totem_core/features/sessions/widgets/session_side_panel.dart';

import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

class VideoSessionScreen extends ConsumerStatefulWidget {
  const VideoSessionScreen({
    required this.sessionSlug,
    required this.loadingScreen,
    this.showAdmissionOrientation = false,
    this.admissionReady = false,
    this.isReturningParticipant = false,
    this.sessionStartedAtAdmission,
    this.now = DateTime.now,
    super.key,
  });

  final String sessionSlug;
  final Widget loadingScreen;
  final bool showAdmissionOrientation;
  final bool admissionReady;
  final bool isReturningParticipant;
  final bool? sessionStartedAtAdmission;
  final ValueGetter<DateTime> now;

  @override
  ConsumerState<VideoSessionScreen> createState() => _VideoSessionScreenState();
}

// Use shared helper to determine transient join disconnect reasons.

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
  StreamSubscription<MediaKind>? _deviceNoticeSubscription;
  StreamSubscription<(MediaKind, TurnOnBlocker)>? _turnOnBlockedSubscription;

  bool _admissionOrientationDismissed = false;
  bool? _admissionOrientationEligible;

  /// True while [showSessionChat] is awaiting dismissal of the overlay host.
  bool _overlayChatPresenting = false;

  /// Bumped when a layout handover (or a newer present) supersedes the
  /// in-flight [showSessionChat] future so its `finally` does not clear the
  /// open flag or block a later re-present.
  int _overlayChatGeneration = 0;

  bool _chatPresentationSyncScheduled = false;

  /// Last dock layout seen by the presentation sync — used to detect resizes
  /// without scheduling a sync on every unrelated rebuild.
  bool? _lastSyncedDockChatSlot;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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

    ref.listenManual(currentSessionProvider, (_, session) {
      // Permissions can change mid-call; tell the user when a device stops.
      unawaited(_deviceNoticeSubscription?.cancel());
      _deviceNoticeSubscription = session?.devices.deviceNeedsAttention.listen(
        _showDeviceNotice,
      );
      unawaited(_turnOnBlockedSubscription?.cancel());
      _turnOnBlockedSubscription = session?.devices.turnOnBlocked.listen(
        _showTurnOnBlocked,
      );

      // Closing the tab skips the leave flow, so leave as the page unloads.
      final handler = session?.leaveOnPageExit;
      if (handler == _pageExitHandler) return;
      _pageExitHandler = handler;
      TotemRouter.instance.setPageExitHandler(handler);
    }, fireImmediately: true);

    _listenToBatteryChanges();
    _warmEmojiGlyphs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyScreenCapturePolicy();
    });

    ref
      ..listenManual(
        currentSessionProvider,
        (_, _) => _syncAdmissionOrientation(),
      )
      ..listenManual(
        currentSessionEventProvider,
        (_, _) => _syncAdmissionOrientation(),
      )
      ..listenManual(
        resolveCurrentScreenProvider,
        (_, _) => _syncAdmissionOrientation(),
      )
      ..listenManual(
        connectionStateProvider,
        (_, _) => _syncAdmissionOrientation(),
      )
      ..listenManual(roomStatusProvider, (_, _) => _syncAdmissionOrientation());
    _syncAdmissionOrientation(rebuild: false);
  }

  @override
  void didUpdateWidget(covariant VideoSessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAdmissionOrientation(rebuild: false);
  }

  void _syncAdmissionOrientation({bool rebuild = true}) {
    final connection = ref.read(connectionStateProvider);
    final status = ref.read(roomStatusProvider);
    final screen = ref.read(resolveCurrentScreenProvider);
    final event = ref.read(currentSessionEventProvider);
    var eligible = _admissionOrientationEligible;
    var dismissed = _admissionOrientationDismissed;

    if (eligible != null && connection != RoomConnectionState.connected) {
      dismissed = true;
    }
    final waitingForAdmission =
        widget.showAdmissionOrientation && !widget.admissionReady;
    if (eligible == null &&
        !waitingForAdmission &&
        connection == RoomConnectionState.connected &&
        ref.read(currentSessionProvider) != null &&
        event != null &&
        !event.ended &&
        status != RoomStatus.ended &&
        screen != null &&
        screen != RoomScreen.disconnected &&
        screen != RoomScreen.error) {
      // Keeper entry-time status survives delayed rendering and tab suspension.
      // Legacy approvals fall back to the first connected room status.
      eligible =
          widget.showAdmissionOrientation &&
          !widget.isReturningParticipant &&
          (widget.sessionStartedAtAdmission ?? status == RoomStatus.active);
    }
    if (eligible == _admissionOrientationEligible &&
        dismissed == _admissionOrientationDismissed) {
      return;
    }

    void update() {
      _admissionOrientationEligible = eligible;
      _admissionOrientationDismissed = dismissed;
    }

    if (rebuild) {
      setState(update);
    } else {
      update();
    }
  }

  void _showDeviceNotice(MediaKind kind) {
    final session = ref.read(currentSessionProvider);
    if (!mounted || session == null) return;
    final notice = deviceNotice(
      kind,
      ref.read(sessionDeviceControllerProvider(session)).problemOf(kind),
    );
    _notificationController.showTimed(
      context,
      icon: switch (kind) {
        MediaKind.microphone => TotemIcons.microphoneOff,
        MediaKind.camera => TotemIcons.cameraOff,
      },
      title: notice.title,
      message: notice.message,
      onTap: () =>
          unawaited(turnOnMedia(context, ref, session.devices.control(kind))),
    );
  }

  void _showTurnOnBlocked((MediaKind, TurnOnBlocker) blocked) {
    if (!mounted) return;
    final (kind, blocker) = blocked;
    final device = switch (kind) {
      MediaKind.microphone => 'microphone',
      MediaKind.camera => 'camera',
    };
    final (title, message) = switch (blocker) {
      TurnOnBlocker.keeperAway => (
        "You can't unmute right now",
        "The keeper is away. You can unmute once they're back.",
      ),
      TurnOnBlocker.connection => (
        "Couldn't turn on your $device",
        'Check your connection and try again.',
      ),
    };
    _notificationController.showTimed(
      context,
      icon: switch (kind) {
        MediaKind.microphone => TotemIcons.microphoneOff,
        MediaKind.camera => TotemIcons.cameraOff,
      },
      title: title,
      message: message,
    );
  }

  @override
  void dispose() {
    unawaited(_deviceNoticeSubscription?.cancel());
    unawaited(_turnOnBlockedSubscription?.cancel());
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

  Widget _buildAdmissionOrientation(String? prompt, {required bool desktop}) {
    final size = MediaQuery.sizeOf(context);
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 420,
        maxHeight: size.height * (desktop ? 0.65 : 0.4),
      ),
      child: Padding(
        padding: EdgeInsets.all(desktop ? 24 : 16),
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
      top: 8,
      child: SafeArea(
        bottom: false,
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

  void _onAudioRouteChanged(
    SessionDeviceState next, {
    required bool speakerChanged,
  }) {
    _notificationController.showTimed(
      context,
      icon: next.isSpeakerphoneEnabled
          ? TotemIcons.speakerOn
          : TotemIcons.speakerOff,
      title: speakerChanged && next.isSpeakerphoneEnabled
          ? 'Audio switched to speakers'
          : 'Audio switched to another device',
      message: 'Your audio output has changed.',
      urgentLatestWinsCategory: 'audio-route',
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
          routeRevision: state.audioRouteRevision,
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
          speakerChanged: previous.speakerphone != next.speakerphone,
        );
      },
    );

    if (kIsWeb) {
      ref.listen(mediaDevicesProvider, (previous, next) {
        if (!mounted ||
            !audioRouteNotifier.audioRouteNotificationsEnabled ||
            ref.read(connectionStateProvider) !=
                RoomConnectionState.connected) {
          return;
        }
        final deviceState = ref.read(
          sessionDeviceControllerProvider(currentSession),
        );
        if (!deviceState.supportsAudioOutputSelection ||
            deviceState.selectedAudioOutputDeviceId != null) {
          return;
        }
        final oldOutputs = previous?.value;
        final newOutputs = next.value;
        if (oldOutputs == null || newOutputs == null) return;
        final oldDefault = oldOutputs
            .where((device) => device.kind == MediaDeviceKind.audioOutput)
            .firstOrNull;
        final newDefault = newOutputs
            .where((device) => device.kind == MediaDeviceKind.audioOutput)
            .firstOrNull;
        if (oldDefault?.id != newDefault?.id ||
            oldDefault?.label != newDefault?.label) {
          _onAudioRouteChanged(deviceState, speakerChanged: false);
        }
      });
    }

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

    final dockChatSlot = shouldDockSessionChat(context);
    // Flag changes are handled via listen so opening/closing chat does not
    // rebuild the whole room tree. Layout (resize) changes are detected here.
    ref.listen(sessionChatOpenProvider, (previous, next) {
      _scheduleChatPresentationSync();
    });
    if (_lastSyncedDockChatSlot != dockChatSlot) {
      _lastSyncedDockChatSlot = dockChatSlot;
      _scheduleChatPresentationSync();
    }
    // The Keeper-approved, fully activated local connection can enter without
    // waiting for a separate roster packet. The roster still filters everyone
    // shown to other participants.
    final waitingForAdmission =
        widget.showAdmissionOrientation && !widget.admissionReady;
    final admissionEstablished =
        !waitingForAdmission &&
        connectionState == RoomConnectionState.connected &&
        !showingDisconnectedScreen;
    final readyForOrientation =
        admissionEstablished && currentRoomScreen != RoomScreen.loading;

    final showOrientation =
        readyForOrientation &&
        roomStatus == RoomStatus.active &&
        _admissionOrientationEligible == true &&
        !_admissionOrientationDismissed;
    final admissionPrompt = showOrientation
        ? ref.watch(currentSessionPromptProvider)
        : null;

    return SessionAdmissionOverlay(
      sessionSlug: widget.sessionSlug,
      child: SessionKeyboardShortcuts(
        navigatorKey: _roomNavigatorKey,
        enableEmojiReactions:
            !waitingForAdmission && currentRoomScreen == RoomScreen.listening,
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
                                              waitingForAdmission
                                                  ? RoomScreen.loading
                                                  : currentRoomScreen,
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
                        ],
                      ),
                    ),
                    // Keep the rail mounted on wide windows even while closed so
                    // the close animation has a widget to slide out.
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
      ),
    );
  }

  void _scheduleChatPresentationSync() {
    if (_chatPresentationSyncScheduled) return;
    _chatPresentationSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatPresentationSyncScheduled = false;
      if (!mounted) return;
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
        return SpeakingTurnScreen(session: session.session!);
      case RoomScreen.listening:
        return ListeningTurnScreen(session: session.session!);
    }
  }
}

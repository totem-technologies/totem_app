import 'dart:async';
import 'dart:ui' as ui;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/screen_protection_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/screens/error_screen.dart';
import 'package:totem_core/features/sessions/screens/listening_turn_screen.dart';
import 'package:totem_core/features/sessions/screens/more_options_popup.dart';
import 'package:totem_core/features/sessions/screens/receive_totem_screen.dart';
import 'package:totem_core/features/sessions/screens/session_disconnected.dart';
import 'package:totem_core/features/sessions/screens/speaking_turn_screen.dart';
import 'package:totem_core/features/sessions/widgets/background.dart';
import 'package:totem_core/features/sessions/widgets/emoji_bar.dart';
import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

class VideoSessionScreen extends ConsumerStatefulWidget {
  const VideoSessionScreen({
    required this.sessionSlug,
    required this.loadingScreen,
    super.key,
  });

  final String sessionSlug;
  final Widget loadingScreen;

  @override
  ConsumerState<VideoSessionScreen> createState() => _VideoSessionScreenState();
}

// Use shared helper to determine transient join disconnect reasons.

class _VideoSessionScreenState extends ConsumerState<VideoSessionScreen> {
  static var _didWarmEmojiGlyphs = false;

  final _roomNavigatorKey = GlobalKey<NavigatorState>();
  final _notificationController = NotificationController();

  NotificationRequest? _closeKeeperLeftNotification;
  Timer? _timeRemainingWarningTimer;
  String? _timeRemainingWarningSessionSlug;
  bool _hasShownTimeRemainingWarning = false;
  bool? _lastKeeperDisconnectedState;
  RoomStatus? _lastKeeperDisconnectedRoomStatus;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _listenToBatteryChanges();
    _warmEmojiGlyphs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyScreenCapturePolicy();
    });
  }

  @override
  void dispose() {
    _notificationController.dismissAll();
    _clearTimeRemainingWarningTimer();
    _disableScreenProtection();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _batterySubscription?.cancel();
    TotemRouter.instance.setTabCloseConfirmationEnabled(false);
    super.dispose();
  }

  void _applyScreenCapturePolicy() {
    if (!mounted) return;

    try {
      final email = ref.read(authControllerProvider).user?.email;
      final shouldProtect =
          !ScreenProtectionService.shouldAllowScreenCaptureForEmail(email);
      ScreenProtectionService.setCaptureProtectionEnabled(shouldProtect);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error applying screen capture policy',
      );
    }
  }

  void _disableScreenProtection() {
    try {
      ScreenProtectionService.setCaptureProtectionEnabled(false);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error disabling screen capture policy',
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

  void _closeKeeperDisconnectedNotification() {
    _closeKeeperLeftNotification?.dismissActive();
    _closeKeeperLeftNotification = null;
  }

  void _clearTimeRemainingWarningTimer() {
    _timeRemainingWarningTimer?.cancel();
    _timeRemainingWarningTimer = null;
  }

  void _scheduleTimeRemainingWarning(
    SessionDetailSchema? sessionEvent,
    RoomConnectionState connectionState,
    RoomStatus roomStatus,
  ) {
    if (sessionEvent == null ||
        connectionState != RoomConnectionState.connected ||
        roomStatus != RoomStatus.active ||
        sessionEvent.ended) {
      _clearTimeRemainingWarningTimer();
      return;
    }

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
    final delay = warningTime.difference(DateTime.now());

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
      _closeKeeperDisconnectedNotification();
      return;
    }

    if (_closeKeeperLeftNotification != null) {
      // do not show again
      return;
    }

    _closeKeeperLeftNotification?.dismissActive();
    _closeKeeperLeftNotification = null;
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
    RoomConnectionState connectionState,
  ) {
    if (connectionState != RoomConnectionState.connected ||
        roomStatus == RoomStatus.ended) {
      _closeKeeperDisconnectedNotification();
      return;
    }

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
    final currentRoomScreen = ref.watch(resolveCurrentScreenProvider)!;
    final currentSessionEvent = ref.watch(currentSessionEventProvider);
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

    _notificationController.blocked =
        currentRoomScreen == RoomScreen.disconnected ||
        currentRoomScreen == RoomScreen.error;

    _scheduleTimeRemainingWarning(
      currentSessionEvent,
      connectionState,
      roomStatus,
    );

    _syncKeeperDisconnectedNotification(
      hasKeeperDisconnected,
      roomStatus,
      connectionState,
    );

    ref
      ..listen(
        emojiReactionsProvider,
        (previous, next) {
          if (!mounted) return;

          final isListeningTurnScreen =
              currentRoomScreen == RoomScreen.listening;

          for (final reaction in next.where(
            (reaction) => !reaction.displayed,
          )) {
            emojiNotifier.displayReaction(
              context,
              reaction,
              isListeningTurnScreen,
            );
          }
        },
      )
      ..listen(
        sessionLivekitErrorProvider,
        (previous, next) {
          if (next == null) return;
          if (previous?.toString() == next.toString()) return;
          _onLivekitError(next);
        },
      )
      ..listen(
        hasKeeperDisconnectedProvider,
        (previous, next) {
          _syncKeeperDisconnectedNotification(
            next,
            roomStatus,
            connectionState,
          );
        },
      )
      ..listen(
        resolveCurrentScreenProvider,
        (previous, next) {
          if (previous != RoomScreen.receiving &&
              next == RoomScreen.receiving) {
            cuesService.playTotemReceivedCue();
          }

          if (next == RoomScreen.disconnected || next == RoomScreen.error) {
            _notificationController.blocked = true;
            _clearTimeRemainingWarningTimer();
          } else {
            _notificationController.blocked = false;
          }
        },
      )
      ..listen(
        roomStatusProvider,
        (previous, next) {
          final isRoomOpeningTransition =
              previous == RoomStatus.waitingRoom && next == RoomStatus.active;
          final isRoomClosingTransition =
              previous == RoomStatus.active && next == RoomStatus.ended;

          if (isRoomOpeningTransition || isRoomClosingTransition) {
            cuesService.playSessionTransitionCue();
          }

          switch (next) {
            case RoomStatus.waitingRoom:
              TotemRouter.instance.setTabCloseConfirmationEnabled(false);
            case RoomStatus.active:
              TotemRouter.instance.setTabCloseConfirmationEnabled(true);
            case RoomStatus.ended:
              _notificationController.blocked = true;
              _clearTimeRemainingWarningTimer();
              TotemRouter.instance.setTabCloseConfirmationEnabled(false);
          }
        },
      )
      ..listen(
        connectionStateProvider,
        (previous, next) {
          if (next == RoomConnectionState.disconnected ||
              next == RoomConnectionState.error) {
            _notificationController.blocked = true;
            _clearTimeRemainingWarningTimer();
          } else {
            _notificationController.blocked = false;
          }
        },
      );

    if (currentSession != null) {
      final audioRouteNotifier = ref.read(
        sessionDeviceControllerProvider(currentSession).notifier,
      );

      ref.listen(
        sessionDeviceControllerProvider(currentSession),
        (previous, next) {
          if (!mounted || previous == null) return;

          if (!audioRouteNotifier.audioRouteNotificationsEnabled) return;

          if (connectionState != RoomConnectionState.connected) return;

          final routeChanged =
              previous.isSpeakerphoneEnabled != next.isSpeakerphoneEnabled ||
              previous.selectedAudioOutputDeviceId !=
                  next.selectedAudioOutputDeviceId;

          if (!routeChanged) return;

          _onAudioRouteChanged(next);
        },
      );
    }

    if (currentSession == null || currentSessionEvent == null) {
      return widget.loadingScreen;
    }

    if (currentSessionEvent.ended || roomStatus == RoomStatus.ended) {
      return SessionDisconnectedScreen(
        session: currentSessionEvent,
        disconnectReason: disconnectReason,
      );
    }

    // transient join recovery handled earlier

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

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
        final shouldPop = await showLeaveDialog(context) ?? false;
        if (context.mounted && shouldPop) {
          await currentSession.leave();
          if (!context.mounted) return;
          TotemRouter.instance.popOrHome(context);
        }
      },
      child: RoomBackground(
        status: roomStatus,
        child: Navigator(
          key: _roomNavigatorKey,
          clipBehavior: Clip.none,
          onDidRemovePage: (page) => {},
          pages: [
            MaterialPage(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: _buildBody(
                        currentSession,
                        currentRoomScreen,
                        currentSessionEvent,
                        disconnectReason,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Overlay(key: EmojiReactions.emojiOverlayKey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    SessionController session,
    RoomScreen screen,
    SessionDetailSchema sessionEvent,
    DisconnectReason? disconnectReason,
  ) {
    switch (screen) {
      case RoomScreen.error:
        return SessionErrorScreen(onRetry: session.join);
      case RoomScreen.loading:
        return widget.loadingScreen;
      case RoomScreen.disconnected:
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
            return SpeakingTurnScreen(event: session.event!);
          },
        );
      case RoomScreen.listening:
        return ListeningTurnScreen(
          event: session.event!,
        );
    }
  }
}

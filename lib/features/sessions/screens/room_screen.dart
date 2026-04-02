import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/screens/error_screen.dart';
import 'package:totem_app/features/sessions/screens/my_turn.dart';
import 'package:totem_app/features/sessions/screens/not_my_turn.dart';
import 'package:totem_app/features/sessions/screens/options_sheet.dart';
import 'package:totem_app/features/sessions/screens/receive_totem_screen.dart';
import 'package:totem_app/features/sessions/screens/session_disconnected.dart';
import 'package:totem_app/features/sessions/widgets/background.dart';
import 'package:totem_app/navigation/app_router.dart';
import 'package:totem_app/shared/totem_icons.dart';
import 'package:totem_app/shared/widgets/error_screen.dart';
import 'package:totem_app/shared/widgets/popups.dart';

class VideoRoomScreen extends ConsumerStatefulWidget {
  const VideoRoomScreen({
    required this.sessionSlug,
    required this.loadingScreen,
    super.key,
  });

  final String sessionSlug;
  final Widget loadingScreen;

  @override
  ConsumerState<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends ConsumerState<VideoRoomScreen> {
  final _roomNavigatorKey = GlobalKey<NavigatorState>();
  final _notificationController = PopupController();

  VoidCallback? _closeKeeperLeftNotification;
  Timer? _timeRemainingWarningTimer;
  String? _timeRemainingWarningSessionSlug;
  bool _hasShownTimeRemainingWarning = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _listenToBatteryChanges();
  }

  @override
  void dispose() {
    _clearSessionPopups();
    _clearTimeRemainingWarningTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _batterySubscription?.cancel();
    super.dispose();
  }

  void _clearSessionPopups() {
    _closeKeeperLeftNotification?.call();
    _closeKeeperLeftNotification = null;
    _notificationController.dismissAll();
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
    showNotificationPopup(
      context,
      icon: TotemIcons.clockCircle,
      title: 'Time Remaining 5 min',
      message: 'Thanks for your participation in this session today',
      controller: _notificationController,
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
                showNotificationPopup(
                  context,
                  icon: TotemIcons.person,
                  title: 'Your battery is running low',
                  message: 'You might want to plug in.',
                  controller: _notificationController,
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
        showErrorPopup(
          context,
          icon: TotemIcons.errorOutlined,
          title: 'Something went wrong',
          message: 'Check your connection and try again.',
          controller: _notificationController,
        );
      }
    }
  }

  void _setKeeperDisconnectedNotification(bool hasKeeperDisconnected) {
    if (!mounted) return;
    _closeKeeperLeftNotification?.call();
    _closeKeeperLeftNotification = null;
    final roomStatus = ref.read(roomStatusProvider);
    if (hasKeeperDisconnected && roomStatus == RoomStatus.active) {
      _closeKeeperLeftNotification = showPermanentNotificationPopup(
        context,
        icon: TotemIcons.pause,
        title: 'The session has been paused.',
        message: 'The keeper will be right back.',
        controller: _notificationController,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = ref.watch(currentSessionProvider);
    final currentRoomScreen = ref.watch(resolveCurrentScreenProvider)!;
    final currentSessionEvent = ref.watch(currentSessionEventProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final roomStatus = ref.watch(roomStatusProvider);
    final disconnectReason = ref.watch(disconnectionReasonProvider);

    _scheduleTimeRemainingWarning(
      currentSessionEvent,
      connectionState,
      roomStatus,
    );

    ref
      ..listen(
        emojiReactionsProvider,
        (previous, next) {
          final isInNotMyTurnScreen =
              ref.read(resolveCurrentScreenProvider) == RoomScreen.notMyTurn;

          for (final reaction in next.where(
            (reaction) => !reaction.displayed,
          )) {
            ref
                .read(emojiReactionsProvider.notifier)
                .displayReaction(context, reaction, isInNotMyTurnScreen);
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
          if (previous == next) return;
          _setKeeperDisconnectedNotification(next);
        },
      )
      ..listen(
        roomStatusProvider,
        (previous, next) {
          if (next == RoomStatus.ended) {
            _clearSessionPopups();
            _clearTimeRemainingWarningTimer();
          }
        },
      )
      ..listen(
        connectionStateProvider,
        (previous, next) {
          if (next == RoomConnectionState.disconnected ||
              next == RoomConnectionState.error) {
            _clearSessionPopups();
            _clearTimeRemainingWarningTimer();
          }
        },
      );

    if (currentSession == null || currentSessionEvent == null) {
      return widget.loadingScreen;
    }

    if (currentSessionEvent.ended || roomStatus == RoomStatus.ended) {
      return RoomBackground(
        status: roomStatus,
        child: SessionDisconnectedScreen(
          session: currentSessionEvent,
          disconnectReason: disconnectReason,
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Checks if there is any other route above the first route.
        //   This route would be a modal sheet or a dialog.
        final navigator = _roomNavigatorKey.currentState;
        if (navigator?.canPop() ?? false) {
          navigator!.pop();
          return;
        }

        // If there is no other route above the first route, the user is
        // trying to leave the session.

        // If the session is not connected or connecting, leave the session.
        if (connectionState != RoomConnectionState.connecting &&
            connectionState != RoomConnectionState.connected) {
          popOrHome(context);
          return;
        }

        // If the session is connected, show a dialog to confirm the action.
        final shouldPop = await showLeaveDialog(context) ?? false;
        if (context.mounted && shouldPop) {
          popOrHome(context);
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
        return RoomErrorScreen(onRetry: session.join);
      case RoomScreen.loading:
        return widget.loadingScreen;
      case RoomScreen.disconnected:
        return SessionDisconnectedScreen(
          session: sessionEvent,
          disconnectReason: disconnectReason,
        );
      case RoomScreen.receiving:
        return const ReceiveTotemScreen();
      case RoomScreen.myTurn:
      case RoomScreen.passing:
        return Builder(
          builder: (context) {
            return MyTurn(event: session.event!);
          },
        );
      case RoomScreen.notMyTurn:
        return NotMyTurn(
          event: session.event!,
        );
    }
  }
}

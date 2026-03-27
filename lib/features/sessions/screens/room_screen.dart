import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/errors/error_handler.dart';
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

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _listenToBatteryChanges();
  }

  @override
  void dispose() {
    _closeKeeperLeftNotification?.call();
    _closeKeeperLeftNotification = null;
    _notificationController.dismissAll();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _batterySubscription?.cancel();
    super.dispose();
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
    if (hasKeeperDisconnected) {
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
    final currentSessionEvent = ref.watch(currentSessionEventProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final roomStatus = ref.watch(roomStatusProvider);
    final disconnectReason = ref.watch(disconnectionReasonProvider);

    ref
      ..listen(
        emojiReactionsProvider,
        (previous, next) {
          final isInNotMyTurnScreen =
              currentSession?.resolveCurrentScreen() == RoomScreen.notMyTurn;

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
    SessionDetailSchema sessionEvent,
    DisconnectReason? disconnectReason,
  ) {
    switch (session.resolveCurrentScreen()) {
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
        return ReceiveTotemScreen(onAcceptTotem: session.keeper.acceptTotem);
      case RoomScreen.myTurn:
      case RoomScreen.passing:
        return Builder(
          builder: (context) {
            return MyTurn(
              onPassTotem: (roundMessage) async {
                try {
                  await session.keeper.passTotem(roundMessage: roundMessage);
                  return true;
                } catch (error) {
                  if (!context.mounted) return false;
                  ErrorHandler.handleApiError(context, error);
                  return false;
                }
              },
              event: session.event!,
            );
          },
        );
      case RoomScreen.notMyTurn:
        return NotMyTurn(
          event: session.event!,
        );
    }
  }
}

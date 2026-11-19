import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/services/connectivity_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/media/session_error_presentation.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

class SessionStatusEffects extends ConsumerStatefulWidget {
  const SessionStatusEffects({
    required this.notifications,
    required this.now,
    required this.child,
    super.key,
  });
  final NotificationController notifications;
  final ValueGetter<DateTime> now;
  final Widget child;
  @override
  ConsumerState<SessionStatusEffects> createState() =>
      _SessionStatusEffectsState();
}

class _SessionStatusEffectsState extends ConsumerState<SessionStatusEffects> {
  NotificationController get _notificationController => widget.notifications;
  NotificationRequest? _closeKeeperLeftNotification;
  NotificationRequest? _offlineNotification;
  Timer? _timeRemainingWarningTimer;
  String? _timeRemainingWarningSessionSlug;
  bool _hasShownTimeRemainingWarning = false;
  bool? _lastIsOffline;
  bool? _lastKeeperDisconnectedState;
  RoomStatus? _lastKeeperDisconnectedRoomStatus;
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

  void _onLivekitError(Object error) {
    if (isSessionErrorShownInline(error)) {
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
  void dispose() {
    _clearTimeRemainingWarningTimer();
    _offlineNotification?.dismissImmediately();
    _closeKeeperLeftNotification?.dismissImmediately();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = ref.watch(currentSessionProvider);
    final currentRoomScreen = ref.watch(resolveCurrentScreenProvider);
    final currentSessionEvent = ref.watch(currentSessionEventProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final roomStatus = ref.watch(roomStatusProvider);
    final hasKeeperDisconnected = ref.watch(hasKeeperDisconnectedProvider);
    final disconnectReason = ref.watch(disconnectionReasonProvider);
    if (currentSession == null ||
        currentSessionEvent == null ||
        currentRoomScreen == null ||
        (currentRoomScreen == RoomScreen.loading &&
            connectionState == RoomConnectionState.disconnected &&
            isTransientJoinDisconnectReason(disconnectReason))) {
      return widget.child;
    }
    final showingDisconnectedScreen =
        currentSessionEvent.ended ||
        roomStatus == RoomStatus.ended ||
        currentRoomScreen == RoomScreen.disconnected ||
        currentRoomScreen == RoomScreen.error;
    _notificationController.blocked = showingDisconnectedScreen;

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
      ..listen(sessionLivekitErrorProvider, (previous, next) {
        if (next == null) return;
        if (identical(previous, next)) return;
        _onLivekitError(next);
      })
      ..listen(resolveCurrentScreenProvider, (previous, next) {
        if (next == RoomScreen.disconnected || next == RoomScreen.error) {
          _clearTimeRemainingWarningTimer();
          _dismissOfflineNotification(immediately: true);
        }
      })
      ..listen(roomStatusProvider, (previous, next) {
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

    return widget.child;
  }
}

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/services/screen_protection_service.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

import 'package:totem_core/shared/router.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

class SessionEnvironmentEffects extends ConsumerStatefulWidget {
  const SessionEnvironmentEffects({
    required this.notifications,
    required this.child,
    super.key,
  });
  final NotificationController notifications;
  final Widget child;
  @override
  ConsumerState<SessionEnvironmentEffects> createState() =>
      _SessionEnvironmentEffectsState();
}

class _SessionEnvironmentEffectsState
    extends ConsumerState<SessionEnvironmentEffects> {
  NotificationController get _notificationController => widget.notifications;
  VoidCallback? _pageExitHandler;
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    ref.listenManual(currentSessionProvider, (_, session) {
      final handler = session?.leaveOnPageExit;
      if (handler == _pageExitHandler) return;
      _pageExitHandler = handler;
      TotemRouter.instance.setPageExitHandler(handler);
    }, fireImmediately: true);
    _listenToBatteryChanges();
    ref.listenManual(
      authControllerProvider.select((state) => state.user?.email),
      (_, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyScreenCapturePolicy();
        });
      },
      fireImmediately: true,
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
          _shouldShowLowBatteryWarning = false;
        } else if (state == BatteryState.discharging) {
          try {
            final level = await battery.batteryLevel;
            if (!mounted) return;
            if (level <= 20 && !_shouldShowLowBatteryWarning) {
              _shouldShowLowBatteryWarning = true;
              if (mounted) {
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

  @override
  void dispose() {
    unawaited(_batterySubscription?.cancel());
    _setScreenProtection(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    TotemRouter.instance.setTabCloseConfirmationEnabled(false);
    if (_pageExitHandler case final handler?) {
      TotemRouter.instance.clearPageExitHandler(handler);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(roomStatusProvider);
    final screen = ref.watch(resolveCurrentScreenProvider);
    final ended = ref.watch(
      currentSessionEventProvider.select((event) => event?.ended ?? false),
    );
    TotemRouter.instance.setTabCloseConfirmationEnabled(
      status != RoomStatus.waitingRoom &&
          status != RoomStatus.ended &&
          !ended &&
          screen != RoomScreen.disconnected &&
          screen != RoomScreen.error,
    );
    return widget.child;
  }
}

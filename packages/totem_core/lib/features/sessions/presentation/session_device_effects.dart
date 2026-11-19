import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/permissions/ui/recovery.dart';
import 'package:totem_core/features/permissions/ui/recovery_content.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/media_devices_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';

import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

class SessionDeviceEffects extends ConsumerStatefulWidget {
  const SessionDeviceEffects({
    required this.notifications,
    required this.child,
    super.key,
  });
  final NotificationController notifications;
  final Widget child;
  @override
  ConsumerState<SessionDeviceEffects> createState() =>
      _SessionDeviceEffectsState();
}

class _SessionDeviceEffectsState extends ConsumerState<SessionDeviceEffects> {
  NotificationController get _notificationController => widget.notifications;
  int _sourceGeneration = 0;
  StreamSubscription<MediaKind>? _deviceNoticeSubscription;
  StreamSubscription<(MediaKind, TurnOnBlocker)>? _turnOnBlockedSubscription;
  @override
  void initState() {
    super.initState();
    ref.listenManual(currentSessionProvider, (_, session) {
      final generation = ++_sourceGeneration;
      unawaited(_deviceNoticeSubscription?.cancel());
      _deviceNoticeSubscription = session?.devices.deviceNeedsAttention.listen((
        kind,
      ) {
        if (mounted && generation == _sourceGeneration) _showDeviceNotice(kind);
      });
      unawaited(_turnOnBlockedSubscription?.cancel());
      _turnOnBlockedSubscription = session?.devices.turnOnBlocked.listen((
        blocked,
      ) {
        if (mounted && generation == _sourceGeneration) {
          _showTurnOnBlocked(blocked);
        }
      });
    }, fireImmediately: true);
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

  @override
  void dispose() {
    _sourceGeneration++;
    unawaited(_deviceNoticeSubscription?.cancel());
    unawaited(_turnOnBlockedSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = ref.watch(currentSessionProvider);
    if (currentSession == null) return widget.child;
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

    return widget.child;
  }
}

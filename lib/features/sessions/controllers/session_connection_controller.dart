import 'dart:async';

import 'package:livekit_client/livekit_client.dart' hide SessionOptions, logger;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/features/sessions/controllers/session_controller.dart';
import 'package:totem_app/features/sessions/controllers/session_types.dart';

class SessionConnectionController {
  SessionConnectionController({
    required this.onRoomEvent,
    required this.onConnected,
    required this.onDisconnected,
    required this.onDataReceived,
    required this.onParticipantDisconnected,
    required this.onParticipantConnected,
  });

  final VoidCallback onRoomEvent;
  final VoidCallback onConnected;
  final DisconnectReasonCallback onDisconnected;
  final DataReceivedEventCallback onDataReceived;
  final ParticipantDisconnectedEventCallback onParticipantDisconnected;
  final ParticipantConnectedEventCallback onParticipantConnected;

  Room? room;
  EventsListener<RoomEvent>? _listener;

  Future<Room> initialize({
    required RoomOptions roomOptions,
    required String url,
    required String token,
  }) async {
    room ??= Room(roomOptions: roomOptions);
    await room!.prepareConnection(url, token);

    _listener ??= room!.createListener()
      ..on((_) => onRoomEvent())
      ..on<RoomConnectedEvent>((_) => onConnected())
      ..on<RoomDisconnectedEvent>((event) => onDisconnected(event.reason))
      ..on<DataReceivedEvent>(onDataReceived)
      ..on<ParticipantDisconnectedEvent>(onParticipantDisconnected)
      ..on<ParticipantConnectedEvent>(onParticipantConnected);

    return room!;
  }

  Future<void> connect({required String url, required String token}) async {
    await room?.connect(url, token);
  }

  Future<void> disconnect() async {
    await room?.disconnect();
  }

  Future<void> dispose() async {
    try {
      _listener
        ?..cancelAll()
        ..dispose();
    } catch (_) {}
    _listener = null;

    try {
      room?.dispose();
    } catch (_) {}
    room = null;
  }

  Future<void> apply({
    required Room room,
    required SessionRoomState state,
    required bool? cameraEnabledOverride,
    required bool? microphoneEnabledOverride,
    required SessionOptions? sessionOptions,
    required BoolGetter isCurrentUserKeeper,
    required AsyncCallback enableMicrophone,
    required AsyncCallback disableMicrophone,
  }) async {
    final cameraEnabled =
        cameraEnabledOverride ?? (sessionOptions?.cameraEnabled ?? false);
    room.localParticipant?.setCameraEnabled(cameraEnabled);

    // If joined in waiting room without keeper, user can start unmuted.
    // During active session, only current speaker can start unmuted.
    // Otherwise only keeper can start unmuted.
    final shouldEnableMicrophone = () {
      if (state.roomState.status == RoomStatus.waitingRoom &&
          !state.hasKeeper) {
        return microphoneEnabledOverride ?? sessionOptions?.microphoneEnabled;
      }
      if (state.roomState.status == RoomStatus.active &&
          state.speakingNow == room.localParticipant?.identity) {
        return microphoneEnabledOverride ?? sessionOptions?.microphoneEnabled;
      }
      return isCurrentUserKeeper() &&
          (microphoneEnabledOverride ??
              sessionOptions?.microphoneEnabled ??
              false);
    }();

    if (shouldEnableMicrophone ?? false) {
      await enableMicrophone();
    } else {
      await disableMicrophone();
    }
  }
}

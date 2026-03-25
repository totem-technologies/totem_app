import 'dart:async';

import 'package:livekit_client/livekit_client.dart' hide logger;

class SessionConnectionController {
  SessionConnectionController({
    required this.onRoomEvent,
    required this.onConnected,
    required this.onDisconnected,
    required this.onDataReceived,
    required this.onParticipantDisconnected,
    required this.onParticipantConnected,
  });

  final void Function() onRoomEvent;
  final void Function() onConnected;
  final void Function(DisconnectReason? reason) onDisconnected;
  final void Function(DataReceivedEvent event) onDataReceived;
  final void Function(ParticipantDisconnectedEvent event)
  onParticipantDisconnected;
  final void Function(ParticipantConnectedEvent event) onParticipantConnected;

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
}

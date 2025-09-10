import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:totem_app/core/config/app_config.dart';

final livekitServiceProvider = Provider<LiveKitService>((ref) {
  return LiveKitService();
});

class LiveKitService {
  LiveKitService();

  Room? _room;
  EventsListener<RoomEvent>? _listener;

  Future<void> connect(String roomName, String token) async {
    _room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    _listener = _room!.createListener();

    await _room!.connect(
      'wss://${AppConfig.liveKitUrl}',
      token,
    );

    try {
      await _room!.localParticipant!.setCameraEnabled(true);
    } catch (error) {
      debugPrint('Could not publish video, error: $error');
    }
    await _room!.localParticipant!.setMicrophoneEnabled(true);
  }

  void disconnect() {
    _room?.disconnect();
    _room = null;
  }

  Room? get room => _room;
  EventsListener<RoomEvent>? get listener => _listener;
}

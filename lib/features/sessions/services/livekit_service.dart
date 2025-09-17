import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'livekit_service.g.dart';

enum SessionCommunicationTopics {
  emoji,
}

typedef OnEmojiReceived = void Function(String userIdentity, String emoji);

@immutable
class SessionOptions {
  const SessionOptions({
    required this.token,
    required this.cameraEnabled,
    required this.microphoneEnabled,
    required this.onEmojiReceived,
  });

  final String token;
  final bool cameraEnabled;
  final bool microphoneEnabled;
  final OnEmojiReceived onEmojiReceived;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SessionOptions &&
        other.token == token &&
        other.cameraEnabled == cameraEnabled &&
        other.microphoneEnabled == microphoneEnabled &&
        other.onEmojiReceived == onEmojiReceived;
  }

  @override
  int get hashCode {
    return token.hashCode ^
        cameraEnabled.hashCode ^
        microphoneEnabled.hashCode ^
        onEmojiReceived.hashCode;
  }
}

@riverpod
LiveKitService sessionService(Ref ref, SessionOptions options) {
  final service = LiveKitService(options);
  return service;
}

class LiveKitService {
  LiveKitService(this.initialOptions) {
    room = RoomContext(
      url: 'wss://totem-d7esbgcp.livekit.cloud',
      token: initialOptions.token,
      connect: true,
      onConnected: () {
        _onConnected(
          cameraEnabled: initialOptions.cameraEnabled,
          microphoneEnabled: initialOptions.microphoneEnabled,
        );
      },
    );

    _listener = room.room.createListener();
    _listener.on<DataReceivedEvent>(_onDataReceived);
  }

  final SessionOptions initialOptions;
  late final RoomContext room;
  late final EventsListener<RoomEvent> _listener;

  void _onConnected({
    required bool cameraEnabled,
    required bool microphoneEnabled,
  }) {
    room.localParticipant?.setCameraEnabled(cameraEnabled);
    room.localParticipant?.setMicrophoneEnabled(microphoneEnabled);
  }

  void _onDataReceived(DataReceivedEvent event) {
    if (event.topic == null || event.participant == null) return;

    if (event.topic == SessionCommunicationTopics.emoji.name) {
      _onEmojiReceived(
        event.participant!.identity,
        const Utf8Decoder().convert(event.data),
      );
    }
  }

  void _onEmojiReceived(String userIdentity, String emoji) {
    debugPrint('Emoji received: $emoji from user: $userIdentity');
    initialOptions.onEmojiReceived(userIdentity, emoji);
  }

  void sendEmoji(String emoji) {
    room.localParticipant?.publishData(
      const Utf8Encoder().convert(emoji),
      topic: SessionCommunicationTopics.emoji.name,
    );
    debugPrint('Session => Sending emoji: $emoji');
  }
}

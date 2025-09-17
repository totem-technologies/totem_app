import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'livekit_service.g.dart';

enum SessionCommunicationTopics {
  emoji('lk-emoji-topic'),

  /// Most of the chat functionality is handled by [ChatContextMixin]
  chat('lk-chat-topic');

  const SessionCommunicationTopics(this.topic);

  final String topic;
}

typedef OnEmojiReceived = void Function(String userIdentity, String emoji);
typedef OnMessageReceived = void Function(String userIdentity, String message);

@immutable
class SessionOptions {
  const SessionOptions({
    required this.token,
    required this.cameraEnabled,
    required this.microphoneEnabled,
    required this.onEmojiReceived,
    required this.onMessageReceived,
  });

  final String token;
  final bool cameraEnabled;
  final bool microphoneEnabled;
  final OnEmojiReceived onEmojiReceived;
  final OnMessageReceived onMessageReceived;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SessionOptions &&
        other.token == token &&
        other.cameraEnabled == cameraEnabled &&
        other.microphoneEnabled == microphoneEnabled &&
        other.onEmojiReceived == onEmojiReceived &&
        other.onMessageReceived == onMessageReceived;
  }

  @override
  int get hashCode {
    return token.hashCode ^
        cameraEnabled.hashCode ^
        microphoneEnabled.hashCode ^
        onEmojiReceived.hashCode ^
        onMessageReceived.hashCode;
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

    if (event.topic == SessionCommunicationTopics.emoji.topic) {
      _onEmojiReceived(
        event.participant!.identity,
        const Utf8Decoder().convert(event.data),
      );
    } else if (event.topic == SessionCommunicationTopics.chat.topic) {
      initialOptions.onMessageReceived(
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
      topic: SessionCommunicationTopics.emoji.topic,
    );
    debugPrint('Session => Sending emoji: $emoji');
  }
}

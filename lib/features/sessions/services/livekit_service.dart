import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_components/livekit_components.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/models/event_detail_schema.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/models/session_state.dart';

part 'livekit_service.g.dart';

enum SessionCommunicationTopics {
  /// Topic for sending emojis.
  emoji('lk-emoji-topic'),

  /// Topic for sending chat messages.
  ///
  /// Most of the chat functionality is handled by [ChatContextMixin]
  chat('lk-chat-topic'),

  /// Topic for sending session state updates.
  state('lk-session-state-topic');

  const SessionCommunicationTopics(this.topic);

  final String topic;
}

typedef OnEmojiReceived = void Function(String userIdentity, String emoji);
typedef OnMessageReceived = void Function(String userIdentity, String message);
typedef OnLivekitError = void Function(LiveKitException error);

@immutable
class SessionOptions {
  const SessionOptions({
    required this.event,
    required this.token,
    required this.cameraEnabled,
    required this.microphoneEnabled,
    required this.onEmojiReceived,
    required this.onMessageReceived,
    required this.onLivekitError,
    required this.onReceiveTotem,
  });

  final EventDetailSchema event;
  final String token;
  final bool cameraEnabled;
  final bool microphoneEnabled;
  final OnEmojiReceived onEmojiReceived;
  final OnMessageReceived onMessageReceived;
  final OnLivekitError onLivekitError;
  final VoidCallback onReceiveTotem;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SessionOptions &&
        other.event == event &&
        other.token == token &&
        other.cameraEnabled == cameraEnabled &&
        other.microphoneEnabled == microphoneEnabled &&
        other.onEmojiReceived == onEmojiReceived &&
        other.onMessageReceived == onMessageReceived &&
        other.onLivekitError == onLivekitError &&
        other.onReceiveTotem == onReceiveTotem;
  }

  @override
  int get hashCode {
    return event.hashCode ^
        token.hashCode ^
        cameraEnabled.hashCode ^
        microphoneEnabled.hashCode ^
        onEmojiReceived.hashCode ^
        onMessageReceived.hashCode ^
        onLivekitError.hashCode ^
        onReceiveTotem.hashCode;
  }
}

@riverpod
LiveKitService sessionService(Ref ref, SessionOptions options) {
  final service = LiveKitService(options)
    ..addListener(() {
      ref.notifyListeners();
    });
  return service;
}

enum RoomConnectionState { connecting, connected, disconnected, error }

class LiveKitService extends ValueNotifier<SessionState> {
  LiveKitService(this.initialOptions) : super(const SessionState.waiting()) {
    room = RoomContext(
      url: AppConfig.liveKitUrl,
      token: initialOptions.token,
      connect: true,
      onConnected: () {
        _onConnected(
          cameraEnabled: initialOptions.cameraEnabled,
          microphoneEnabled: initialOptions.microphoneEnabled,
        );
      },
      onDisconnected: _onDisconnected,
      onError: _onError,
    );

    _listener = room.room.createListener();
    _listener.on<DataReceivedEvent>(_onDataReceived);

    room.addListener(_propagateRoomChanges);
  }

  void _propagateRoomChanges() {
    if (room.room.metadata != _lastMetadata) {
      _lastMetadata = room.room.metadata;
      if (_lastMetadata != null) {
        try {
          debugPrint(
            'Session => Updating session state from room metadata',
          );
          final newState = SessionState.fromJson(
            jsonDecode(_lastMetadata!) as Map<String, dynamic>,
          );
          _onStateChanged(newState);
        } catch (e) {
          debugPrint('Error decoding session state: $e');
        }
      }
    }
    notifyListeners();
  }

  final SessionOptions initialOptions;
  late final RoomContext room;
  late final EventsListener<RoomEvent> _listener;

  String? _lastMetadata;
  SessionState get state => value;

  bool get isKeeper {
    return initialOptions.event.space.author.slug ==
        room.localParticipant?.identity;
  }

  RoomConnectionState _connectionState = RoomConnectionState.connecting;
  RoomConnectionState get connectionState => _connectionState;

  void _onConnected({
    required bool cameraEnabled,
    required bool microphoneEnabled,
  }) {
    if (room.localParticipant != null) {
      room.localParticipant!.setCameraEnabled(cameraEnabled);
      room.localParticipant!.setMicrophoneEnabled(microphoneEnabled);
    }

    _connectionState = RoomConnectionState.connected;
    notifyListeners();
  }

  void _onDisconnected() {
    _connectionState = RoomConnectionState.disconnected;
    notifyListeners();
  }

  void _onError(LiveKitException? error) {
    if (error == null) return;
    debugPrint('LiveKit error: $error');

    ErrorHandler.handleLivekitError(error);

    _connectionState = RoomConnectionState.error;
    notifyListeners();
    initialOptions.onLivekitError(error);
  }

  void _onDataReceived(DataReceivedEvent event) {
    if (event.topic == null || event.participant == null) return;

    if (event.topic == SessionCommunicationTopics.state.topic) {
      try {
        debugPrint(
          'Session => Updating session state',
        );
        if (room.room.metadata != null) {
          final newState = SessionState.fromJson(
            jsonDecode(room.room.metadata!) as Map<String, dynamic>,
          );
          _onStateChanged(newState);
        }
      } catch (e) {
        debugPrint('Error decoding session state: $e');
      }
    } else if (event.topic == SessionCommunicationTopics.emoji.topic) {
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

  void _onStateChanged(SessionState newState) {
    final previousState = value;

    if (previousState != newState) {
      debugPrint('Session state changed: $newState');
      value = newState;
      notifyListeners();
    }

    if (previousState.speakingNow != newState.speakingNow) {
      if (isMyTurn) {
        debugPrint('You are now speaking');
        initialOptions.onReceiveTotem();
      } else {
        // TODO(bdlukaa): Handle you are not speaking
      }
    }
  }

  bool get isMyTurn {
    return value.speakingNow != null &&
        value.speakingNow == room.localParticipant?.identity;
  }

  void passTotem() {
    if (!isMyTurn) return;

    // TODO(bdlukaa): Invoke pass totem api
  }
}

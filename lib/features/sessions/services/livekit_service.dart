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
  chat('lk-chat-topic');

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
        other.event.slug == event.slug &&
        other.token == token;
  }

  @override
  int get hashCode {
    return event.slug.hashCode ^ token.hashCode;
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

class LiveKitService extends ChangeNotifier {
  LiveKitService(this.initialOptions) {
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
      if (_lastMetadata != null) {
        try {
          debugPrint(
            'Session => Updating session state from room metadata',
          );
          final previousState = SessionState.fromJson(
            jsonDecode(_lastMetadata!) as Map<String, dynamic>,
          );
          final newState = SessionState.fromJson(
            jsonDecode(room.room.metadata!) as Map<String, dynamic>,
          );
          _onStateChanged(previousState, newState);
        } catch (e) {
          debugPrint('Error decoding session state: $e');
        }
      }
      _lastMetadata = room.room.metadata;
    }
    notifyListeners();
  }

  final SessionOptions initialOptions;
  late final RoomContext room;
  late final EventsListener<RoomEvent> _listener;

  String? _lastMetadata;
  SessionState get state {
    if (room.room.metadata != null || _lastMetadata != null) {
      try {
        return SessionState.fromJson(
          jsonDecode(room.room.metadata ?? _lastMetadata!)
              as Map<String, dynamic>,
        );
      } catch (error, stackTrace) {
        debugPrint('Error decoding session state: $error\n$stackTrace');
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Error decoding session state from metadata',
        );
      }
    }
    return const SessionState.waiting();
  }

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

  void _onStateChanged(SessionState previousState, SessionState newState) {
    if (previousState != newState) {
      debugPrint('Session state changed: $newState');
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
    return state.speakingNow != null &&
        state.speakingNow == room.localParticipant?.identity;
  }

  void passTotem() {
    if (!isMyTurn) return;

    // TODO(bdlukaa): Invoke pass totem api
  }
}

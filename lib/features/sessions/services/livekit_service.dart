import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide ChatMessage;
import 'package:livekit_components/livekit_components.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/features/sessions/models/session_state.dart';

part 'livekit_service.g.dart';

enum SessionCommunicationTopics {
  emoji('lk-emoji-topic'),
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
    required this.eventSlug,
    required this.token,
    required this.cameraEnabled,
    required this.microphoneEnabled,
    required this.onEmojiReceived,
    required this.onMessageReceived,
    required this.onLivekitError,
    required this.onReceiveTotem,
  });

  final String eventSlug;
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
        other.eventSlug == eventSlug &&
        other.token == token;
  }

  @override
  int get hashCode => eventSlug.hashCode ^ token.hashCode;
}

enum RoomConnectionState { connecting, connected, disconnected, error }

@immutable
class LiveKitState {
  const LiveKitState({
    this.connectionState = RoomConnectionState.connecting,
    this.sessionState = const SessionState.waiting(),
  });

  final RoomConnectionState connectionState;
  final SessionState sessionState;

  bool isMyTurn(RoomContext room) {
    return sessionState.speakingNow != null &&
        sessionState.speakingNow == room.localParticipant?.identity;
  }

  LiveKitState copyWith({
    RoomConnectionState? connectionState,
    SessionState? sessionState,
  }) {
    return LiveKitState(
      connectionState: connectionState ?? this.connectionState,
      sessionState: sessionState ?? this.sessionState,
    );
  }
}

@riverpod
class LiveKitService extends _$LiveKitService {
  late final RoomContext room;
  late final EventsListener<RoomEvent> _listener;
  late final MobileTotemApi _apiService;
  late final SessionOptions _options;
  String? _lastMetadata;

  @override
  LiveKitState build(SessionOptions options) {
    _options = options;
    _apiService = ref.read(mobileApiServiceProvider);

    room = RoomContext(
      url: AppConfig.liveKitUrl,
      token: _options.token,
      connect: true,
      onConnected: _onConnected,
      onDisconnected: _onDisconnected,
      onError: _onError,
    );

    _listener = room.room.createListener();
    _listener.on<DataReceivedEvent>(_onDataReceived);
    room.addListener(_onRoomChanges);

    ref.onDispose(() {
      debugPrint('Disposing LiveKitService and closing connections.');
      unawaited(_listener.dispose());
      room
        ..removeListener(_onRoomChanges)
        ..dispose();
    });

    return const LiveKitState();
  }

  void _onConnected() {
    if (room.localParticipant == null) return;

    unawaited(room.localParticipant!.setCameraEnabled(_options.cameraEnabled));
    unawaited(
      room.localParticipant!.setMicrophoneEnabled(_options.microphoneEnabled),
    );
    state = state.copyWith(connectionState: RoomConnectionState.connected);
  }

  void _onDisconnected() {
    state = state.copyWith(connectionState: RoomConnectionState.disconnected);
  }

  void _onError(LiveKitException? error) {
    if (error == null) return;
    debugPrint('LiveKit error: $error');
    ErrorHandler.handleLivekitError(error);
    state = state.copyWith(connectionState: RoomConnectionState.error);
    _options.onLivekitError(error);
  }

  void _onRoomChanges() {
    final metadata = room.room.metadata;
    if (metadata != _lastMetadata) {
      final previousState = SessionState.fromMetadata(_lastMetadata);
      final newState = SessionState.fromMetadata(metadata);

      if (previousState.speakingNow != newState.speakingNow &&
          newState.speakingNow == room.localParticipant?.identity) {
        debugPrint('You are now speaking');
        _options.onReceiveTotem();
      }

      state = state.copyWith(sessionState: newState);
      _lastMetadata = metadata;
    }
  }

  void _onDataReceived(DataReceivedEvent event) {
    if (event.topic == null || event.participant == null) return;
    final data = const Utf8Decoder().convert(event.data);

    if (event.topic == SessionCommunicationTopics.emoji.topic) {
      _options.onEmojiReceived(event.participant!.identity, data);
    } else if (event.topic == SessionCommunicationTopics.chat.topic) {
      try {
        final message = ChatMessage.fromMap(
          jsonDecode(data) as Map<String, dynamic>,
          event.participant,
        );
        _options.onMessageReceived(
          event.participant!.identity,
          message.message,
        );
      } catch (error, stackTrace) {
        debugPrint('Error decoding chat message: $error');
        debugPrintStack(stackTrace: stackTrace);
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Error decoding chat message',
        );
      }
    }
  }

  /// Pass the totem to the next participant in the speaking order.
  ///
  /// This fails silently if it's not the user's turn.
  Future<void> passTotem() async {
    if (!state.isMyTurn(room)) return;
    try {
      await _apiService.meetings.totemMeetingsMobileApiPassTotemEndpoint(
        eventSlug: _options.eventSlug,
      );
    } catch (error, stackTrace) {
      debugPrint('Error passing totem: $error');
      debugPrintStack(stackTrace: stackTrace);
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error passing totem',
      );
    }
  }

  /// Pass the totem to the next participant in the speaking order.
  ///
  /// This fails silently if it's not the user's turn.
  Future<void> acceptTotem() async {
    if (!state.isMyTurn(room)) return;
    try {
      await _apiService.meetings.totemMeetingsMobileApiAcceptTotemEndpoint(
        eventSlug: _options.eventSlug,
      );
    } catch (error, stackTrace) {
      debugPrint('Error accepting totem: $error');
      debugPrintStack(stackTrace: stackTrace);
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error accepting totem',
      );
    }
  }

  /// Send an emoji to other participants.
  Future<void> sendEmoji(String emoji) async {
    await room.localParticipant?.publishData(
      const Utf8Encoder().convert(emoji),
      topic: SessionCommunicationTopics.emoji.topic,
    );
  }

  Future<void> startSession() async {
    await _apiService.meetings.totemMeetingsMobileApiStartRoomEndpoint(
      eventSlug: _options.eventSlug,
    );
  }
}

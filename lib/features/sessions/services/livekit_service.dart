import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide ChatMessage;
import 'package:livekit_components/livekit_components.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/mobile_totem_api.dart';
import 'package:totem_app/api/models/session_state.dart';
import 'package:totem_app/api/models/totem_status.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

export 'package:totem_app/api/models/session_state.dart';
export 'package:totem_app/api/models/session_status.dart';
export 'package:totem_app/features/sessions/services/utils.dart';

part 'devices_control.dart';
part 'keeper_control.dart';
part 'livekit_service.g.dart';
part 'participant_control.dart';

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
    required this.keeperSlug,
    required this.token,
    required this.cameraEnabled,
    required this.microphoneEnabled,
    required this.onEmojiReceived,
    required this.onMessageReceived,
    required this.onLivekitError,
    required this.cameraOptions,
    required this.audioOptions,
    required this.audioOutputOptions,
  });

  final String eventSlug;
  final String keeperSlug;
  final String token;
  final bool cameraEnabled;
  final bool microphoneEnabled;

  final OnEmojiReceived onEmojiReceived;
  final OnMessageReceived onMessageReceived;
  final OnLivekitError onLivekitError;

  final CameraCaptureOptions cameraOptions;
  final AudioCaptureOptions audioOptions;
  final AudioOutputOptions audioOutputOptions;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionOptions &&
        other.eventSlug == eventSlug &&
        other.keeperSlug == keeperSlug &&
        other.token == token;
  }

  @override
  int get hashCode => eventSlug.hashCode ^ keeperSlug.hashCode ^ token.hashCode;

  @override
  String toString() {
    return 'SessionOptions(eventSlug: $eventSlug, keeperSlug: $keeperSlug, '
        'token: $token, cameraEnabled: $cameraEnabled, '
        'microphoneEnabled: $microphoneEnabled)';
  }
}

enum RoomConnectionState { connecting, connected, disconnected, error }

@immutable
class LiveKitState {
  const LiveKitState({
    this.connectionState = RoomConnectionState.connecting,
    this.sessionState = const SessionState(speakingOrder: []),
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

  @override
  String toString() {
    return 'LiveKitState('
        'connectionState: $connectionState, '
        'sessionState: $sessionState'
        ')';
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
      roomOptions: RoomOptions(
        defaultCameraCaptureOptions: _options.cameraOptions,
        defaultAudioCaptureOptions: _options.audioOptions,
        defaultAudioOutputOptions: _options.audioOutputOptions,

        dynacast: true,
        // defaultVideoPublishOptions: const VideoPublishOptions(
        //   simulcast: true
        // ),
        // defaultAudioPublishOptions: const AudioPublishOptions(),

        /// https://docs.livekit.io/home/client/tracks/subscribe/#adaptive-stream
        adaptiveStream: true,
      ),
    );

    _listener = room.room.createListener();
    _listener
      ..on<DataReceivedEvent>(_onDataReceived)
      ..on<ParticipantDisconnectedEvent>(_onParticipantDisconnected)
      ..on<ParticipantConnectedEvent>(_onParticipantConnected);
    room.addListener(_onRoomChanges);

    unawaited(WakelockPlus.enable());

    ref.onDispose(() {
      debugPrint('Disposing LiveKitService and closing connections.');
      unawaited(_listener.dispose());
      room.removeListener(_onRoomChanges);
      unawaited(WakelockPlus.disable());
    });

    return const LiveKitState();
  }

  void _onConnected() {
    if (room.localParticipant == null) return;

    unawaited(room.localParticipant!.setCameraEnabled(_options.cameraEnabled));
    unawaited(
      // TODO(bdlukaa): Revisit this in the future - Microphone Starts Disabled
      // room.localParticipant!.setMicrophoneEnabled(_options.microphoneEnabled)
      room.localParticipant!.setMicrophoneEnabled(false),
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
    if (metadata == null) return;
    if (_lastMetadata == null) {
      _lastMetadata = metadata;
      state = state.copyWith(
        sessionState: SessionState.fromJson(
          jsonDecode(metadata) as Map<String, dynamic>,
        ),
      );
      return;
    }
    if (_lastMetadata != null && metadata != _lastMetadata) {
      // final previousState = SessionState.fromJson(
      //   jsonDecode(_lastMetadata!) as Map<String, dynamic>,
      // );
      final newState = SessionState.fromJson(
        jsonDecode(metadata) as Map<String, dynamic>,
      );

      // if (previousState.speakingNow != newState.speakingNow) {
      //    if (newState.speakingNow == room.localParticipant?.identity) {
      //      debugPrint('You are now speaking');
      //      _options.onReceiveTotem();
      //    }
      // }

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

  bool _hasKeeperDisconnected = false;
  bool get hasKeeperDisconnected => _hasKeeperDisconnected;

  Future<void> _onParticipantDisconnected(
    ParticipantDisconnectedEvent event,
  ) async {
    if (isKeeper(event.participant.identity)) {
      await _onKeeperLeave();
    }
  }

  void _onParticipantConnected(ParticipantConnectedEvent event) {
    if (isKeeper(event.participant.identity)) {
      _onKeeperJoin();
    }
  }

  bool isKeeper([String? userSlug]) {
    if (userSlug == null) {
      final currentUserSlug = ref.read(
        authControllerProvider.select((auth) => auth.user?.slug),
      );
      userSlug = currentUserSlug;
    }
    return _options.keeperSlug == userSlug;
  }
}

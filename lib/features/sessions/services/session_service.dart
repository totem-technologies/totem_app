import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart' hide ChatMessage, logger;
import 'package:livekit_components/livekit_components.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/api/export.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/api_service.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/shared/logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

export 'package:totem_app/api/models/session_state.dart';
export 'package:totem_app/api/models/session_status.dart';
export 'package:totem_app/features/sessions/services/utils.dart';

part 'background_control.dart';
part 'devices_control.dart';
part 'keeper_control.dart';
part 'session_service.g.dart';
part 'participant_control.dart';

enum SessionEndedReason { finished, keeperLeft }

enum SessionCommunicationTopics {
  emoji('lk-emoji-topic'),
  chat('lk-chat-topic');

  const SessionCommunicationTopics(this.topic);
  final String topic;
}

typedef OnEmojiReceived = void Function(String userIdentity, String emoji);
typedef OnMessageReceived = void Function(String userIdentity, String message);
typedef OnLivekitError = void Function(LiveKitException error);
typedef OnKeeperLeaveRoom = VoidCallback Function(Session room);

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
    required this.onKeeperLeaveRoom,
    required this.onConnected,
    required this.cameraOptions,
    required this.audioOptions,
    required this.audioOutputOptions,
  });

  final String eventSlug;
  final String token;
  final bool cameraEnabled;
  final bool microphoneEnabled;

  final OnEmojiReceived onEmojiReceived;
  final OnMessageReceived onMessageReceived;
  final OnLivekitError onLivekitError;
  final OnKeeperLeaveRoom onKeeperLeaveRoom;
  final VoidCallback onConnected;

  final CameraCaptureOptions cameraOptions;
  final AudioCaptureOptions audioOptions;
  final AudioOutputOptions audioOutputOptions;

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
class SessionRoomState {
  const SessionRoomState({
    this.connectionState = RoomConnectionState.connecting,
    this.sessionState = const SessionState(keeperSlug: '', speakingOrder: []),
    this.hasKeeperDisconnected = false,
  });

  final RoomConnectionState connectionState;
  final SessionState sessionState;
  final bool hasKeeperDisconnected;

  bool isMyTurn(RoomContext room) {
    return sessionState.speakingNow != null &&
        sessionState.speakingNow == room.localParticipant?.identity;
  }

  bool amNext(RoomContext room) {
    return sessionState.nextSpeaker != null &&
        sessionState.nextSpeaker == room.localParticipant?.identity;
  }

  SessionRoomState copyWith({
    RoomConnectionState? connectionState,
    SessionState? sessionState,
    bool? hasKeeperDisconnected,
  }) {
    return SessionRoomState(
      connectionState: connectionState ?? this.connectionState,
      sessionState: sessionState ?? this.sessionState,
      hasKeeperDisconnected:
          hasKeeperDisconnected ?? this.hasKeeperDisconnected,
    );
  }

  @override
  String toString() {
    return 'SessionRoomState('
        'connectionState: $connectionState, '
        'sessionState: $sessionState'
        ')';
  }
}

@riverpod
class Session extends _$Session {
  late final RoomContext room;
  late final EventsListener<RoomEvent> _listener;
  late final MobileTotemApi _apiService;
  late SessionOptions _options;
  String? _lastMetadata;
  EventDetailSchema? event;

  Timer? _notificationTimer;
  VoidCallback? closeKeeperLeftNotification;
  SessionEndedReason reason = SessionEndedReason.finished;

  static const defaultCameraOptions = CameraCaptureOptions(
    params: VideoParametersPresets.h540_169,
  );

  @override
  SessionRoomState build(SessionOptions options) {
    _options = options;
    _apiService = ref.read(mobileApiServiceProvider);

    ref.watch(eventProvider(_options.eventSlug)).whenData((event) {
      this.event = event;
    });

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
        defaultVideoPublishOptions: const VideoPublishOptions(
          simulcast: false,
          videoSimulcastLayers: [
            VideoParametersPresets.h360_169,
            VideoParametersPresets.h540_169,
            VideoParametersPresets.h720_169,
          ],
        ),
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

    WakelockPlus.enable();
    setupBackgroundMode();

    ref.onDispose(() {
      logger.d('Disposing LiveKitService and closing connections.');
      endBackgroundMode();
      WakelockPlus.disable();
      _keeperDisconnectedTimer?.cancel();
      _keeperDisconnectedTimer = null;
      closeKeeperLeftNotification?.call();
      closeKeeperLeftNotification = null;
      _notificationTimer?.cancel();
      _notificationTimer = null;
      _listener
        ..cancelAll()
        ..dispose();
      room
        ..removeListener(_onRoomChanges)
        ..dispose();
    });

    return const SessionRoomState();
  }

  void _onConnected() {
    if (room.localParticipant == null) {
      logger.i('Local participant is null on connected.');
      return;
    }

    logger.i(
      'Connected to LiveKit room as '
      '"${room.localParticipant!.identity}".',
    );

    room.localParticipant!.setCameraEnabled(_options.cameraEnabled);

    // TODO(bdlukaa): This doesn't seem to work. Use room.connect to provide custom FastConnectOptions and disable microphone on start there.
    // The current behavior is to enable microphone only for keepers at the
    // beginning of the session.
    // room.localParticipant!.setMicrophoneEnabled(_options.microphoneEnabled)
    room.localParticipant!.setMicrophoneEnabled(isKeeper());
    state = state.copyWith(connectionState: RoomConnectionState.connected);

    options.onConnected();
  }

  void _onDisconnected() {
    state = state.copyWith(connectionState: RoomConnectionState.disconnected);
  }

  void _onError(LiveKitException? error) {
    if (error == null) return;
    ErrorHandler.handleLivekitError(error);
    state = state.copyWith(connectionState: RoomConnectionState.error);
    _options.onLivekitError(error);
  }

  void _onRoomChanges() {
    final metadata = room.room.metadata;
    if (metadata == null || metadata.isEmpty) return;

    try {
      if (_lastMetadata == null) {
        _lastMetadata = metadata;
        state = state.copyWith(
          sessionState: SessionState.fromJson(
            jsonDecode(metadata) as Map<String, dynamic>,
          ),
        );
      } else if (metadata != _lastMetadata) {
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
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error decoding session metadata',
      );
    }

    if (state.sessionState.status == SessionStatus.ended) {
      reason = SessionEndedReason.finished;
      room.disconnect();
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
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Error decoding chat message',
        );
      }
    }
  }

  static const keeperDisconnectionTimeout = Duration(minutes: 3);
  Timer? _keeperDisconnectedTimer;

  Future<void> _onParticipantDisconnected(
    ParticipantDisconnectedEvent event,
  ) async {
    if (isKeeper(event.participant.identity)) {
      await _onKeeperDisconnected();
    }
  }

  void _onParticipantConnected(ParticipantConnectedEvent event) {
    if (isKeeper(event.participant.identity)) {
      _onKeeperConnected();
    }
  }

  bool isKeeper([String? userSlug]) {
    if (userSlug == null) {
      final currentUserSlug = ref.read(
        authControllerProvider.select((auth) => auth.user?.slug),
      );
      userSlug = currentUserSlug;
    }

    return state.sessionState.keeperSlug == userSlug;
  }
}

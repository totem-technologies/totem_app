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
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
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

enum SessionEndedReason { finished, keeperLeft, keeperNotJoined }

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
    this.participants = const [],
  });

  final RoomConnectionState connectionState;
  final SessionState sessionState;
  final bool hasKeeperDisconnected;
  final List<Participant> participants;

  bool isMyTurn(RoomContext room) {
    return sessionState.speakingNow != null &&
        sessionState.speakingNow == room.localParticipant?.identity;
  }

  bool amNext(RoomContext room) {
    return sessionState.nextSpeaker != null &&
        sessionState.nextSpeaker == room.localParticipant?.identity;
  }

  String get speakingNow {
    return sessionState.speakingNow ?? sessionState.keeperSlug;
  }

  SessionRoomState copyWith({
    RoomConnectionState? connectionState,
    SessionState? sessionState,
    bool? hasKeeperDisconnected,
    List<Participant>? participants,
  }) {
    return SessionRoomState(
      connectionState: connectionState ?? this.connectionState,
      sessionState: sessionState ?? this.sessionState,
      hasKeeperDisconnected:
          hasKeeperDisconnected ?? this.hasKeeperDisconnected,
      participants: participants ?? this.participants,
    );
  }

  @override
  String toString() {
    return 'SessionRoomState('
        'connectionState: $connectionState, '
        'sessionState: $sessionState, '
        'hasKeeperDisconnected: $hasKeeperDisconnected, '
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionRoomState &&
        other.connectionState == connectionState &&
        other.sessionState == sessionState &&
        other.hasKeeperDisconnected == hasKeeperDisconnected &&
        const DeepCollectionEquality().equals(
          other.participants.map((p) => p.identity),
          participants.map((p) => p.identity),
        );
  }

  @override
  int get hashCode =>
      connectionState.hashCode ^
      sessionState.hashCode ^
      hasKeeperDisconnected.hashCode ^
      const DeepCollectionEquality().hash(participants.map((p) => p.identity));
}

@riverpod
class Session extends _$Session {
  late final RoomContext context;
  late final EventsListener<RoomEvent> _listener;
  Timer? _timer;
  static const syncTimerDuration = Duration(seconds: 20);

  late SessionOptions _options;
  String? _lastMetadata;
  SessionDetailSchema? event;

  bool _hasKeeperEverJoined = false;
  Timer? _notificationTimer;
  VoidCallback? closeKeeperLeftNotification;
  SessionEndedReason reason = SessionEndedReason.finished;

  static const defaultCameraOptions = CameraCaptureOptions(
    params: VideoParametersPresets.h540_169,
  );

  @override
  SessionRoomState build(SessionOptions options) {
    _options = options;
    ref
        .watch(eventProvider(_options.eventSlug))
        .whenData((event) => this.event = event);

    _timer?.cancel();
    _timer = Timer.periodic(Session.syncTimerDuration, (_) => _checkUp());

    context = RoomContext(
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

    _listener = context.room.createListener();
    _listener
      ..on((_) => _onRoomChanges())
      ..on<DataReceivedEvent>(_onDataReceived)
      ..on<ParticipantDisconnectedEvent>(_onParticipantDisconnected)
      ..on<ParticipantConnectedEvent>(_onParticipantConnected)
      ..on<ParticipantEvent>(_updateParticipantsList);

    WakelockPlus.enable();
    setupBackgroundMode();

    ref.onDispose(_cleanUp);

    return SessionRoomState(
      sessionState: SessionState(
        keeperSlug: event?.space.author.slug ?? '',
        speakingOrder: [],
      ),
    );
  }

  static const keeperNotJoinedTimeout = Duration(minutes: 5);
  bool get hasKeeperEverJoined => _hasKeeperEverJoined;

  void _checkUp() {
    _updateParticipantsList();

    // TODO(bdlukaa): This is very error prone.
    // If the following flow happens, the user will be disconnected even if the keeper joins later:
    //    1. Keeper joins the session.
    //    2. User joins the session late, after the keeper.
    //    3. User leaves the room.
    //    4. Keeper leaves the room.
    //    5. User joins the room again, but the keeper is not there.
    //    6. After 10 seconds, the user is disconnected because the keeper "never joined".
    //
    // This should be controlled by the backend instead.
    // final startedAt = event?.start;
    // if (startedAt != null &&
    //     !_hasKeeperEverJoined &&
    //     DateTime.now().isAfter(
    //       startedAt.add(Session.keeperNotJoinedTimeout),
    //     )) {
    //   reason = SessionEndedReason.keeperNotJoined;
    //   context.disconnect();
    //   return;
    // }

    ref
        .read(mobileApiServiceProvider)
        .meetings
        .totemMeetingsMobileApiGetRoomStateEndpoint(
          eventSlug: _options.eventSlug,
        )
        .timeout(const Duration(seconds: 5))
        .then(_onRoomChanges)
        .catchError((dynamic error, StackTrace stackTrace) {
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: 'Error checking room state',
          );
        });
  }

  void _updateParticipantsList([ParticipantEvent? event]) {
    try {
      final participants = <Participant>[
        ...context.room.remoteParticipants.values,
        if (context.room.localParticipant != null)
          context.room.localParticipant!,
      ];

      if (state.sessionState.speakingOrder.isNotEmpty) {
        participants.sort((a, b) {
          final aIndex = state.sessionState.speakingOrder.indexOf(a.identity);
          final bIndex = state.sessionState.speakingOrder.indexOf(b.identity);
          return aIndex.compareTo(bIndex);
        });
      }

      final hasKeeper = participants.any((p) => isKeeper(p.identity));
      if (!_hasKeeperEverJoined && hasKeeper) _hasKeeperEverJoined = true;
      if (state.hasKeeperDisconnected && hasKeeper) {
        _onKeeperConnected();
      } else if (!state.hasKeeperDisconnected && !hasKeeper) {
        _onKeeperDisconnected();
      }

      state = state.copyWith(participants: participants);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error updating participants list',
      );
    }
  }

  void _onConnected() {
    if (context.room.localParticipant == null) {
      logger.i('Local participant is null on connected.');
      return;
    }

    logger.i(
      'Connected to LiveKit room as '
      '"${context.room.localParticipant!.identity}".',
    );

    _onRoomChanges();

    context.room.localParticipant?.setCameraEnabled(_options.cameraEnabled);

    // If the user joined in the waiting
    // If the keeper is not in the room, the participants will start unmuted.
    final isKeeperInRoom = state.participants.any((p) => isKeeper(p.identity));
    context.room.localParticipant!.setMicrophoneEnabled(() {
      if (state.sessionState.status == SessionStatus.waiting &&
          !isKeeperInRoom) {
        // If joined in the waiting room, everyone can join unmuted.
        return _options.microphoneEnabled;
      }
      // In other status, only the keeper can join unmuted.
      return isKeeper() && _options.microphoneEnabled;
    }());
    // context.room.localParticipant!.setMicrophoneEnabled(_options.microphoneEnabled)
    state = state.copyWith(connectionState: RoomConnectionState.connected);

    options.onConnected();
    _updateParticipantsList();
  }

  void _onDisconnected() {
    state = state.copyWith(connectionState: RoomConnectionState.disconnected);
    _cleanUp();
  }

  void _onError(LiveKitException? error) {
    if (error == null) return;
    ErrorHandler.handleLivekitError(error);
    state = state.copyWith(connectionState: RoomConnectionState.error);
    _options.onLivekitError(error);
  }

  void _onRoomChanges([SessionState? newSessionState]) {
    if (newSessionState != null) {
      state = state.copyWith(sessionState: newSessionState);
    } else {
      final metadata = context.room.metadata;
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
    }

    if (state.sessionState.status == SessionStatus.ended) {
      _onSessionEnd();
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

  void _onParticipantDisconnected(ParticipantDisconnectedEvent event) {
    if (isKeeper(event.participant.identity)) {
      _onKeeperDisconnected();
    }
  }

  void _onParticipantConnected(ParticipantConnectedEvent event) {
    if (isKeeper(event.participant.identity)) {
      _onKeeperConnected();
    }
  }

  Future<void> _onSessionEnd() async {
    reason = SessionEndedReason.finished;
    context.disconnect();
  }

  void _cleanUp() {
    logger.d('Disposing SessionService and closing connections.');

    if (ref.mounted) {
      try {
        if (event != null) {
          ref.invalidate(spaceProvider(event!.space.slug));
        }
        ref.invalidate(spacesSummaryProvider);
      } catch (_) {}
    }

    endBackgroundMode(); // This closes _notificationTimer
    try {
      WakelockPlus.disable();
    } catch (_) {}

    _timer?.cancel();
    _timer = null;

    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    closeKeeperLeftNotification?.call();
    closeKeeperLeftNotification = null;

    try {
      _listener
        ..cancelAll()
        ..dispose();
    } catch (_) {}
    try {
      context
        ..removeListener(_onRoomChanges)
        ..dispose();
    } catch (_) {}
  }
}

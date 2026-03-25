import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide ChatMessage, logger;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/sessions/controllers/session_connection_controller.dart';
import 'package:totem_app/features/sessions/controllers/session_device_controller.dart';
import 'package:totem_app/features/sessions/controllers/session_infra_controller.dart';
import 'package:totem_app/features/sessions/controllers/utils.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart'
    show sessionScopeProvider;
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/shared/logger.dart';

export 'package:totem_app/features/sessions/controllers/utils.dart';

part 'devices_control.dart';
part 'keeper_control.dart';
part 'participant_control.dart';
part 'session_controller.g.dart';

enum SessionCommunicationTopics {
  emoji('lk-emoji-topic'),
  chat('lk-chat-topic'),
  participantRemoved('lk-participant-removed-topic');

  const SessionCommunicationTopics(this.topic);
  final String topic;
}

// ============= Domain Errors =============

sealed class RoomError {
  const RoomError();
}

class RoomLiveKitError extends RoomError {
  const RoomLiveKitError(this.exception);
  final LiveKitException exception;

  @override
  String toString() => 'RoomLiveKitError: ${exception.message}';
}

class RoomDisconnectionError extends RoomError {
  const RoomDisconnectionError(this.reason);
  final DisconnectReason reason;

  @override
  String toString() => 'RoomDisconnectionError: ${reason.name}';
}

class RoomTimeoutError extends RoomError {
  const RoomTimeoutError(this.phase);
  final SessionPhase phase;

  @override
  String toString() => 'RoomTimeoutError in phase: ${phase.name}';
}

// ============= Nested Domain State =============

@immutable
class ConnectionState {
  const ConnectionState({
    required this.phase,
    required this.state,
    this.error,
  });

  final SessionPhase phase;
  final RoomConnectionState state;
  final RoomError? error;

  ConnectionState copyWith({
    SessionPhase? phase,
    RoomConnectionState? state,
    RoomError? error,
    bool clearError = false,
  }) {
    return ConnectionState(
      phase: phase ?? this.phase,
      state: state ?? this.state,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionState &&
        other.phase == phase &&
        other.state == state &&
        other.error?.toString() == error?.toString();
  }

  @override
  int get hashCode =>
      phase.hashCode ^ state.hashCode ^ error.toString().hashCode;
}

@immutable
class ParticipantsState {
  const ParticipantsState({
    this.participants = const [],
    this.hasKeeperDisconnected = false,
    this.removed = false,
  });

  final List<Participant> participants;
  final bool hasKeeperDisconnected;
  final bool removed;

  ParticipantsState copyWith({
    List<Participant>? participants,
    bool? hasKeeperDisconnected,
    bool? removed,
  }) {
    return ParticipantsState(
      participants: participants ?? this.participants,
      hasKeeperDisconnected:
          hasKeeperDisconnected ?? this.hasKeeperDisconnected,
      removed: removed ?? this.removed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantsState &&
        const DeepCollectionEquality().equals(
          other.participants.map((p) => p.identity),
          participants.map((p) => p.identity),
        ) &&
        other.hasKeeperDisconnected == hasKeeperDisconnected &&
        other.removed == removed;
  }

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(participants.map((p) => p.identity)) ^
      hasKeeperDisconnected.hashCode ^
      removed.hashCode;
}

@immutable
class ChatState {
  const ChatState({
    this.messages = const [],
  });

  final List<ChatMessage> messages;

  ChatState copyWith({
    List<ChatMessage>? messages,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatState &&
        const DeepCollectionEquality().equals(
          other.messages.map((m) => m.id),
          messages.map((m) => m.id),
        );
  }

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(messages.map((m) => m.id));
}

@immutable
class SessionTurnState {
  const SessionTurnState({
    required this.roomState,
    this.isSpeakerphoneEnabled = false,
  });

  final RoomState roomState;
  final bool isSpeakerphoneEnabled;

  SessionTurnState copyWith({
    RoomState? roomState,
    bool? isSpeakerphoneEnabled,
  }) {
    return SessionTurnState(
      roomState: roomState ?? this.roomState,
      isSpeakerphoneEnabled:
          isSpeakerphoneEnabled ?? this.isSpeakerphoneEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionTurnState &&
        other.roomState == roomState &&
        other.isSpeakerphoneEnabled == isSpeakerphoneEnabled;
  }

  @override
  int get hashCode => roomState.hashCode ^ isSpeakerphoneEnabled.hashCode;
}

@immutable
class SessionOptions {
  const SessionOptions({
    required this.eventSlug,
    required this.token,
    required this.cameraEnabled,
    required this.microphoneEnabled,
    required this.cameraOptions,
    required this.audioOutputOptions,
  });

  final String eventSlug;
  final String token;
  final bool cameraEnabled;
  final bool microphoneEnabled;

  final CameraCaptureOptions cameraOptions;
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

enum SessionPhase {
  idle,
  connecting,
  connected,
  disconnected,
  error,
  ended,
}

sealed class _SessionEvent {
  const _SessionEvent();
}

class _ConnectionChanged extends _SessionEvent {
  const _ConnectionChanged(this.connectionState, this.phase);

  final RoomConnectionState connectionState;
  final SessionPhase phase;
}

class _RoomStateChanged extends _SessionEvent {
  const _RoomStateChanged(this.roomState);

  final RoomState roomState;
}

class _ParticipantsChanged extends _SessionEvent {
  const _ParticipantsChanged(this.participants);

  final List<Participant> participants;
}

class _KeeperDisconnectedChanged extends _SessionEvent {
  const _KeeperDisconnectedChanged(this.hasKeeperDisconnected);

  final bool hasKeeperDisconnected;
}

class _ParticipantRemoved extends _SessionEvent {
  const _ParticipantRemoved();
}

class _SpeakerphoneChanged extends _SessionEvent {
  const _SpeakerphoneChanged(this.isSpeakerphoneEnabled);

  final bool isSpeakerphoneEnabled;
}

class _DisconnectReasonChanged extends _SessionEvent {
  const _DisconnectReasonChanged(this.disconnectReason);

  final DisconnectReason? disconnectReason;
}

class _SessionErrorChanged extends _SessionEvent {
  const _SessionErrorChanged(this.error);

  final RoomError? error;
}

class _LiveKitErrorChanged extends _SessionEvent {
  const _LiveKitErrorChanged(this.livekitError);

  final LiveKitException? livekitError;
}

class _ChatMessageAdded extends _SessionEvent {
  const _ChatMessageAdded(this.message);

  final ChatMessage message;
}

@immutable
class SessionRoomState {
  const SessionRoomState({
    required this.connection,
    required this.participants,
    required this.chat,
    required this.turn,
  });

  /// Connection state including phase and any errors.
  final ConnectionState connection;

  /// Participants in the session with keeper status.
  final ParticipantsState participants;

  /// Chat messages and related state.
  final ChatState chat;

  /// Turn order state and audio output settings.
  final SessionTurnState turn;

  // ===== Compatibility getters =====
  // Keep previous public API surface while migrating callers incrementally.
  SessionPhase get phase => connection.phase;
  RoomConnectionState get connectionState => connection.state;
  RoomState get roomState => turn.roomState;
  bool get hasKeeperDisconnected => participants.hasKeeperDisconnected;
  List<Participant> get participantsList => participants.participants;
  bool get removed => participants.removed;
  bool get isSpeakerphoneEnabled => turn.isSpeakerphoneEnabled;
  List<ChatMessage> get messages => chat.messages;
  DisconnectReason? get disconnectReason {
    final error = connection.error;
    if (error is RoomDisconnectionError) return error.reason;
    return null;
  }

  LiveKitException? get livekitError {
    final error = connection.error;
    if (error is RoomLiveKitError) return error.exception;
    return null;
  }

  // ===== Domain methods =====

  bool isMyTurn(Room room) {
    return turn.roomState.currentSpeaker != null &&
        turn.roomState.currentSpeaker == room.localParticipant?.identity;
  }

  bool amNext(Room room) {
    return turn.roomState.nextSpeaker != null &&
        turn.roomState.nextSpeaker == room.localParticipant?.identity;
  }

  String get speakingNow {
    if (turn.roomState.currentSpeaker == null ||
        turn.roomState.currentSpeaker!.isEmpty) {
      return turn.roomState.keeper;
    }
    return turn.roomState.currentSpeaker ?? turn.roomState.keeper;
  }

  bool get hasKeeper =>
      participants.participants.any((p) => isKeeper(p.identity));

  bool isKeeper(String? userSlug) {
    return turn.roomState.keeper == userSlug;
  }

  Participant? featuredParticipant() {
    if (participants.participants.isEmpty) return null;
    if (turn.roomState.status == RoomStatus.waitingRoom && !hasKeeper) {
      return null;
    }
    return participants.participants.firstWhereOrNull(
          (participant) => participant.identity == speakingNow,
        ) ??
        participants.participants.firstWhereOrNull(
          (participant) => participant.identity == turn.roomState.keeper,
        );
  }

  Participant? speakingNextParticipant() {
    if (turn.roomState.nextSpeaker == null) return null;
    return participants.participants.firstWhereOrNull((participant) {
      return participant.identity == turn.roomState.nextSpeaker;
    });
  }

  @override
  String toString() {
    return 'SessionRoomState('
        'phase: ${connection.phase}, '
        'connectionState: ${connection.state}, '
        'roomState: ${turn.roomState}, '
        'error: ${connection.error}, '
        'participants: ${participants.participants.length}, '
        'removed: ${participants.removed}, '
        'isSpeakerphoneEnabled: ${turn.isSpeakerphoneEnabled}, '
        'messages: ${chat.messages.length}'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionRoomState &&
        other.connection == connection &&
        other.participants == participants &&
        other.chat == chat &&
        other.turn == turn;
  }

  @override
  int get hashCode =>
      connection.hashCode ^
      participants.hashCode ^
      chat.hashCode ^
      turn.hashCode;
}

@riverpod
class SessionController extends _$SessionController {
  /// The [Room] of the current session, which holds the LiveKit room and related information.
  SessionConnectionController? _connectionController;

  Room? get room => _connectionController?.room;

  /// The sync timer periodically checks for changes in the room state
  /// and participants list, to keep the UI up to date.
  Timer? _syncTimer;
  static const syncTimerDuration = Duration(seconds: 20);

  SessionOptions? _options;
  bool? _cameraEnabledOverride;
  bool? _microphoneEnabledOverride;
  String? _lastMetadata;
  SessionDetailSchema? event;
  SessionDeviceController? _deviceController;

  static const defaultCameraCaptureOptions = CameraCaptureOptions(
    params: VideoParameters(
      dimensions: VideoDimensionsPresets.h720_43,
      encoding: VideoEncoding(
        maxBitrate: 1300 * 1000,
        maxFramerate: 20,
      ),
    ),
  );

  SessionDeviceController get _devices {
    return _deviceController ??= SessionDeviceController(
      ref: ref,
      currentRoom: () => room,
      currentRoomState: () => state.roomState,
      hasKeeper: () => state.hasKeeper,
      onSpeakerphoneChanged: (enabled) {
        _dispatch(_SpeakerphoneChanged(enabled));
      },
      defaultCameraCaptureOptions:
          SessionController.defaultCameraCaptureOptions,
    );
  }

  SessionConnectionController get _connection {
    return _connectionController ??= SessionConnectionController(
      onRoomEvent: () {
        if (ref.mounted) {
          _onRoomChanges();
        }
      },
      onConnected: _onConnected,
      onDisconnected: (reason) {
        logger.d('Disconnected from session. Reason: $reason');
        if (reason != null) {
          _dispatch(_SessionErrorChanged(RoomDisconnectionError(reason)));
        }
        _onDisconnected();
      },
      onDataReceived: _onDataReceived,
      onParticipantDisconnected: _onParticipantDisconnected,
      onParticipantConnected: _onParticipantConnected,
    );
  }

  void _dispatch(_SessionEvent event) {
    switch (event) {
      case _ConnectionChanged():
        state = SessionRoomState(
          connection: state.connection.copyWith(
            state: event.connectionState,
            phase: event.phase,
            clearError: event.connectionState == RoomConnectionState.connected,
          ),
          participants: event.connectionState == RoomConnectionState.connected
              ? state.participants.copyWith(removed: false)
              : state.participants,
          chat: state.chat,
          turn: state.turn,
        );
      case _RoomStateChanged():
        final isEnded = event.roomState.status == RoomStatus.ended;
        state = SessionRoomState(
          connection: state.connection.copyWith(
            phase: isEnded ? SessionPhase.ended : null,
          ),
          participants: state.participants,
          chat: state.chat,
          turn: state.turn.copyWith(roomState: event.roomState),
        );
      case _ParticipantsChanged():
        state = SessionRoomState(
          connection: state.connection,
          participants: state.participants.copyWith(
            participants: event.participants,
          ),
          chat: state.chat,
          turn: state.turn,
        );
      case _KeeperDisconnectedChanged():
        state = SessionRoomState(
          connection: state.connection,
          participants: state.participants.copyWith(
            hasKeeperDisconnected: event.hasKeeperDisconnected,
          ),
          chat: state.chat,
          turn: state.turn,
        );
      case _ParticipantRemoved():
        state = SessionRoomState(
          connection: state.connection,
          participants: state.participants.copyWith(removed: true),
          chat: state.chat,
          turn: state.turn,
        );
      case _SpeakerphoneChanged():
        state = SessionRoomState(
          connection: state.connection,
          participants: state.participants,
          chat: state.chat,
          turn: state.turn.copyWith(
            isSpeakerphoneEnabled: event.isSpeakerphoneEnabled,
          ),
        );
      case _DisconnectReasonChanged():
        // Handled through _SessionErrorChanged now, but kept for future use
        break;
      case _SessionErrorChanged():
        state = SessionRoomState(
          connection: state.connection.copyWith(
            error: event.error,
            state: event.error is RoomLiveKitError
                ? RoomConnectionState.error
                : state.connection.state,
            phase: event.error is RoomLiveKitError ? SessionPhase.error : null,
          ),
          participants: state.participants,
          chat: state.chat,
          turn: state.turn,
        );
      case _LiveKitErrorChanged():
        // This event type is no longer used; maintained for backward compat
        break;
      case _ChatMessageAdded():
        state = SessionRoomState(
          connection: state.connection,
          participants: state.participants,
          chat: state.chat.copyWith(
            messages: [...state.chat.messages, event.message],
          ),
          turn: state.turn,
        );
    }
  }

  @override
  SessionRoomState build(SessionOptions options) {
    _options = options;
    ref
        .watch(eventProvider(options.eventSlug))
        .whenData((event) => this.event = event);

    ref.onDispose(_cleanUp);

    final initialRoomState = RoomState(
      keeper: event?.space.author.slug ?? '',
      nextSpeaker: '',
      currentSpeaker: '',
      status: RoomStatus.waitingRoom,
      turnState: TurnState.idle,
      sessionSlug: options.eventSlug,
      statusDetail: const RoomStateStatusDetailWaitingRoom(
        WaitingRoomDetail(),
      ),
      talkingOrder: [],
      version: 0,
      roundNumber: 0,
    );

    return SessionRoomState(
      connection: const ConnectionState(
        phase: SessionPhase.idle,
        state: RoomConnectionState.disconnected,
      ),
      participants: const ParticipantsState(),
      chat: const ChatState(),
      turn: SessionTurnState(
        roomState: initialRoomState,
        isSpeakerphoneEnabled: _devices.userSpeakerPreference,
      ),
    );
  }

  void _updateParticipantsList() {
    try {
      final participants = <Participant>[
        if (room != null) ...[
          ...room!.remoteParticipants.values,
          if (room!.localParticipant != null) room!.localParticipant!,
        ],
      ];

      final sortedParticipants = participantsSorting(
        originalParticipants: participants,
        state: state,
        showSpeakingNow: true,
      );

      final hasKeeper = sortedParticipants.any(
        (p) => state.isKeeper(p.identity),
      );
      if (state.hasKeeperDisconnected && hasKeeper) {
        _onKeeperConnected();
      }

      _dispatch(_ParticipantsChanged(sortedParticipants));
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error updating participants list',
      );
    }
  }

  void _onConnected() {
    if (room?.localParticipant == null) {
      logger.i('Local participant is null on connected.');
      return;
    }

    logger.i(
      'Connected to LiveKit room as '
      '"${room!.localParticipant!.identity}".',
    );

    _onRoomChanges();

    final cameraEnabled =
        _cameraEnabledOverride ?? (_options?.cameraEnabled ?? false);
    room!.localParticipant?.setCameraEnabled(cameraEnabled);

    // If the user joined in the waiting
    // If the keeper is not in the room, the participants will start unmuted.
    final isMicrophoneEnabled =
        () {
          if (state.roomState.status == RoomStatus.waitingRoom &&
              !state.hasKeeper) {
            // If joined in the waiting room, everyone can join unmuted.
            return _microphoneEnabledOverride ?? _options?.microphoneEnabled;
          }
          if (state.roomState.status == RoomStatus.active) {
            if (state.speakingNow == room!.localParticipant?.identity) {
              // If it's the user's turn to speak, they can join unmuted.
              return _microphoneEnabledOverride ?? _options?.microphoneEnabled;
            }
          }
          // In other states, only the keeper can join unmuted.
          return isCurrentUserKeeper() &&
              (_microphoneEnabledOverride ??
                  _options?.microphoneEnabled ??
                  false);
        }() ??
        false;
    if (isMicrophoneEnabled) {
      enableMicrophone();
    } else {
      disableMicrophone();
    }
    // context.room.localParticipant!.setMicrophoneEnabled(_options.microphoneEnabled)
    _dispatch(
      const _ConnectionChanged(
        RoomConnectionState.connected,
        SessionPhase.connected,
      ),
    );

    // _userSpeakerPreference is always true: when no external audio device
    // is connected, the app should default to speaker (not earpiece).
    _devices.resetSpeakerRoutingDefaults();
    unawaited(_devices.setSpeakerphone(true));

    _updateParticipantsList();
    _devices.setupDeviceChangeListener();
  }

  void _onDisconnected() {
    _dispatch(
      const _ConnectionChanged(
        RoomConnectionState.disconnected,
        SessionPhase.disconnected,
      ),
    );
    _cleanUp();
  }

  void _onError(LiveKitException? error) {
    if (error == null) return;
    ErrorHandler.handleLivekitError(error);
    _dispatch(_SessionErrorChanged(RoomLiveKitError(error)));
  }

  void _onRoomChanges([RoomState? newSessionState]) {
    _updateParticipantsList();
    if (newSessionState != null) {
      _dispatch(_RoomStateChanged(newSessionState));
    } else {
      final metadata = room?.metadata;
      if (metadata == null || metadata.isEmpty) return;

      try {
        if (_lastMetadata == null) {
          _lastMetadata = metadata;
          _dispatch(
            _RoomStateChanged(
              RoomState.fromJson(
                jsonDecode(metadata) as Map<String, dynamic>,
              ),
            ),
          );
        } else if (metadata != _lastMetadata) {
          final newState = RoomState.fromJson(
            jsonDecode(metadata) as Map<String, dynamic>,
          );

          _dispatch(_RoomStateChanged(newState));
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

    if (state.roomState.status == RoomStatus.ended) {
      _onSessionEnd();
    }
  }

  void _onDataReceived(DataReceivedEvent event) {
    if (event.topic == null) return;
    final data = const Utf8Decoder().convert(event.data);
    logger.d(
      '(${room?.localParticipant}) Received data on topic "${event.topic}" from participant "${event.participant?.identity}": $data',
    );

    final topic = SessionCommunicationTopics.values.firstWhereOrNull(
      (t) => t.topic == event.topic,
    );

    if (topic == null) {
      logger.w('Received data on unknown topic "${event.topic}". Ignoring.');
      return;
    }

    switch (topic) {
      case SessionCommunicationTopics.emoji:
        final participant = event.participant;
        if (participant == null) return;
        ref
            .read(emojiReactionsProvider.notifier)
            .emitIncomingReaction(participant.identity, data);
      case SessionCommunicationTopics.chat:
        try {
          final message = ChatMessage.fromMap(
            jsonDecode(data) as Map<String, dynamic>,
            event.participant,
          );
          _dispatch(_ChatMessageAdded(message));
        } catch (error, stackTrace) {
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: 'Error decoding chat message',
          );
        }
      case SessionCommunicationTopics.participantRemoved:
        logger.d(
          'Received participant removed event from ${event.participant?.identity}: $data',
        );
        final json = jsonDecode(data) as Map<String, dynamic>;
        // final action = json['action'] as String?;
        final identity = json['identity'] as String?;
        // final reason = json['reason'] as String?;

        // If participant identity is null, the message comes from the server
        if (event.participant?.identity != null &&
            event.participant!.identity != state.roomState.keeper) {
          logger.d(
            'Participant removed event is not from the keeper, ignoring.',
          );
          return;
        }

        try {
          if (identity == room?.localParticipant?.identity) {
            logger.d(
              'Received participant removed event for local participant.',
            );
            _dispatch(const _ParticipantRemoved());
            unawaited(_connection.disconnect());
          }
        } catch (error, stackTrace) {
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: 'Error decoding participant removed event',
          );
        }
    }
  }

  static const keeperDisconnectionTimeout = Duration(minutes: 3);
  Timer? _keeperDisconnectedTimer;

  void _onParticipantDisconnected(ParticipantDisconnectedEvent event) {
    if (state.isKeeper(event.participant.identity)) {
      _onKeeperDisconnected();
    }
  }

  void _onParticipantConnected(ParticipantConnectedEvent event) {
    if (state.isKeeper(event.participant.identity)) {
      _onKeeperConnected();
    }
  }

  Future<void> _onSessionEnd() async {
    logger.d('Session has ended. Cleaning up and disconnecting.');
    await leave();
  }

  void configureJoinPreferences({
    required bool cameraEnabled,
    required bool microphoneEnabled,
  }) {
    _cameraEnabledOverride = cameraEnabled;
    _microphoneEnabledOverride = microphoneEnabled;
  }

  Future<void> join() async {
    if (room != null) {
      if (state.connectionState == RoomConnectionState.connected) return;
    }

    _dispatch(
      const _ConnectionChanged(
        RoomConnectionState.connecting,
        SessionPhase.connecting,
      ),
    );

    final options = _options;
    if (options == null) return;

    await _connection.initialize(
      roomOptions: RoomOptions(
        defaultCameraCaptureOptions: options.cameraOptions,
        defaultAudioCaptureOptions: const AudioCaptureOptions(),
        defaultAudioOutputOptions: options.audioOutputOptions,
        dynacast: true,
        defaultVideoPublishOptions: VideoPublishOptions(
          videoCodec: 'h265',
          backupVideoCodec: const BackupVideoCodec(
            codec: 'vp8',
            simulcast: true,
          ),
          simulcast: true,
          videoSimulcastLayers: [
            VideoParameters(
              dimensions: VideoParametersPresets.h540_43.dimensions,
              encoding: const VideoEncoding(
                maxBitrate: 400_000,
                maxFramerate: 20,
              ),
            ),
            VideoParameters(
              dimensions: VideoParametersPresets.h720_43.dimensions,
              encoding: const VideoEncoding(
                maxBitrate: 1_500_000,
                maxFramerate: 20,
              ),
            ),
          ],
        ),
        adaptiveStream: true,
      ),
      url: AppConfig.liveKitUrl,
      token: options.token,
    );

    await ref
        .read(sessionInfraControllerProvider(options))
        .activate(event: event);

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      SessionController.syncTimerDuration,
      (_) => _onRoomChanges(),
    );

    try {
      await _connection.connect(
        url: AppConfig.liveKitUrl,
        token: options.token,
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error connecting to LiveKit room',
      );
      _onError(error is LiveKitException ? error : null);
    }
  }

  Future<void> leave() async {
    await _connection.disconnect();
    _cleanUp();
  }

  void _cleanUp() {
    logger.d('Disposing SessionService and closing connections.');

    final options = _options;
    if (options != null && ref.mounted) {
      unawaited(
        ref.read(sessionInfraControllerProvider(options)).deactivate(),
      );
    }

    if (ref.mounted) {
      try {
        ref.read(emojiReactionsProvider.notifier).clear();
      } catch (_) {}
      if (event != null) {
        try {
          ref.invalidate(spaceProvider(event!.space.slug));
        } catch (_) {}
      }
      try {
        ref.invalidate(spacesSummaryProvider);
      } catch (_) {}
      try {
        ref.invalidate(sessionScopeProvider);
      } catch (_) {}
    }

    _syncTimer?.cancel();
    _syncTimer = null;

    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    unawaited(_devices.dispose());
    _deviceController = null;

    unawaited(_connection.dispose());
    _connectionController = null;
  }
}

@Riverpod(keepAlive: true)
SessionRoomState session(Ref ref, SessionOptions options) {
  return ref.watch(sessionControllerProvider(options));
}

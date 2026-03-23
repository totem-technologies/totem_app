import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as audio;
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide ChatMessage, logger;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/core/services/screen_protection_service.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/features/sessions/services/utils.dart';
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/shared/logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

export 'package:totem_app/features/sessions/services/utils.dart';

part 'background_control.dart';
part 'devices_control.dart';
part 'keeper_control.dart';
part 'participant_control.dart';
part 'session_service.g.dart';

enum SessionCommunicationTopics {
  emoji('lk-emoji-topic'),
  chat('lk-chat-topic'),
  participantRemoved('lk-participant-removed-topic');

  const SessionCommunicationTopics(this.topic);
  final String topic;
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

@immutable
class SessionRoomState {
  const SessionRoomState({
    required this.roomState,
    this.connectionState = RoomConnectionState.connecting,
    this.hasKeeperDisconnected = false,
    this.participants = const [],
    this.removed = false,
    this.isSpeakerphoneEnabled = false,
    this.disconnectReason,
    this.messages = const [],
    this.livekitError,
  });

  /// The current connection state of the room.
  final RoomConnectionState connectionState;

  /// The current state of the room, as published by the backend and LiveKit metadata.
  final RoomState roomState;

  /// Whether the keeper has disconnected from the session.
  final bool hasKeeperDisconnected;

  /// The participants in the session.
  final List<Participant> participants;

  /// Whether the local participant was removed from the session.
  final bool removed;

  /// Whether the speaker is on.
  final bool isSpeakerphoneEnabled;

  /// Why LiveKit disconnected this participant, when available.
  final DisconnectReason? disconnectReason;

  /// The chat messages in the session.
  final List<ChatMessage> messages;

  /// The latest LiveKit error that occurred in the session, if any.
  /// This is used to display error messages to the user when LiveKit errors occur.
  final LiveKitException? livekitError;

  bool isMyTurn(Room room) {
    return roomState.currentSpeaker != null &&
        roomState.currentSpeaker == room.localParticipant?.identity;
  }

  bool amNext(Room room) {
    return roomState.nextSpeaker != null &&
        roomState.nextSpeaker == room.localParticipant?.identity;
  }

  String get speakingNow {
    if (roomState.currentSpeaker == null || roomState.currentSpeaker!.isEmpty) {
      return roomState.keeper;
    }
    return roomState.currentSpeaker ?? roomState.keeper;
  }

  bool get hasKeeper => participants.any((p) => isKeeper(p.identity));

  bool isKeeper(String? userSlug) {
    return roomState.keeper == userSlug;
  }

  /// Returns the participant that is featured right now.
  ///
  /// If no participants, return null.
  ///
  /// If in the waiting room and the keeper is not present, return null.
  ///
  /// If [speakingNow] is present, return the corresponding participant.
  ///
  /// Otherwise, return the keeper participant if present, or null if not.
  Participant? featuredParticipant() {
    if (participants.isEmpty) return null;
    if (roomState.status == RoomStatus.waitingRoom && !hasKeeper) {
      return null;
    }
    return participants.firstWhereOrNull(
          (participant) => participant.identity == speakingNow,
        ) ??
        participants.firstWhereOrNull(
          (participant) => participant.identity == roomState.keeper,
        );
  }

  Participant? speakingNextParticipant() {
    if (roomState.nextSpeaker == null) return null;
    return participants.firstWhereOrNull((participant) {
      return participant.identity == roomState.nextSpeaker;
    });
  }

  SessionRoomState copyWith({
    RoomConnectionState? connectionState,
    RoomState? roomState,
    bool? hasKeeperDisconnected,
    List<Participant>? participants,
    bool? removed,
    bool? isSpeakerphoneEnabled,
    DisconnectReason? disconnectReason,
    bool clearDisconnectReason = false,
    List<ChatMessage>? messages,
    LiveKitException? livekitError,
    bool clearLivekitError = false,
  }) {
    return SessionRoomState(
      connectionState: connectionState ?? this.connectionState,
      roomState: roomState ?? this.roomState,
      hasKeeperDisconnected:
          hasKeeperDisconnected ?? this.hasKeeperDisconnected,
      participants: participants ?? this.participants,
      removed: removed ?? this.removed,
      isSpeakerphoneEnabled:
          isSpeakerphoneEnabled ?? this.isSpeakerphoneEnabled,
      disconnectReason: clearDisconnectReason
          ? null
          : disconnectReason ?? this.disconnectReason,
      messages: messages ?? this.messages,
      livekitError: clearLivekitError
          ? null
          : livekitError ?? this.livekitError,
    );
  }

  @override
  String toString() {
    return 'SessionRoomState('
        'connectionState: $connectionState, '
        'sessionState: $roomState, '
        'hasKeeperDisconnected: $hasKeeperDisconnected, '
        'removed: $removed, '
        'disconnectReason: $disconnectReason, '
        'isSpeakerphoneEnabled: $isSpeakerphoneEnabled, '
        'messages: $messages'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionRoomState &&
        other.connectionState == connectionState &&
        other.roomState == roomState &&
        other.hasKeeperDisconnected == hasKeeperDisconnected &&
        const DeepCollectionEquality().equals(
          other.participants.map((p) => p.identity),
          participants.map((p) => p.identity),
        ) &&
        other.removed == removed &&
        other.disconnectReason == disconnectReason &&
        other.isSpeakerphoneEnabled == isSpeakerphoneEnabled &&
        other.livekitError?.message == livekitError?.message &&
        const DeepCollectionEquality().equals(
          other.messages.map((m) => m.id),
          messages.map((m) => m.id),
        );
  }

  @override
  int get hashCode =>
      connectionState.hashCode ^
      roomState.hashCode ^
      hasKeeperDisconnected.hashCode ^
      const DeepCollectionEquality().hash(participants.map((p) => p.identity)) ^
      removed.hashCode ^
      disconnectReason.hashCode ^
      isSpeakerphoneEnabled.hashCode ^
      (livekitError?.message).hashCode ^
      const DeepCollectionEquality().hash(messages.map((m) => m.id));
}

@riverpod
class Session extends _$Session {
  /// The [Room] of the current session, which holds the LiveKit room and related information.
  Room? room;
  EventsListener<RoomEvent>? _listener;

  /// The sync timer periodically checks for changes in the room state
  /// and participants list, to keep the UI up to date.
  Timer? _syncTimer;
  static const syncTimerDuration = Duration(seconds: 20);

  SessionOptions? _options;
  String? _lastMetadata;
  SessionDetailSchema? event;

  Timer? _notificationTimer;

  StreamSubscription<void>? _becomingNoisySubscription;
  StreamSubscription<audio.AudioDevicesChangedEvent>?
  _devicesChangedSubscription;
  bool _userSpeakerPreference = true;
  bool _hasExternalOutput = false;

  static const defaultCameraCaptureOptions = CameraCaptureOptions(
    params: VideoParameters(
      dimensions: VideoDimensionsPresets.h720_43,
      encoding: VideoEncoding(
        maxBitrate: 1300 * 1000,
        maxFramerate: 20,
      ),
    ),
  );

  @override
  SessionRoomState build(SessionOptions options) {
    _options = options;
    ref
        .watch(eventProvider(options.eventSlug))
        .whenData((event) => this.event = event);

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Session.syncTimerDuration,
      (_) => _onRoomChanges(),
    );

    room = Room(
      roomOptions: RoomOptions(
        defaultCameraCaptureOptions: options.cameraOptions,
        defaultAudioCaptureOptions: const AudioCaptureOptions(),
        defaultAudioOutputOptions: options.audioOutputOptions,

        dynacast: true,
        defaultVideoPublishOptions: VideoPublishOptions(
          // https://docs.livekit.io/transport/media/advanced/#video-codec-support
          // https://livekit.io/webrtc/codecs-guide
          // https://github.com/flutter-webrtc/flutter-webrtc/issues/252
          videoCodec: 'h265',
          backupVideoCodec: const BackupVideoCodec(
            codec: 'vp8',
            simulcast: true,
          ),
          simulcast: true,
          videoSimulcastLayers: [
            // Low Layer
            // VideoParameters(
            //   dimensions: VideoParametersPresets.h360_43.dimensions,
            //   encoding: const VideoEncoding(
            //     maxBitrate: 180_000,
            //     maxFramerate: 15,
            //   ),
            // ),
            // Mid Layer
            VideoParameters(
              dimensions: VideoParametersPresets.h540_43.dimensions,
              encoding: const VideoEncoding(
                maxBitrate: 400_000,
                maxFramerate: 20,
              ),
            ),
            // High Layer
            VideoParameters(
              dimensions: VideoParametersPresets.h720_43.dimensions,
              encoding: const VideoEncoding(
                maxBitrate: 1_500_000,
                maxFramerate: 20,
              ),
            ),
          ],
        ),
        // defaultAudioPublishOptions: const AudioPublishOptions(),

        /// https://docs.livekit.io/home/client/tracks/subscribe/#adaptive-stream
        adaptiveStream: true,
      ),
    );

    room!.prepareConnection(AppConfig.liveKitUrl, options.token);

    // TODO(bdlukaa): Connect should only be done after the user explicitly clicks the "Join Session"
    // button on the waiting room screen, to avoid joining the LiveKit room before it's needed. This
    // will require some refactoring of the code, as currently the connection is established in the
    // build method of the Session provider. One possible approach is to move the connection logic
    // to a separate method that is called when the user clicks the "Join Session" button, and keep
    // track of whether the connection has been established in the state.
    connect();

    _listener = room!.createListener();
    _listener
      ?..on((_) {
        if (ref.mounted) {
          _onRoomChanges();
        }
      })
      ..on<RoomConnectedEvent>((_) {
        _onConnected();
      })
      ..on<RoomDisconnectedEvent>((event) {
        logger.d('Disconnected from session. Reason: ${event.reason}');
        if (event.reason != null) {
          state = state.copyWith(disconnectReason: event.reason);
        }
        _onDisconnected();
      })
      ..on<DataReceivedEvent>(_onDataReceived)
      ..on<ParticipantDisconnectedEvent>(_onParticipantDisconnected)
      ..on<ParticipantConnectedEvent>(_onParticipantConnected);

    WakelockPlus.enable();
    setupBackgroundMode();
    _applyScreenCapturePolicy();

    ref.onDispose(_cleanUp);

    return SessionRoomState(
      roomState: RoomState(
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
      ),
      isSpeakerphoneEnabled: _userSpeakerPreference,
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

      state = state.copyWith(participants: sortedParticipants);
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

    room!.localParticipant?.setCameraEnabled(
      _options?.cameraEnabled ?? false,
    );

    // If the user joined in the waiting
    // If the keeper is not in the room, the participants will start unmuted.
    final isMicrophoneEnabled =
        () {
          if (state.roomState.status == RoomStatus.waitingRoom &&
              !state.hasKeeper) {
            // If joined in the waiting room, everyone can join unmuted.
            return _options?.microphoneEnabled;
          }
          if (state.roomState.status == RoomStatus.active) {
            if (state.speakingNow == room!.localParticipant?.identity) {
              // If it's the user's turn to speak, they can join unmuted.
              return _options?.microphoneEnabled;
            }
          }
          // In other states, only the keeper can join unmuted.
          return isCurrentUserKeeper() &&
              (_options?.microphoneEnabled ?? false);
        }() ??
        false;
    if (isMicrophoneEnabled) {
      enableMicrophone();
    } else {
      disableMicrophone();
    }
    // context.room.localParticipant!.setMicrophoneEnabled(_options.microphoneEnabled)
    state = state.copyWith(
      connectionState: RoomConnectionState.connected,
      removed: false,
      clearDisconnectReason: true,
      clearLivekitError: true,
    );

    // _userSpeakerPreference is always true: when no external audio device
    // is connected, the app should default to speaker (not earpiece).
    _userSpeakerPreference = true;
    _hasExternalOutput = false;

    _autoSetSpeakerphone(true);
    _applyScreenCapturePolicy();

    _updateParticipantsList();
    setupDeviceChangeListener();
  }

  void _onDisconnected() {
    state = state.copyWith(connectionState: RoomConnectionState.disconnected);
    _cleanUp();
  }

  void _onError(LiveKitException? error) {
    if (error == null) return;
    ErrorHandler.handleLivekitError(error);
    state = state.copyWith(
      connectionState: RoomConnectionState.error,
      livekitError: error,
    );
  }

  void _onRoomChanges([RoomState? newSessionState]) {
    _updateParticipantsList();
    if (newSessionState != null) {
      state = state.copyWith(roomState: newSessionState);
    } else {
      final metadata = room?.metadata;
      if (metadata == null || metadata.isEmpty) return;

      try {
        if (_lastMetadata == null) {
          _lastMetadata = metadata;
          state = state.copyWith(
            roomState: RoomState.fromJson(
              jsonDecode(metadata) as Map<String, dynamic>,
            ),
          );
        } else if (metadata != _lastMetadata) {
          final newState = RoomState.fromJson(
            jsonDecode(metadata) as Map<String, dynamic>,
          );

          state = state.copyWith(roomState: newState);
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
          state = state.copyWith(messages: [...state.messages, message]);
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
            state = state.copyWith(removed: true);
            room?.disconnect();
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
    endBackgroundMode();
    await leave();
  }

  Future<void> connect() async {
    try {
      await room!.connect(AppConfig.liveKitUrl, options.token);
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
    await room?.disconnect();
    _cleanUp();
  }

  void _cleanUp() {
    logger.d('Disposing SessionService and closing connections.');

    if (ref.mounted) {
      try {
        ref.read(screenProtectionProvider).setCaptureProtectionEnabled(false);
      } catch (_) {}
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

    endBackgroundMode(); // This closes _notificationTimer

    try {
      WakelockPlus.disable();
    } catch (_) {}

    _syncTimer?.cancel();
    _syncTimer = null;

    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    _becomingNoisySubscription?.cancel();
    _becomingNoisySubscription = null;

    _devicesChangedSubscription?.cancel();
    _devicesChangedSubscription = null;

    try {
      _listener
        ?..cancelAll()
        ..dispose();
    } catch (error) {
      ErrorHandler.logError(
        error,
        message: 'Error disposing LiveKit event listener',
      );
    }
    try {
      room
        ?..removeListener(_onRoomChanges)
        ..dispose();
    } catch (_) {}
  }

  void _applyScreenCapturePolicy() {
    final email = ref.read(authControllerProvider).user?.email;
    final shouldProtect =
        !ScreenProtectionService.shouldAllowScreenCaptureForEmail(email);
    ref
        .read(screenProtectionProvider)
        .setCaptureProtectionEnabled(shouldProtect);
  }
}

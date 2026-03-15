import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as audio;
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide ChatMessage, logger;
import 'package:livekit_components/livekit_components.dart';
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
    required this.roomState,
    this.connectionState = RoomConnectionState.connecting,
    this.hasKeeperDisconnected = false,
    this.participants = const [],
    this.removed = false,
    this.isSpeakerphoneEnabled = false,
    this.disconnectReason,
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

  bool isMyTurn(RoomContext room) {
    return roomState.currentSpeaker != null &&
        roomState.currentSpeaker == room.localParticipant?.identity;
  }

  bool amNext(RoomContext room) {
    return roomState.nextSpeaker != null &&
        roomState.nextSpeaker == room.localParticipant?.identity;
  }

  String get speakingNow {
    if (roomState.currentSpeaker == null || roomState.currentSpeaker!.isEmpty) {
      return roomState.keeper;
    }
    return roomState.currentSpeaker ?? roomState.keeper;
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
        'isSpeakerphoneEnabled: $isSpeakerphoneEnabled'
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
        other.isSpeakerphoneEnabled == isSpeakerphoneEnabled;
  }

  @override
  int get hashCode =>
      connectionState.hashCode ^
      roomState.hashCode ^
      hasKeeperDisconnected.hashCode ^
      const DeepCollectionEquality().hash(participants.map((p) => p.identity)) ^
      removed.hashCode ^
      disconnectReason.hashCode ^
      isSpeakerphoneEnabled.hashCode;
}

@riverpod
class Session extends _$Session {
  /// The [RoomContext] of the current session, which holds the LiveKit room and related information.
  RoomContext? context;
  EventsListener<RoomEvent>? _listener;

  /// The sync timer periodically checks for changes in the room state
  /// and participants list, to keep the UI up to date.
  Timer? _syncTimer;
  static const syncTimerDuration = Duration(seconds: 20);

  SessionOptions? _options;
  String? _lastMetadata;
  SessionDetailSchema? event;

  Timer? _notificationTimer;

  /// A list of callbacks that close the "keeper left" notification,
  /// so that they can be called when the keeper comes back or the
  /// user leaves the session.
  List<VoidCallback> closeKeeperLeftNotificationCallbacks = [];

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
        maxFramerate: 22,
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

    context = RoomContext(
      url: AppConfig.liveKitUrl,
      token: options.token,
      connect: true,
      onConnected: _onConnected,
      onDisconnected: _onDisconnected,
      onError: _onError,
      roomOptions: RoomOptions(
        defaultCameraCaptureOptions: options.cameraOptions,
        defaultAudioCaptureOptions: options.audioOptions,
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
            // Layer 1: "Tunnel Mode"
            // Meet will drop the framerate to 15fps before letting the video freeze
            // VideoParameters(
            //   dimensions: VideoParametersPresets.h360_43.dimensions,
            //   encoding: const VideoEncoding(
            //     maxBitrate: 80000,
            //     maxFramerate: 15,
            //   ),
            // ),

            // Layer 2: "Standard Grid"
            VideoParameters(
              dimensions: VideoParametersPresets.h540_43.dimensions,
              encoding: const VideoEncoding(
                maxBitrate: 400_000,
                maxFramerate: 18,
              ),
            ),

            // Layer 3: "Active Speaker"
            VideoParameters(
              dimensions: VideoParametersPresets.h720_43.dimensions,
              encoding: const VideoEncoding(
                maxBitrate: 900_000,
                maxFramerate: 20,
              ),
            ),
          ],
        ),
        // defaultAudioPublishOptions: const AudioPublishOptions(),

        /// https://docs.livekit.io/home/client/tracks/subscribe/#adaptive-stream
        adaptiveStream: false,
      ),
    );

    _listener = context?.room.createListener();
    _listener
      ?..on((_) {
        if (ref.mounted) {
          _onRoomChanges();
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        logger.d('Disconnected from session. Reason: ${event.reason}');
        if (event.reason != null) {
          state = state.copyWith(disconnectReason: event.reason);
        }
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

  /// Whether the keeper is currently in the session.
  bool get hasKeeper => state.participants.any((p) => isKeeper(p.identity));

  void _updateParticipantsList() {
    try {
      final participants = <Participant>[
        if (context?.room != null) ...context!.room.remoteParticipants.values,
        if (context?.room.localParticipant != null)
          context!.room.localParticipant!,
      ];

      final sortedParticipants = participantsSorting(
        originalParticipants: participants,
        state: state,
        showSpeakingNow: true,
      );

      final hasKeeper = sortedParticipants.any((p) => isKeeper(p.identity));
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
    if (context?.room.localParticipant == null) {
      logger.i('Local participant is null on connected.');
      return;
    }

    logger.i(
      'Connected to LiveKit room as '
      '"${context!.room.localParticipant!.identity}".',
    );

    _onRoomChanges();

    context!.room.localParticipant?.setCameraEnabled(
      _options?.cameraEnabled ?? false,
    );

    // If the user joined in the waiting
    // If the keeper is not in the room, the participants will start unmuted.
    final isMicrophoneEnabled =
        () {
          if (state.roomState.status == RoomStatus.waitingRoom && !hasKeeper) {
            // If joined in the waiting room, everyone can join unmuted.
            return _options?.microphoneEnabled;
          }
          if (state.roomState.status == RoomStatus.active) {
            if (state.speakingNow == context!.room.localParticipant?.identity) {
              // If it's the user's turn to speak, they can join unmuted.
              return _options?.microphoneEnabled;
            }
          }
          // In other states, only the keeper can join unmuted.
          return isKeeper() && (_options?.microphoneEnabled ?? false);
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
    );

    // _userSpeakerPreference is always true: when no external audio device
    // is connected, the app should default to speaker (not earpiece).
    _userSpeakerPreference = true;
    _hasExternalOutput = false;

    _autoSetSpeakerphone(true);
    _applyScreenCapturePolicy();

    options.onConnected();
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
    state = state.copyWith(connectionState: RoomConnectionState.error);
    _options?.onLivekitError(error);
  }

  void _onRoomChanges([RoomState? newSessionState]) {
    _updateParticipantsList();
    if (newSessionState != null) {
      state = state.copyWith(roomState: newSessionState);
    } else {
      final metadata = context?.room.metadata;
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
      '(${context?.room.localParticipant}) Received data on topic "${event.topic}" from participant "${event.participant?.identity}": $data',
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
        _options?.onEmojiReceived(event.participant!.identity, data);
      case SessionCommunicationTopics.chat:
        try {
          final message = ChatMessage.fromMap(
            jsonDecode(data) as Map<String, dynamic>,
            event.participant,
          );
          _options?.onMessageReceived(
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
          if (identity == context?.room.localParticipant?.identity) {
            logger.d(
              'Received participant removed event for local participant.',
            );
            state = state.copyWith(removed: true);
            context?.disconnect();
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
    logger.d('Session has ended. Cleaning up and disconnecting.');
    endBackgroundMode();
    context?.disconnect();
  }

  Future<void> leave() async {
    await context?.disconnect();
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

    closeKeeperLeftNotifications();

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
      context
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

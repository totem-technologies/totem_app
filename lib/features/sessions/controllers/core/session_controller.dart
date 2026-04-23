import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions, logger;
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/auth/controllers/auth_controller.dart';
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/config/app_config.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/home/repositories/home_screen_repository.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state_events.dart';
import 'package:totem_app/features/sessions/controllers/core/session_state_reducer.dart';
import 'package:totem_app/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_app/features/sessions/controllers/features/session_infra_controller.dart';
import 'package:totem_app/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_app/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_app/features/sessions/controllers/utils.dart';
import 'package:totem_app/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_app/features/sessions/providers/session_cues_provider.dart';
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart'
    show sessionScopeProvider;
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/shared/logger.dart';

export 'package:totem_app/features/sessions/controllers/core/session_state.dart';
export 'package:totem_app/features/sessions/controllers/features/session_messaging_controller.dart'
    show SessionChatMessage;
export 'package:totem_app/features/sessions/controllers/utils.dart';

part 'session_controller.g.dart';

class SessionRoomMetadataResult {
  const SessionRoomMetadataResult({
    required this.roomState,
    required this.lastMetadata,
  });

  final RoomState? roomState;
  final String? lastMetadata;
}

enum RoomScreen {
  error,
  loading,
  disconnected,
  receiving,
  passing,
  speaking,
  listening,
}

/// The reason the session was diconnected.
///
/// See also:
///
///  * [DisconnectReason], the reason the user was disconnected from the livekit room.
enum SessionDisconnectedReason {
  /// The same account joined from another device and replaced this device.
  movedToAnotherDevice,

  /// The session has ended normally, usually by the keeper.
  keeperEnded,

  /// The keeper left the session and didn't come back within the timeout period.
  keeperAbsent,

  /// The keeper never joined the session and it ended after the timeout period.
  roomEmpty,

  /// The user was kicked out of the session by the keeper.
  removed,
}

@riverpod
class SessionController extends _$SessionController {
  Room? _room;
  Room? get room => _room;
  EventsListener<RoomEvent>? _listener;

  /// The sync timer periodically checks for changes in the room state
  /// and participants list, to keep the UI up to date.
  Timer? _syncTimer;
  static const syncTimerDuration = Duration(seconds: 20);

  bool? _cameraEnabledOverride;
  bool? _microphoneEnabledOverride;
  String? _lastMetadata;
  SessionDetailSchema? event;
  static const SessionStateReducer _stateReducer = SessionStateReducer();

  static const defaultCameraCaptureOptions = CameraCaptureOptions(
    params: VideoParameters(
      dimensions: VideoDimensionsPresets.h720_43,
      encoding: VideoEncoding(
        maxBitrate: 1300 * 1000,
        maxFramerate: 20,
      ),
    ),
  );

  SessionDeviceController get devices {
    return ref.read(sessionDeviceControllerProvider(this).notifier);
  }

  SessionMessagingController get messaging {
    return ref.read(sessionMessagingControllerProvider(this).notifier);
  }

  SessionKeeperController get keeper {
    return ref.read(sessionKeeperControllerProvider(this).notifier);
  }

  bool isCurrentUserKeeper() {
    final currentUserSlug = ref.read(
      authControllerProvider.select((auth) => auth.user?.slug),
    );
    if (currentUserSlug == null) return false;
    return state.isKeeper(currentUserSlug);
  }

  void _onKeeperDisconnected() {
    keeper.onKeeperDisconnected(state.roomState.status);
  }

  void _onKeeperConnected() {
    keeper.onKeeperConnected();
  }

  void setKeeperDisconnected(bool hasKeeperDisconnected) {
    _dispatch(KeeperDisconnectedChanged(hasKeeperDisconnected));
  }

  void addSessionChatMessage(SessionChatMessage message) {
    _dispatch(SessionChatMessageAdded(message));
  }

  void markParticipantRemoved() {
    _dispatch(const ParticipantRemoved());
  }

  void applyRoomState(RoomState roomState) {
    _onRoomChanges(roomState);
  }

  Future<void> disconnectFromRoom() {
    return _disconnect();
  }

  void _dispatch(SessionEvent event) {
    state = _stateReducer.reduceState(state, event);
  }

  @override
  SessionRoomState build(SessionOptions options) {
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
      ),
    );
  }

  void _updateParticipantsList() {
    try {
      final participantsSorted = sortedParticipants();

      final hasKeeper = participantsSorted.any(
        (p) => state.isKeeper(p.identity),
      );
      if (state.hasKeeperDisconnected && hasKeeper) {
        _onKeeperConnected();
      }

      _dispatch(ParticipantsChanged(participantsSorted));
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
      '"${room?.localParticipant?.identity}".',
    );

    _onRoomChanges();

    _applyJoinMediaState();
    _dispatch(
      const ConnectionChanged(
        RoomConnectionState.connected,
        SessionPhase.connected,
      ),
    );

    final speakerPref = options.speakerEnabled;
    devices.resetSpeakerRoutingDefaults(speakerPref);
    // Delay setting up the listener and applying the initial routing up to a bit.
    // This allows LiveKit's FastConnect and incoming WebRTC streams to settle,
    // avoiding the earpiece/default audio routing from overriding our preference.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!ref.mounted) return;
      devices.setupDeviceChangeListener();
    });

    _updateParticipantsList();
  }

  void _onDisconnected() {
    _dispatch(
      const ConnectionChanged(
        RoomConnectionState.disconnected,
        SessionPhase.disconnected,
      ),
    );
    _cleanUp();
  }

  void _onError(LiveKitException? error) {
    if (error == null) return;
    ErrorHandler.handleLivekitError(error);
    _dispatch(SessionErrorChanged(RoomLiveKitError(error)));
  }

  void _onRoomChanges([RoomState? newSessionState]) {
    _updateParticipantsList();
    if (newSessionState != null) {
      _dispatch(RoomStateChanged(newSessionState));
    } else {
      final metadataResult = resolveMetadataState(
        metadata: room?.metadata,
        lastMetadata: _lastMetadata,
      );
      _lastMetadata = metadataResult.lastMetadata;
      if (metadataResult.roomState != null) {
        _dispatch(RoomStateChanged(metadataResult.roomState!));
      }
    }

    if (state.roomState.status == RoomStatus.ended) {
      _onSessionEnd();
    }
  }

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
      const ConnectionChanged(
        RoomConnectionState.connecting,
        SessionPhase.connecting,
      ),
    );

    final cameraEnabled = _cameraEnabledOverride ?? options.cameraEnabled;

    await initializeConnection(
      roomOptions: RoomOptions(
        defaultCameraCaptureOptions: options.cameraOptions,
        defaultAudioCaptureOptions: const AudioCaptureOptions(),
        defaultAudioOutputOptions: AudioOutputOptions(
          speakerOn: options.speakerEnabled,
        ),
        dynacast: true,
        defaultVideoPublishOptions: const VideoPublishOptions(
          // simulcast: true,
          videoCodec: 'h265',
          //   videoEncoding: const VideoEncoding(
          //     maxBitrate: 1_500_000,
          //     maxFramerate: 30,
          //   ),
          //   videoSimulcastLayers: [
          //     // Low: Small tiles (216p @ 15fps) - Minimal CPU impact
          //     // const VideoParameters(
          //     //   dimensions: VideoDimensions(384, 216),
          //     //   encoding: VideoEncoding(
          //     //     maxBitrate: 150_000,
          //     //     maxFramerate: 15,
          //     //   ),
          //     // ),
          //     // Medium: Mid-size tiles (540p @ 20fps)
          //     const VideoParameters(
          //       dimensions: VideoDimensions(960, 540),
          //       encoding: VideoEncoding(
          //         maxBitrate: 450_000,
          //         maxFramerate: 24,
          //       ),
          //     ),
          //     // High: The active speaker (720p @ 30fps)
          //     VideoParameters(
          //       dimensions: VideoParametersPresets.h720_169.dimensions,
          //       encoding: const VideoEncoding(
          //         maxBitrate: 1_500_000,
          //         maxFramerate: 30,
          //       ),
          //     ),
          //   ],
        ),
        adaptiveStream: true,
      ),
      url: AppConfig.liveKitUrl,
      token: options.token,
    );

    await ref
        .read(sessionInfraControllerProvider.notifier)
        .activate(event: event);

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      SessionController.syncTimerDuration,
      (_) => _onRoomChanges(),
    );

    try {
      await _connect(
        url: AppConfig.liveKitUrl,
        token: options.token,
        fastConnectOptions: FastConnectOptions(
          microphone: TrackOption(enabled: options.microphoneEnabled),
          camera: TrackOption(enabled: cameraEnabled),
        ),
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error connecting to LiveKit room',
      );
      _onError(error is LiveKitException ? error : null);
    }

    ref.read(sessionCuesServiceProvider).playSessionTransitionCue();
  }

  Future<void> leave() async {
    await _disconnect();
    _cleanUp();
  }

  void _cleanUp() {
    logger.d('Disposing SessionService and closing connections.');

    if (ref.mounted) {
      unawaited(
        ref.read(sessionInfraControllerProvider.notifier).deactivate(),
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
      try {
        keeper.disposePresenceTracking();
      } catch (_) {}
      try {
        devices.dispose();
      } catch (_) {}
    }

    _syncTimer?.cancel();
    _syncTimer = null;

    disposeConnection();
  }

  @visibleForTesting
  Future<Room> initializeConnection({
    required RoomOptions roomOptions,
    required String url,
    required String token,
  }) async {
    final room = _room ??= Room(roomOptions: roomOptions);
    await room.prepareConnection(url, token);

    _listener ??= room.createListener()
      ..on((_) {
        if (ref.mounted) {
          _onRoomChanges();
        }
      })
      ..on<RoomConnectedEvent>((_) => _onConnected())
      ..on<RoomDisconnectedEvent>((event) {
        logger.d('Disconnected from session. Reason: ${event.reason}');
        if (event.reason != null) {
          _dispatch(
            SessionErrorChanged(RoomDisconnectionError(event.reason!)),
          );
        }
        _onDisconnected();
      })
      ..on<DataReceivedEvent>(messaging.handleDataReceived)
      ..on<ParticipantDisconnectedEvent>(_onParticipantDisconnected)
      ..on<ParticipantConnectedEvent>(_onParticipantConnected);

    return room;
  }

  Future<void> _connect({
    required String url,
    required String token,
    required FastConnectOptions fastConnectOptions,
  }) async {
    await _room?.connect(
      url,
      token,
      fastConnectOptions: fastConnectOptions,
    );
  }

  Future<void> _disconnect() async {
    await _disableLocalMediaTracks();
    await _room?.disconnect();
  }

  Future<void> _disableLocalMediaTracks() async {
    final localParticipant = _room?.localParticipant;
    if (localParticipant == null) {
      return;
    }

    try {
      await localParticipant.setCameraEnabled(false);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to disable camera while leaving session',
      );
    }

    try {
      await localParticipant.setMicrophoneEnabled(false);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to disable microphone while leaving session',
      );
    }
  }

  @visibleForTesting
  Future<void> disposeConnection() async {
    await _disableLocalMediaTracks();

    try {
      _listener
        ?..cancelAll()
        ..dispose();
    } catch (_) {}
    _listener = null;

    try {
      _room?.dispose();
    } catch (_) {}
    _room = null;
  }

  Future<void> _applyJoinMediaState() async {
    final currentRoom = room;
    if (currentRoom == null) return;

    final cameraEnabled = _cameraEnabledOverride ?? options.cameraEnabled;
    currentRoom.localParticipant?.setCameraEnabled(cameraEnabled);

    final shouldEnableMicrophone = () {
      if (state.roomState.status == RoomStatus.waitingRoom &&
          !state.hasKeeper) {
        return _microphoneEnabledOverride ?? options.microphoneEnabled;
      }
      if (state.roomState.status == RoomStatus.active &&
          state.speakingNow == currentRoom.localParticipant?.identity) {
        return _microphoneEnabledOverride ?? options.microphoneEnabled;
      }
      return isCurrentUserKeeper() &&
          (_microphoneEnabledOverride ?? options.microphoneEnabled);
    }();

    if (shouldEnableMicrophone) {
      await devices.enableMicrophone();
    } else {
      await devices.disableMicrophone();
    }
  }

  @visibleForTesting
  List<Participant> sortedParticipants() {
    final participants = <Participant>[
      if (room != null) ...[
        ...?room?.remoteParticipants.values,
        ?room?.localParticipant,
      ],
    ];

    return participantsSorting(
      originalParticipants: participants,
      state: state,
      showSpeakingNow: true,
    );
  }

  @visibleForTesting
  SessionRoomMetadataResult resolveMetadataState({
    required String? metadata,
    required String? lastMetadata,
  }) {
    if (metadata == null || metadata.isEmpty) {
      return SessionRoomMetadataResult(
        roomState: null,
        lastMetadata: lastMetadata,
      );
    }

    try {
      if (lastMetadata == null) {
        return SessionRoomMetadataResult(
          roomState: RoomState.fromJson(
            jsonDecode(metadata) as Map<String, dynamic>,
          ),
          lastMetadata: metadata,
        );
      }

      if (metadata != lastMetadata) {
        return SessionRoomMetadataResult(
          roomState: RoomState.fromJson(
            jsonDecode(metadata) as Map<String, dynamic>,
          ),
          lastMetadata: metadata,
        );
      }
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error decoding session metadata',
      );
    }

    return SessionRoomMetadataResult(
      roomState: null,
      lastMetadata: lastMetadata,
    );
  }
}

@Riverpod(keepAlive: true)
SessionRoomState session(Ref ref, SessionOptions options) {
  return ref.watch(sessionControllerProvider(options));
}

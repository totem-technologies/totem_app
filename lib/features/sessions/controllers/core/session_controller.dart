import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions, logger;
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
import 'package:totem_app/features/sessions/providers/session_scope_provider.dart'
    show sessionScopeProvider;
import 'package:totem_app/features/spaces/repositories/space_repository.dart';
import 'package:totem_app/shared/logger.dart';

export 'package:totem_app/features/sessions/controllers/core/session_state.dart';
export 'package:totem_app/features/sessions/controllers/features/session_messaging_controller.dart'
    show SessionChatMessage;
export 'package:totem_app/features/sessions/controllers/utils.dart';

part 'session_controller.g.dart';

class _SessionRoomMetadataResult {
  const _SessionRoomMetadataResult({
    required this.roomState,
    required this.lastMetadata,
  });

  final RoomState? roomState;
  final String? lastMetadata;
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

  SessionOptions? _options;
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

  void onSpeakerphoneChanged(bool enabled) {
    _dispatch(SpeakerphoneChanged(enabled));
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
        isSpeakerphoneEnabled: devices.userSpeakerPreference,
      ),
    );
  }

  void _updateParticipantsList() {
    try {
      final sortedParticipants = _sortedParticipants();

      final hasKeeper = sortedParticipants.any(
        (p) => state.isKeeper(p.identity),
      );
      if (state.hasKeeperDisconnected && hasKeeper) {
        _onKeeperConnected();
      }

      _dispatch(ParticipantsChanged(sortedParticipants));
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

    unawaited(_applyJoinMediaState());
    // context.room.localParticipant!.setMicrophoneEnabled(_options.microphoneEnabled)
    _dispatch(
      const ConnectionChanged(
        RoomConnectionState.connected,
        SessionPhase.connected,
      ),
    );

    // _userSpeakerPreference is always true: when no external audio device
    // is connected, the app should default to speaker (not earpiece).
    devices.resetSpeakerRoutingDefaults();
    unawaited(devices.setSpeakerphone(true));

    _updateParticipantsList();
    devices.setupDeviceChangeListener();
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
      final metadataResult = _resolveMetadataState(
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

    final options = _options;
    if (options == null) return;

    await _initializeConnection(
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
        .read(sessionInfraControllerProvider(options).notifier)
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
    await _disconnect();
    _cleanUp();
  }

  void _cleanUp() {
    logger.d('Disposing SessionService and closing connections.');

    final options = _options;
    if (options != null && ref.mounted) {
      unawaited(
        ref.read(sessionInfraControllerProvider(options).notifier).deactivate(),
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

    keeper.disposePresenceTracking();

    unawaited(devices.dispose());
    unawaited(_disposeConnection());
  }

  Future<Room> _initializeConnection({
    required RoomOptions roomOptions,
    required String url,
    required String token,
  }) async {
    _room ??= Room(roomOptions: roomOptions);
    await _room!.prepareConnection(url, token);

    _listener ??= _room!.createListener()
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

    return _room!;
  }

  Future<void> _connect({required String url, required String token}) async {
    await _room?.connect(url, token);
  }

  Future<void> _disconnect() async {
    await _room?.disconnect();
  }

  Future<void> _disposeConnection() async {
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
    final options = _options;
    if (currentRoom == null) return;

    final cameraEnabled =
        _cameraEnabledOverride ?? (options?.cameraEnabled ?? false);
    currentRoom.localParticipant?.setCameraEnabled(cameraEnabled);

    final shouldEnableMicrophone = () {
      if (state.roomState.status == RoomStatus.waitingRoom &&
          !state.hasKeeper) {
        return _microphoneEnabledOverride ?? options?.microphoneEnabled;
      }
      if (state.roomState.status == RoomStatus.active &&
          state.speakingNow == currentRoom.localParticipant?.identity) {
        return _microphoneEnabledOverride ?? options?.microphoneEnabled;
      }
      return isCurrentUserKeeper() &&
          (_microphoneEnabledOverride ?? options?.microphoneEnabled ?? false);
    }();

    if (shouldEnableMicrophone ?? false) {
      await devices.enableMicrophone();
    } else {
      await devices.disableMicrophone();
    }
  }

  List<Participant> _sortedParticipants() {
    final participants = <Participant>[
      if (room != null) ...[
        ...room!.remoteParticipants.values,
        if (room!.localParticipant != null) room!.localParticipant!,
      ],
    ];

    return participantsSorting(
      originalParticipants: participants,
      state: state,
      showSpeakingNow: true,
    );
  }

  _SessionRoomMetadataResult _resolveMetadataState({
    required String? metadata,
    required String? lastMetadata,
  }) {
    if (metadata == null || metadata.isEmpty) {
      return _SessionRoomMetadataResult(
        roomState: null,
        lastMetadata: lastMetadata,
      );
    }

    try {
      if (lastMetadata == null) {
        return _SessionRoomMetadataResult(
          roomState: RoomState.fromJson(
            jsonDecode(metadata) as Map<String, dynamic>,
          ),
          lastMetadata: metadata,
        );
      }

      if (metadata != lastMetadata) {
        return _SessionRoomMetadataResult(
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

    return _SessionRoomMetadataResult(
      roomState: null,
      lastMetadata: lastMetadata,
    );
  }
}

@Riverpod(keepAlive: true)
SessionRoomState session(Ref ref, SessionOptions options) {
  return ref.watch(sessionControllerProvider(options));
}

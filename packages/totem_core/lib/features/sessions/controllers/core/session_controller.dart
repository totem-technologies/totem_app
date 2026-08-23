import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions, logger;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/controllers/core/join_media_owner.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state_events.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state_reducer.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_infra_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/controllers/utils.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart'
    show sessionScopeProvider;
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/shared/logger.dart';

export 'package:totem_core/features/sessions/controllers/core/session_state.dart';
export 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart'
    show SessionChatMessage;
export 'package:totem_core/features/sessions/controllers/utils.dart';

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

  /// The user was banned from the session by the keeper.
  banned,

  /// The user was disconnected for an unknown reason.
  other,
}

enum SessionJoinResult {
  success,
  retryableFailure,
  fatalFailure,
}

@riverpod
class SessionController extends _$SessionController {
  Room? _room;
  Room? get room => _room;
  @visibleForTesting
  set room(Room? value) {
    _room = value;
  }

  EventsListener<RoomEvent>? _listener;
  bool _awaitingInitialMicrophonePublication = false;

  final JoinMediaOwner _joinMediaOwner = JoinMediaOwner();

  /// The sync timer periodically checks for changes in the room state
  /// and participants list, to keep the UI up to date.
  KeepAliveLink? _keepAliveLink;
  Timer? _syncTimer;
  Timer? _statePollTimer;
  static const syncTimerDuration = Duration(seconds: 20);
  static const _statePollInterval = Duration(seconds: 15);

  String? _lastMetadata;
  SessionDetailSchema? session;
  static const SessionStateReducer _stateReducer = SessionStateReducer();

  /// The capture framerate caps both the local self-view and the published
  /// stream (the camera is the single source for both).
  static const defaultCameraCaptureOptions = CameraCaptureOptions(
    params: VideoParameters(
      dimensions: VideoDimensionsPresets.h720_43,
      encoding: VideoEncoding(
        maxBitrate: 1300 * 1000,
        maxFramerate: 24,
      ),
    ),
  );

  /// h264 has hardware encode/decode on effectively every mobile device.
  ///
  /// Some Browsers have trouble encoding h265.
  /// Prefer h265 on mobile devices.
  static const defaultVideoPublishOptions = VideoPublishOptions(
    videoCodec: (kIsWeb || kIsWasm) ? 'h264' : 'h265',
    backupVideoCodec: BackupVideoCodec(codec: 'h264'),
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

  void addSessionChatMessage(SessionChatMessage message) {
    _dispatch(SessionChatMessageAdded(message));
  }

  void markParticipantRemoved(RemoveReason reason) {
    _dispatch(ParticipantRemoved(reason));
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
        .watch(sessionProvider(options.sessionSlug))
        .whenData((event) => session = event);

    ref.onDispose(() => unawaited(_cleanUp()));

    final initialRoomState = RoomState(
      keeper: session?.space.author.slug ?? '',
      nextSpeaker: '',
      currentSpeaker: '',
      status: RoomStatus.waitingRoom,
      turnState: TurnState.idle,
      sessionSlug: options.sessionSlug,
      statusDetail: const RoomStateStatusDetailWaitingRoom(
        WaitingRoomDetail(),
      ),
      talkingOrder: const [],
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
      final previousParticipants = state.participantsList;
      final hadKeeper = previousParticipants.any(
        (p) => state.isKeeper(p.identity),
      );

      final participantsSorted = sortedParticipants();
      final hasKeeper = participantsSorted.any(
        (p) => state.isKeeper(p.identity),
      );

      logger.d(
        '_updateParticipantsList: hasKeeper=$hasKeeper, roomStatus=${state.roomState.status}, participants=${participantsSorted.map((p) => p.identity).toList()}',
      );

      if (!hadKeeper && hasKeeper) {
        keeper.onKeeperConnected();
      } else if (hadKeeper && !hasKeeper) {
        keeper.onKeeperDisconnected(state.roomState.status);
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

    unawaited(_applyJoinMediaState());
    _dispatch(
      const ConnectionChanged(
        RoomConnectionState.connected,
        SessionPhase.connected,
      ),
    );

    // Fetch server state immediately on join so the client is never stuck with
    // stale local state when LiveKit metadata is empty (e.g. room was killed and
    // recreated on Livekit but alive on the Totem server).
    unawaited(_pollServerState());

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
    _disableLocalMediaTracks();
    _dispatch(
      const ConnectionChanged(
        RoomConnectionState.disconnected,
        SessionPhase.disconnected,
      ),
    );
    _cleanUp();
  }

  void preventAutoDispose() {
    _keepAliveLink ??= ref.keepAlive();
  }

  void allowAutoDispose() {
    _keepAliveLink?.close();
    _keepAliveLink = null;
  }

  void _onError(LiveKitException? error) {
    if (error == null) return;
    ErrorHandler.handleLivekitError(error);
    _dispatch(SessionErrorChanged(RoomLiveKitError(error)));
  }

  void _onRoomChanges([RoomState? newSessionState]) {
    _updateParticipantsList();
    void handleStateChange(RoomState state) {
      if (state.version <= this.state.roomState.version) return;

      if (state.status == RoomStatus.ended) {
        _disableLocalMediaTracks();
      }
      _dispatch(RoomStateChanged(state));
    }

    if (newSessionState != null) {
      handleStateChange(newSessionState);
    } else {
      final metadataResult = resolveMetadataState(
        metadata: room?.metadata,
        lastMetadata: _lastMetadata,
      );
      _lastMetadata = metadataResult.lastMetadata;
      if (metadataResult.roomState != null) {
        handleStateChange(metadataResult.roomState!);
      }
    }

    if (state.roomState.status == RoomStatus.ended) {
      _onSessionEnd();
    }
  }

  Future<void> _pollServerState() async {
    if (!ref.mounted) return;
    if (state.connectionState != RoomConnectionState.connected) return;

    try {
      final roomState = await ref.read(
        roomStateProvider(options.sessionSlug).future,
      );
      if (!ref.mounted) return;

      // Protects against out-of-order application from overlapping polls
      if (roomState.version > state.roomState.version) {
        applyRoomState(roomState);
        logger.d('Polled server state: version ${roomState.version}');
      }
    } catch (e, s) {
      logger.d(
        'poll room state failed (will retry next tick)',
        error: e,
        stackTrace: s,
      );
      // Network hiccup or transient error - the next poll will retry.
    }
  }

  void _startStatePolling() {
    _statePollTimer?.cancel();
    _statePollTimer = Timer.periodic(_statePollInterval, (_) {
      unawaited(_pollServerState());
    });
  }

  void _onParticipantDisconnected(ParticipantDisconnectedEvent event) {
    if (isCurrentUserKeeper()) _pollServerState();
    _updateParticipantsList();
  }

  void _onParticipantConnected(ParticipantConnectedEvent event) {
    _updateParticipantsList();
  }

  Future<void> _onSessionEnd() async {
    logger.d('Session has ended. Cleaning up and disconnecting.');
    await leave();
  }

  Future<SessionJoinResult> join({SessionJoinMedia? joinMedia}) async {
    final retainedJoinMedia = _joinMediaOwner.retain(joinMedia);

    if (state.connectionState == RoomConnectionState.connected ||
        state.connectionState == RoomConnectionState.connecting) {
      // The caller transferred ownership, but this no-op join will never hand
      // these tracks to LiveKit. Release only the media supplied by this call;
      // tracks retained by an in-flight join must remain alive. Connection
      // state becomes connecting before initializeConnection assigns _room, so
      // the state machine itself must be the re-entrancy guard.
      if (retainedJoinMedia.hasOwnedTracks) {
        _detachJoinMediaPreview(joinMedia);
      }
      await retainedJoinMedia.dispose();
      return SessionJoinResult.success;
    }

    _dispatch(
      const ConnectionChanged(
        RoomConnectionState.connecting,
        SessionPhase.connecting,
      ),
    );

    try {
      await initializeConnection(
        roomOptions: RoomOptions(
          defaultCameraCaptureOptions: options.cameraOptions,
          defaultAudioCaptureOptions: const AudioCaptureOptions(),
          defaultAudioOutputOptions: AudioOutputOptions(
            speakerOn: options.speakerEnabled,
          ),
          dynacast: true,
          defaultVideoPublishOptions: defaultVideoPublishOptions,
          adaptiveStream: true,
        ),
        url: AppConfig.instance.liveKitUrl,
        token: options.token,
      );

      await ref
          .read(sessionInfraControllerProvider.notifier)
          .activate(event: session);

      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(
        SessionController.syncTimerDuration,
        (_) => _onRoomChanges(),
      );
      _startStatePolling();

      final connectOptions = defaultTargetPlatform == TargetPlatform.iOS
          ? const ConnectOptions(
              timeouts: Timeouts(
                connection: Duration(seconds: 30),
                debounce: Duration(milliseconds: 20),
                publish: Duration(seconds: 10),
                subscribe: Duration(seconds: 10),
                peerConnection: Duration(seconds: 10),
                iceRestart: Duration(seconds: 10),
              ),
            )
          : null;

      final initialCameraTrack = options.cameraEnabled
          ? _joinMediaOwner.track<LocalVideoTrack>()
          : null;
      final initialMicrophoneTrack = options.microphoneEnabled
          ? _joinMediaOwner.track<LocalAudioTrack>()
          : null;

      final fastConnectOptions = FastConnectOptions(
        microphone: initialMicrophoneTrack != null
            ? TrackOption(track: initialMicrophoneTrack)
            : TrackOption(enabled: options.microphoneEnabled),
        camera: initialCameraTrack != null
            ? TrackOption(track: initialCameraTrack)
            : TrackOption(enabled: options.cameraEnabled),
      );

      // A successful Room.connect transfers ownership even though the
      // LocalTrackPublication may not be visible yet: LiveKit's
      // EngineJoinResponseEvent handler performs FastConnect publication
      // asynchronously. If connect throws, retain ownership so failed-join
      // cleanup below can stop the raw capture before join returns.
      _awaitingInitialMicrophonePublication = options.microphoneEnabled;
      try {
        await _connect(
          url: AppConfig.instance.liveKitUrl,
          token: options.token,
          fastConnectOptions: fastConnectOptions,
          connectOptions: connectOptions,
        );
      } catch (_) {
        _awaitingInitialMicrophonePublication = false;
        rethrow;
      }
      _joinMediaOwner
        ..releaseToRoom(initialCameraTrack)
        ..releaseToRoom(initialMicrophoneTrack);
      // Residual SDK limitation: Room.connect can succeed before FastConnect
      // publication finishes. If that later asynchronous publication fails,
      // LiveKit exposes no completion/error future through which ownership can
      // be reclaimed, so the raw track can remain live until browser cleanup.
      return SessionJoinResult.success;
    }
    // For ConnectException and MediaConnectException, we log the error but don't
    // necessarily want to show an error message to the user.
    // https://github.com/livekit/client-sdk-flutter/issues/756#issuecomment-4565674372
    on ConnectException catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message:
            '(${error.statusCode}) Error connecting to LiveKit room: ${error.reason}',
      );
      switch (error.reason) {
        case ConnectionErrorReason.NotAllowed:
        case ConnectionErrorReason.InternalError:
          // This error can occur when the token is invalid or doesn't have the right permissions.
          // In this case, we want to show an error message to the user.
          _onError(error);
          return SessionJoinResult.fatalFailure;
        case ConnectionErrorReason.Timeout:
          // These errors can occur due to transient network issues or server problems.
          // We can choose to retry the connection or show an error message.
          return SessionJoinResult.retryableFailure;
      }
    } on MediaConnectException catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error establishing media connection to LiveKit room',
      );
      // We may want to catch this error in the future.
      // _onError(error);
      return SessionJoinResult.retryableFailure;
    } on LiveKitException catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error connecting to LiveKit room',
      );
      _onError(error);
      return SessionJoinResult.fatalFailure;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Unexpected error occurred',
      );
      return SessionJoinResult.retryableFailure;
    } finally {
      // Successful FastConnect tracks were removed from the owner above, so
      // this only disposes media that LiveKit did not accept. In particular,
      // fatal failures keep rendering the Session error UI and never run the
      // retry reset path, so join itself must release their live capture.
      if (retainedJoinMedia.hasOwnedTracks) {
        _detachJoinMediaPreview(joinMedia);
      }
      await retainedJoinMedia.dispose();
    }
  }

  void _detachJoinMediaPreview(SessionJoinMedia? joinMedia) {
    try {
      joinMedia?.onBeforeDispose?.call();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to detach pre-join media before disposal',
      );
    }
  }

  /// Tears down a failed connection attempt while keeping the controller
  /// available for another join from the pre-join screen.
  Future<void> resetAfterFailedJoin() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    _statePollTimer?.cancel();
    _statePollTimer = null;

    if (ref.mounted) {
      try {
        await ref.read(sessionInfraControllerProvider.notifier).deactivate();
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to deactivate session infrastructure after join',
        );
      }
    }

    await disposeConnection();
    if (ref.mounted) {
      _dispatch(
        const ConnectionChanged(
          RoomConnectionState.disconnected,
          SessionPhase.idle,
          wasJoining: true,
        ),
      );
    }
  }

  Future<void> leave() async {
    try {
      await _disconnect();
    } finally {
      await _cleanUp();
    }
  }

  Future<void> _cleanUp() async {
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
      if (session != null) {
        try {
          ref.invalidate(spaceProvider(session!.space.slug));
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
    _statePollTimer?.cancel();
    _statePollTimer = null;

    await disposeConnection();
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
        // Handles transient disconnects that can occur during the joining process,
        // to avoid showing the disconnected screen in those cases.
        //
        // Usually happens on iOS: https://github.com/livekit/client-sdk-flutter/issues/756
        final isTransientJoinDisconnect =
            state.connectionState == RoomConnectionState.connecting &&
            isTransientJoinDisconnectReason(event.reason);

        if (isTransientJoinDisconnect) {
          _dispatch(
            const ConnectionChanged(
              RoomConnectionState.disconnected,
              SessionPhase.disconnected,
              wasJoining: true,
            ),
          );
          return;
        }

        if (event.reason != null) {
          _dispatch(
            SessionErrorChanged(RoomDisconnectionError(event.reason!)),
          );
        }
        _onDisconnected();
      })
      ..on<DataReceivedEvent>((data) {
        if (ref.mounted) messaging.handleDataReceived(data);
      })
      ..on<LocalTrackPublishedEvent>((event) {
        if (!_awaitingInitialMicrophonePublication ||
            event.participant != room.localParticipant ||
            event.publication.source != TrackSource.microphone) {
          return;
        }

        _awaitingInitialMicrophonePublication = false;
        unawaited(_applyJoinMediaState());
      })
      ..on<ParticipantDisconnectedEvent>(_onParticipantDisconnected)
      ..on<ParticipantConnectedEvent>(_onParticipantConnected);

    return room;
  }

  Future<void> _connect({
    required String url,
    required String token,
    FastConnectOptions? fastConnectOptions,
    ConnectOptions? connectOptions,
  }) async {
    await _room?.connect(
      url,
      token,
      connectOptions: connectOptions,
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
    _awaitingInitialMicrophonePublication = false;
    await _disableLocalMediaTracks();

    try {
      _listener
        ?..cancelAll()
        ..dispose();
    } catch (_) {}
    _listener = null;

    try {
      await _room?.dispose();
    } catch (_) {}
    _room = null;

    await _joinMediaOwner.disposeAll();
  }

  Future<void> _applyJoinMediaState() async {
    final currentRoom = room;
    if (currentRoom == null) return;

    // FastConnect is the sole owner of initial capture enablement. Its
    // publication continues asynchronously after Room.connect completes, so
    // enabling either source here can open a second getUserMedia capture before
    // the first publication is registered. Camera needs no post-connect policy
    // adjustment: FastConnect already received options.cameraEnabled.

    final shouldEnableMicrophone = () {
      if (state.roomState.status == RoomStatus.waitingRoom &&
          !state.hasKeeper) {
        return options.microphoneEnabled;
      }
      if (state.roomState.status == RoomStatus.active) {
        if (state.speakingNow == currentRoom.localParticipant?.identity) {
          return options.microphoneEnabled;
        }
        return false;
      }
      return isCurrentUserKeeper() && options.microphoneEnabled;
    }();

    if (!shouldEnableMicrophone) {
      try {
        await devices.disableMicrophone();
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to apply initial microphone state',
        );
      }
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

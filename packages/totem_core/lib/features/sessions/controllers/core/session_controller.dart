import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, SessionOptions, logger;
import 'package:livekit_client/livekit_client.dart'
    as livekit
    show ConnectionState;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
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
import 'package:totem_core/features/sessions/media/livekit_local_media.dart';
import 'package:totem_core/features/sessions/media/livekit_room_media.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';
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

enum SessionJoinResult { success, retryableFailure, fatalFailure }

@riverpod
class SessionController extends _$SessionController {
  Room? _room;
  Room? get room => _room;
  @visibleForTesting
  set room(Room? value) {
    _room = value;
    _localMedia.attach(value);
    _roomMedia.attach(value);
  }

  final LiveKitLocalMedia _localMedia = LiveKitLocalMedia(
    cameraCaptureOptions: defaultCameraCaptureOptions,
  );
  LocalMedia get localMedia => _localMedia;

  final LiveKitRoomMedia _roomMedia = LiveKitRoomMedia();
  RoomMedia get roomMedia => _roomMedia;

  EventsListener<RoomEvent>? _listener;
  Room? _pendingConnectedRoom;
  bool _isAdoptingConnectedRoom = false;
  final Set<Object> _subscribedRemotePublications = Set.identity();
  Set<String>? _admittedMediaRecipients;
  Set<String>? _appliedMediaRecipients;

  final JoinMediaOwner _joinMediaOwner = JoinMediaOwner();

  /// The sync timer periodically checks for changes in the room state
  /// and participants list, to keep the UI up to date.
  KeepAliveLink? _keepAliveLink;
  Timer? _syncTimer;
  Timer? _statePollTimer;
  Future<void>? _leaveFuture;
  Future<void>? _cleanupFuture;
  Future<void>? _statePollFuture;
  bool _pollPending = false;
  bool _pendingReconcile = false;
  int _connectionGeneration = 0;
  int _consecutivePollFailures = 0;
  static const _pollFailureReportThreshold = 3;
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
      encoding: VideoEncoding(maxBitrate: 1300 * 1000, maxFramerate: 24),
    ),
  );

  /// h264 has hardware encode/decode on effectively every mobile device.
  ///
  /// Some Browsers have trouble encoding h265.
  /// Prefer h265 on mobile devices.
  static final VideoPublishOptions defaultVideoPublishOptions =
      videoPublishOptionsForPlatform(isWeb: kIsWeb, isWasm: kIsWasm);

  static VideoPublishOptions videoPublishOptionsForPlatform({
    required bool isWeb,
    required bool isWasm,
  }) => VideoPublishOptions(
    videoCodec: (isWeb || isWasm) ? 'h264' : 'h265',
    backupVideoCodec: const BackupVideoCodec(codec: 'h264'),
  );

  static RoomOptions sessionRoomOptions({
    required CameraCaptureOptions cameraOptions,
    required bool speakerEnabled,
  }) => LiveKitLocalMedia.applyCapturePolicy(
    RoomOptions(
      defaultCameraCaptureOptions: cameraOptions,
      defaultAudioOutputOptions: AudioOutputOptions(speakerOn: speakerEnabled),
      dynacast: true,
      defaultVideoPublishOptions: defaultVideoPublishOptions,
      adaptiveStream: true,
    ),
  );

  SessionDeviceController get devices {
    return ref.read(sessionDeviceControllerProvider(this).notifier);
  }

  SessionMessagingController? _messaging;

  SessionMessagingController get messaging {
    final existing = _messaging;
    if (existing != null) return existing;
    final controller = ref.read(
      sessionMessagingControllerProvider(this).notifier,
    );
    _messaging = controller;
    return controller;
  }

  SessionKeeperController get keeper {
    return ref.read(sessionKeeperControllerProvider(this).notifier);
  }

  bool isCurrentUserKeeper() {
    final currentUserSlug = ref.read(
      authControllerProvider.select((auth) => auth.user?.slug.value),
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
    _updateRoomState(roomState);
  }

  /// Limits local media subscriptions to the keeper and admitted recipients.
  ///
  /// Until this method receives a roster, non-keeper publishers fail closed
  /// while retaining access for the keeper when its identity is known.
  void updateAdmittedMediaRecipients(Set<String> identities) {
    _admittedMediaRecipients = Set.unmodifiable(identities);
    _applyMediaSubscriptionPermissions();
  }

  Future<void> disconnectFromRoom() async {
    try {
      await leave();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to disconnect from session',
      );
    }
  }

  void _dispatch(SessionEvent event) {
    state = _stateReducer.reduceState(state, event);
  }

  @override
  SessionRoomState build(SessionOptions options) {
    ref
      ..listen(sessionDeviceControllerProvider(this), (_, _) {})
      ..listen(sessionInfraControllerProvider, (_, _) {})
      ..listen(sessionKeeperControllerProvider(this), (_, _) {})
      ..listen(sessionMessagingControllerProvider(this), (_, _) {});
    // The device controls follow the session's state until tracks publish.
    listenSelf((_, _) => devices.syncWithSession());

    ref
        .watch(sessionProvider(options.sessionSlug))
        .whenData((event) => session = event);

    ref.onDispose(() {
      final pendingRoom = _pendingConnectedRoom;
      _pendingConnectedRoom = null;
      if (pendingRoom != null && !identical(pendingRoom, _room)) {
        unawaited(_releaseOfferedRoom(pendingRoom));
      }
      _cleanUpInBackground('Failed to clean up session');
    });

    final initialRoomState = RoomState(
      keeper: session?.space.author.slug.value ?? '',
      nextSpeaker: const Omittable(''),
      currentSpeaker: const Omittable(''),
      status: RoomStatus.waitingRoom,
      turnState: TurnState.idle,
      sessionSlug: options.sessionSlug,
      statusDetail: const RoomStateStatusDetailWaitingRoom(WaitingRoomDetail()),
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
      turn: SessionTurnState(roomState: initialRoomState),
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

    _updateRoomState();
    _applyMediaSubscriptionPermissions();

    unawaited(_applyJoinMediaState());
    // A transferred pre-join track is already rendering in the loading screen.
    // Keep that renderer mounted until LiveKit has accepted the track below;
    // otherwise the room replaces it with an avatar-only tile before the
    // publication becomes available.
    final hasPendingPreJoinMedia =
        _joinMediaOwner.track<LocalVideoTrack>() != null ||
        _joinMediaOwner.track<LocalAudioTrack>() != null;
    if (!hasPendingPreJoinMedia) {
      _dispatch(
        const ConnectionChanged(
          RoomConnectionState.connected,
          SessionPhase.connected,
        ),
      );
    }

    // Fetch server state immediately on join so the client is never stuck with
    // stale local state when LiveKit metadata is empty (e.g. room was killed and
    // recreated on Livekit but alive on the Totem server).
    unawaited(_scheduleServerStatePoll());

    final speakerPref = options.speakerEnabled;
    devices.resetSpeakerRoutingDefaults(speakerPref);
    final connectionGeneration = _connectionGeneration;
    // Delay setting up the listener and applying the initial routing up to a bit.
    // This allows initial publication and incoming WebRTC streams to settle,
    // avoiding the earpiece/default audio routing from overriding our preference.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!ref.mounted || connectionGeneration != _connectionGeneration) return;
      unawaited(devices.setupDeviceChangeListener());
    });

    _updateParticipantsList();
  }

  void _onDisconnected() {
    if (_leaveFuture != null) return;

    _dispatch(
      const ConnectionChanged(
        RoomConnectionState.disconnected,
        SessionPhase.disconnected,
      ),
    );
    _cleanUpInBackground('Failed to clean up disconnected session');
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

  void _updateRoomState([RoomState? newSessionState]) {
    bool handleStateChange(RoomState nextState) {
      final currentState = state.roomState;
      final isEnding =
          currentState.status != RoomStatus.ended &&
          nextState.status == RoomStatus.ended;
      if (nextState.version < currentState.version ||
          (nextState.version == currentState.version && !isEnding)) {
        return false;
      }

      _dispatch(RoomStateChanged(nextState));
      _applyMediaSubscriptionPermissions();
      return isEnding;
    }

    var sessionEnded = false;
    if (newSessionState != null) {
      sessionEnded = handleStateChange(newSessionState);
    } else {
      final metadataResult = resolveMetadataState(
        metadata: room?.metadata,
        lastMetadata: _lastMetadata,
      );
      _lastMetadata = metadataResult.lastMetadata;
      if (metadataResult.roomState case final roomState?) {
        sessionEnded = handleStateChange(roomState);
      }
    }

    if (sessionEnded) {
      unawaited(_onSessionEnd());
    }
  }

  Future<void> _pollServerState({
    required int connectionGeneration,
    bool attemptReconcile = false,
  }) async {
    if (!ref.mounted || connectionGeneration != _connectionGeneration) return;
    if (state.connectionState != RoomConnectionState.connected) return;

    try {
      final roomState = await ref.read(
        roomStateProvider(
          options.sessionSlug,
          attemptReconcile: attemptReconcile,
        ).future,
      );
      if (!ref.mounted || connectionGeneration != _connectionGeneration) {
        return;
      }

      if (_consecutivePollFailures > 0) {
        logger.i(
          'Room-state polling recovered after $_consecutivePollFailures failure(s)',
        );
        _consecutivePollFailures = 0;
      }
      if (roomState.version > state.roomState.version) {
        applyRoomState(roomState);
        logger.d('Polled server state: version ${roomState.version}');
      }
    } catch (error, stackTrace) {
      _consecutivePollFailures++;
      logger.d(
        'poll room state failed (will retry next tick)',
        error: error,
        stackTrace: stackTrace,
      );

      final isUnexpected = error is AppDataException || error is StateError;
      if (isUnexpected ||
          _consecutivePollFailures >= _pollFailureReportThreshold) {
        ErrorHandler.report(
          error,
          stackTrace: stackTrace,
          message: 'Room-state polling failed',
          incidentKey:
              'room-state-poll:${options.sessionSlug}:${error.runtimeType}',
          diagnostics: {
            'feature': 'session',
            'operation': 'poll_room_state',
            'session_slug': options.sessionSlug,
            'attempt_reconcile': attemptReconcile,
            'consecutive_failures': _consecutivePollFailures,
            'recovery': 'pending',
          },
        );
      }
    }
  }

  Future<void> _scheduleServerStatePoll({bool attemptReconcile = false}) {
    _pollPending = true;
    _pendingReconcile = _pendingReconcile || attemptReconcile;
    return _statePollFuture ??= _drainServerStatePolls();
  }

  Future<void> _drainServerStatePolls() async {
    try {
      while (_pollPending && ref.mounted) {
        final connectionGeneration = _connectionGeneration;
        final attemptReconcile = _pendingReconcile;
        _pollPending = false;
        _pendingReconcile = false;
        await _pollServerState(
          connectionGeneration: connectionGeneration,
          attemptReconcile: attemptReconcile,
        );
      }
    } finally {
      _statePollFuture = null;
    }
  }

  void _startStatePolling() {
    _statePollTimer?.cancel();
    _statePollTimer = Timer.periodic(_statePollInterval, (_) {
      unawaited(_scheduleServerStatePoll());
    });
  }

  /// Attempts to reconcile the local state with the server state.
  void _attemptReconcile() {
    if (!isCurrentUserKeeper()) return;
    if (state.roomState.status == RoomStatus.ended) return;
    unawaited(_scheduleServerStatePoll(attemptReconcile: true));
  }

  void _onParticipantDisconnected(ParticipantDisconnectedEvent event) {
    _attemptReconcile();
    _updateParticipantsList();
  }

  void _onParticipantConnected(
    ParticipantConnectedEvent event, {
    bool Function(String identity)? isAdmitted,
  }) {
    final identity = event.participant.identity;
    final isKnownAdmittedParticipant =
        isAdmitted?.call(identity) ?? _isMediaRecipientOrKeeper(identity);
    if (isKnownAdmittedParticipant) _attemptReconcile();
    _updateParticipantsList();
  }

  bool _isMediaRecipientOrKeeper(String identity) =>
      _admittedMediaRecipients?.contains(identity) == true ||
      identity == state.roomState.keeper;

  Future<void> _onSessionEnd() async {
    logger.d('Session has ended. Cleaning up and disconnecting.');
    try {
      await leave();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to disconnect after session ended',
      );
    }
  }

  bool get _canPublishInitialMedia =>
      ref.mounted &&
      state.roomState.status != RoomStatus.ended &&
      switch (state.connectionState) {
        RoomConnectionState.connecting || RoomConnectionState.connected => true,
        _ => false,
      };

  Future<void> _waitForPreviousConnectionCleanup() async {
    final previousLeave = _leaveFuture;
    if (previousLeave != null) {
      try {
        await previousLeave;
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to leave previous session connection',
        );
      }
    }
    final previousCleanup = _cleanupFuture;
    if (previousCleanup != null) await previousCleanup;
  }

  Future<bool> _initializeSessionInfrastructure() async {
    await ref
        .read(sessionInfraControllerProvider.notifier)
        .activate(event: session);
    if (!ref.mounted) return false;

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(SessionController.syncTimerDuration, (_) {
      _updateRoomState();
      _updateParticipantsList();
    });
    _startStatePolling();
    return true;
  }

  Future<SessionJoinResult> _publishInitialMedia() async {
    final initialCameraTrack = _joinMediaOwner.track<LocalVideoTrack>();
    final initialMicrophoneTrack = _joinMediaOwner.track<LocalAudioTrack>();

    try {
      if (!_canPublishInitialMedia) return SessionJoinResult.retryableFailure;
      if (initialCameraTrack != null || options.cameraEnabled) {
        final published = await _localMedia.publishJoinCamera(
          initialCameraTrack,
          publishOptions: defaultVideoPublishOptions,
        );
        if (!ref.mounted) return SessionJoinResult.retryableFailure;
        if (published) _joinMediaOwner.releaseToRoom(initialCameraTrack);
        if (published && !options.cameraEnabled) {
          await _localMedia.setCameraEnabled(false);
        }
      }

      if (!_canPublishInitialMedia) return SessionJoinResult.retryableFailure;
      if (initialMicrophoneTrack != null || options.microphoneEnabled) {
        final published = await _localMedia.publishJoinMicrophone(
          initialMicrophoneTrack,
          muted: !shouldEnableMicrophone(),
        );
        if (!ref.mounted) return SessionJoinResult.retryableFailure;
        if (published) _joinMediaOwner.releaseToRoom(initialMicrophoneTrack);
      }

      if (!_canPublishInitialMedia) return SessionJoinResult.retryableFailure;
      await _applyJoinMediaState();
      if (!ref.mounted) return SessionJoinResult.retryableFailure;

      if ((initialCameraTrack != null || initialMicrophoneTrack != null) &&
          state.connectionState == RoomConnectionState.connecting) {
        _dispatch(
          const ConnectionChanged(
            RoomConnectionState.connected,
            SessionPhase.connected,
          ),
        );
      }
      return SessionJoinResult.success;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error publishing initial session media',
      );
      return SessionJoinResult.retryableFailure;
    }
  }

  Future<SessionJoinResult> join({SessionJoinMedia? joinMedia}) async {
    await _waitForPreviousConnectionCleanup();

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
        roomOptions: sessionRoomOptions(
          cameraOptions: options.cameraOptions,
          speakerEnabled: options.speakerEnabled,
        ),
        url: AppConfig.instance.liveKitUrl,
        token: options.token,
      );
      if (!ref.mounted || !await _initializeSessionInfrastructure()) {
        return SessionJoinResult.retryableFailure;
      }

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

      // FastConnect publishes supplied tracks asynchronously after connect
      // completes. Publish explicitly so join cannot report a false success.
      await _connect(
        url: AppConfig.instance.liveKitUrl,
        token: options.token,
        connectOptions: connectOptions,
      );
      if (!ref.mounted) return SessionJoinResult.retryableFailure;

      if (!_localMedia.isAvailable) {
        throw StateError('Room connected without a local participant');
      }

      return await _publishInitialMedia();
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
      // Successfully published tracks were removed from the owner above, so
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

  Future<void> leave() {
    final leave = _leaveFuture;
    if (leave != null) return leave;

    late final Future<void> newLeave;
    newLeave = _leaveAndCleanUp().whenComplete(() {
      if (identical(_leaveFuture, newLeave)) {
        _leaveFuture = null;
      }
    });
    _leaveFuture = newLeave;
    return newLeave;
  }

  Future<void> _leaveAndCleanUp() async {
    try {
      await _disconnect();
    } finally {
      try {
        await _cleanUp();
      } finally {
        if (ref.mounted) {
          _dispatch(
            const ConnectionChanged(
              RoomConnectionState.disconnected,
              SessionPhase.disconnected,
            ),
          );
        }
      }
    }
  }

  /// Leaves while the page is unloading, such as when the user closes the
  /// tab. Nothing after the first await runs then, so [leave] would never
  /// reach LiveKit. [Room.disconnect] sends its leave request before its
  /// first await, so the server removes this participant at once instead of
  /// after its connection timeout. Capture stops with the page.
  void leaveOnPageExit() {
    unawaited(_room?.disconnect());
  }

  void _cleanUpInBackground(String message) {
    unawaited(
      _cleanUp().catchError((Object error, StackTrace stackTrace) {
        ErrorHandler.logError(error, stackTrace: stackTrace, message: message);
      }),
    );
  }

  Future<void> _cleanUp() {
    final cleanup = _cleanupFuture;
    if (cleanup != null) return cleanup;

    late final Future<void> newCleanup;
    newCleanup = _performCleanup().whenComplete(() {
      if (identical(_cleanupFuture, newCleanup)) {
        _cleanupFuture = null;
      }
    });
    _cleanupFuture = newCleanup;
    return newCleanup;
  }

  Future<void> _performCleanup() async {
    logger.d('Disposing SessionService and closing connections.');

    _isAdoptingConnectedRoom = false;
    _subscribedRemotePublications.clear();
    _admittedMediaRecipients = null;
    _appliedMediaRecipients = null;
    ++_connectionGeneration;
    _pollPending = false;
    _pendingReconcile = false;

    if (ref.mounted) {
      try {
        await ref.read(sessionInfraControllerProvider.notifier).deactivate();
      } catch (error, stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to deactivate session infrastructure',
        );
      }
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
        await devices.stopDeviceChangeListener();
      } catch (_) {}
    }

    _syncTimer?.cancel();
    _syncTimer = null;
    _statePollTimer?.cancel();
    _statePollTimer = null;
    await disposeConnection();
  }

  Future<SessionJoinResult> activateConnectedRoom({
    required Room room,
    SessionJoinMedia? joinMedia,
    bool Function(String identity)? isAdmitted,
  }) async {
    final retainedJoinMedia = _joinMediaOwner.retain(joinMedia);
    final pendingRoom = _pendingConnectedRoom;
    final hasActiveRoom =
        _leaveFuture == null &&
        (_room != null ||
            state.connectionState == RoomConnectionState.connected ||
            state.connectionState == RoomConnectionState.connecting);
    if (pendingRoom != null || hasActiveRoom) {
      final existingRoom = pendingRoom ?? _room;
      if (retainedJoinMedia.hasOwnedTracks) {
        _detachJoinMediaPreview(joinMedia);
      }
      await retainedJoinMedia.dispose();
      if (identical(existingRoom, room)) return SessionJoinResult.success;
      await _releaseOfferedRoom(room);
      return SessionJoinResult.retryableFailure;
    }

    // The caller transfers this room at invocation, before waiting for a
    // previous connection to finish cleaning up.
    _pendingConnectedRoom = room;
    _dispatch(
      const ConnectionChanged(
        RoomConnectionState.connecting,
        SessionPhase.connecting,
      ),
    );

    try {
      await _waitForPreviousConnectionCleanup();
      if (!identical(_pendingConnectedRoom, room)) {
        return SessionJoinResult.retryableFailure;
      }
      if (!_isRoomConnected(room)) {
        throw StateError('Connected room disconnected before activation');
      }
      _pendingConnectedRoom = null;
      this.room = room;
      _registerRoomEventListeners(room, isAdmitted: isAdmitted);
      if (!await _initializeSessionInfrastructure()) {
        throw StateError(
          'Session controller was disposed during room activation',
        );
      }
      if (!_localMedia.isAvailable) {
        throw StateError('Connected room has no local participant');
      }
      if (!_isRoomConnected(room)) {
        throw StateError('Connected room disconnected during activation');
      }

      _onConnected();
      final result = await _publishInitialMedia();
      if (result != SessionJoinResult.success) {
        await resetAfterFailedJoin();
        return result;
      }
      if (!_isRoomConnected(room)) {
        await resetAfterFailedJoin();
        return SessionJoinResult.retryableFailure;
      }

      _isAdoptingConnectedRoom = true;
      _subscribeToExistingRemotePublications(room);
      return SessionJoinResult.success;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to activate connected session room',
      );
      if (identical(_room, room)) {
        await resetAfterFailedJoin();
      } else {
        _pendingConnectedRoom = null;
        await _releaseOfferedRoom(room);
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
      return SessionJoinResult.retryableFailure;
    } finally {
      if (retainedJoinMedia.hasOwnedTracks) {
        _detachJoinMediaPreview(joinMedia);
      }
      await retainedJoinMedia.dispose();
    }
  }

  bool _isRoomConnected(Room room) =>
      room.connectionState == livekit.ConnectionState.connected;

  Future<void> _releaseOfferedRoom(Room room) async {
    try {
      await room.disconnect();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to disconnect rejected connected session room',
      );
    }
    try {
      await room.dispose();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to dispose rejected connected session room',
      );
    }
  }

  @visibleForTesting
  Future<Room> initializeConnection({
    required RoomOptions roomOptions,
    required String url,
    required String token,
  }) async {
    final room = _room ??= Room(roomOptions: roomOptions);
    _localMedia.attach(room);
    _roomMedia.attach(room);
    await room.prepareConnection(url, token);
    _registerRoomEventListeners(room);
    return room;
  }

  void _registerRoomEventListeners(
    Room room, {
    bool Function(String identity)? isAdmitted,
  }) {
    _listener ??= room.createListener()
      ..on<RoomMetadataChangedEvent>((_) {
        if (ref.mounted) _updateRoomState();
      })
      ..on<RoomConnectedEvent>((_) => _onConnected())
      ..on<RoomReconnectedEvent>((_) {
        _applyMediaSubscriptionPermissions(force: true);
      })
      ..on<RoomDisconnectedEvent>((event) {
        logger.d('Disconnected from session. Reason: ${event.reason}');
        if (event.reason != null) {
          _dispatch(SessionErrorChanged(RoomDisconnectionError(event.reason!)));
        }
        if (_leaveFuture != null) return;

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

        _onDisconnected();
      })
      ..on<DataReceivedEvent>((data) {
        if (ref.mounted) messaging.handleDataReceived(data);
      })
      ..on<ParticipantDisconnectedEvent>(_onParticipantDisconnected)
      ..on<ParticipantConnectedEvent>(
        (event) => _onParticipantConnected(event, isAdmitted: isAdmitted),
      )
      ..on<ParticipantNameUpdatedEvent>((_) => _updateParticipantsList())
      ..on<LocalTrackPublishedEvent>((_) {
        _applyMediaSubscriptionPermissions(force: true);
      })
      ..on<TrackPublishedEvent>((event) {
        _subscribeToRemotePublication(event.publication);
      });
  }

  bool get _isLocalUserKeeper {
    final keeperIdentity = state.roomState.keeper;
    return keeperIdentity.isNotEmpty &&
        room?.localParticipant?.identity == keeperIdentity;
  }

  void _applyMediaSubscriptionPermissions({bool force = false}) {
    final localParticipant = room?.localParticipant;
    if (!ref.mounted || localParticipant == null) return;

    final recipients = <String>{...?_admittedMediaRecipients};
    final keeperIdentity = state.roomState.keeper;
    if (!_isLocalUserKeeper && keeperIdentity.isNotEmpty) {
      recipients.add(keeperIdentity);
    }
    recipients.remove(localParticipant.identity);
    if (!force &&
        _appliedMediaRecipients != null &&
        setEquals(_appliedMediaRecipients, recipients)) {
      return;
    }

    try {
      localParticipant.setTrackSubscriptionPermissions(
        allParticipantsAllowed: false,
        trackPermissions: recipients
            .map((identity) => ParticipantTrackPermission(identity, true, null))
            .toList(growable: false),
      );
      _appliedMediaRecipients = Set.unmodifiable(recipients);
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to update local media subscription permissions',
      );
    }
  }

  void _subscribeToExistingRemotePublications(Room room) {
    room.remoteParticipants.values
        .expand((participant) => participant.getTrackPublications())
        .forEach(_subscribeToRemotePublication);
  }

  void _subscribeToRemotePublication(RemoteTrackPublication publication) {
    if (!_isAdoptingConnectedRoom ||
        !_subscribedRemotePublications.add(publication)) {
      return;
    }
    unawaited(
      publication.subscribe().catchError((Object error, StackTrace stackTrace) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Failed to subscribe to an adopted room track',
        );
      }),
    );
  }

  Future<void> _connect({
    required String url,
    required String token,
    ConnectOptions? connectOptions,
  }) async {
    await _room?.connect(url, token, connectOptions: connectOptions);
  }

  Future<void> _disconnect() async {
    await _disableLocalMediaTracks();
    await _room?.disconnect();
  }

  Future<void> _disableLocalMediaTracks() async {
    try {
      await _localMedia.release();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to release local media while leaving session',
      );
    }
  }

  @visibleForTesting
  Future<void> disposeConnection() async {
    await _messaging?.disposeAdmissionTransport();
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
    _localMedia.attach(null);
    _roomMedia.attach(null);

    await _joinMediaOwner.disposeAll();
  }

  /// Whether the microphone should be on when joining: the user's preference,
  /// limited by the room's turn rules.
  bool shouldEnableMicrophone() {
    if (state.roomState.status == RoomStatus.waitingRoom && !state.hasKeeper) {
      return options.microphoneEnabled;
    }
    if (state.roomState.status == RoomStatus.active) {
      if (state.speakingNow == room?.localParticipant?.identity) {
        return options.microphoneEnabled;
      }
      return false;
    }
    return isCurrentUserKeeper() && options.microphoneEnabled;
  }

  Future<void> _applyJoinMediaState() async {
    final currentRoom = room;
    if (currentRoom == null) return;

    if (!shouldEnableMicrophone()) {
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
  List<ParticipantInfo> sortedParticipants() {
    final participants = <ParticipantInfo>[
      if (room != null) ...[
        ...?room?.remoteParticipants.values.map((p) => p.toInfo()),
        ?room?.localParticipant?.toInfo(),
      ],
    ];

    return participantsSorting(
      originalParticipants: participants,
      talkingOrder: state.roomState.talkingOrder,
      speakingNow: state.speakingNow,
      nextSpeaker: state.roomState.nextSpeaker.value,
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

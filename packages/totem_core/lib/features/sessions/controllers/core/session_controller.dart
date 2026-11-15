import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/controllers/core/join_media_owner.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state_events.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state_reducer.dart';
import 'package:totem_core/features/sessions/controllers/features/session_device_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_infra_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_keeper_controller.dart';
import 'package:totem_core/features/sessions/controllers/features/session_messaging_controller.dart';
import 'package:totem_core/features/sessions/controllers/utils.dart';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';
import 'package:totem_core/features/sessions/media/session_transport_compatibility.dart'
    as compatibility;
import 'package:totem_core/features/sessions/media/session_transport_factory_provider.dart';
import 'package:totem_core/features/sessions/providers/emoji_reactions_provider.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart'
    show sessionScopeProvider;
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';
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
///  * [SessionTransportDisconnectReason], the transport disconnection reason.
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
  SessionRoomState get admissionState => state;
  Future<void>? _admissionCleanup;
  SessionAdmissionService? _admission;
  SessionAdmissionService get admission =>
      _admission ??= SessionAdmissionService(ref, this);
  SessionTransport? _transport;
  SessionTransport? get transport => _transport;
  // B2/C2 compatibility only: this getter never owns the SDK room.
  compatibility.LegacySessionRoom? get room =>
      compatibility.legacyRoom(_transport);
  @visibleForTesting
  set room(compatibility.LegacySessionRoom? value) {
    if (identical(room, value)) return;
    _transport = value == null
        ? null
        : compatibility.wrapLegacyRoom(
            value,
            options.cameraOptions,
            localMedia: localMedia,
            roomMedia: roomMedia,
          );
  }

  late SessionTransportFactory _transportFactory;
  LocalMedia get localMedia => _transportFactory.localMedia;
  RoomMedia get roomMedia => _transportFactory.roomMedia;
  StreamSubscription<SessionTransportEvent>? _listener;
  compatibility.LegacyConnectedRoomOffer? _pendingConnectedRoom;
  Set<String>? _admittedMediaRecipients;
  Set<String>? _appliedMediaRecipients;
  bool? _appliedAllParticipantsAllowed;

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
  static const compatibility.LegacyCameraOptions defaultCameraCaptureOptions =
      compatibility.defaultCameraCaptureOptions;
  static final compatibility.LegacyVideoPublishOptions
  defaultVideoPublishOptions = videoPublishOptionsForPlatform(
    isWeb: kIsWeb,
    isWasm: kIsWasm,
  );
  static compatibility.LegacyVideoPublishOptions
  videoPublishOptionsForPlatform({required bool isWeb, required bool isWasm}) =>
      compatibility.videoPublishOptionsForPlatform(
        isWeb: isWeb,
        isWasm: isWasm,
      );
  static compatibility.LegacyRoomOptions sessionRoomOptions({
    required compatibility.LegacyCameraOptions cameraOptions,
    required bool speakerEnabled,
  }) => compatibility.sessionRoomOptions(
    cameraOptions: cameraOptions,
    speakerEnabled: speakerEnabled,
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
  /// Until this method receives a roster, Keeper media remains available to
  /// avoid a local recovery failure silencing the Session. Other publishers
  /// fail closed while retaining access for the Keeper when known.
  void updateAdmittedMediaRecipients(Set<String> identities) {
    final newlyAdmitted = identities.difference(_admittedMediaRecipients ?? {});
    _admittedMediaRecipients = Set.unmodifiable(identities);
    _applyMediaSubscriptionPermissions();

    final remoteParticipants = _transport?.participants
        .where((p) => !p.isLocal)
        .map((p) => p.identity)
        .toSet();
    if (remoteParticipants != null &&
        newlyAdmitted.any(remoteParticipants.contains)) {
      _attemptReconcile();
    }
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
    _transportFactory = ref.watch(sessionTransportFactoryProvider(options));
    ref
      ..listen(sessionDeviceControllerProvider(this), (_, _) {})
      ..listen(sessionInfraControllerProvider, (_, _) {})
      ..listen(sessionKeeperControllerProvider(this), (_, _) {})
      ..listen(sessionMessagingControllerProvider(this), (_, _) {});
    // The device controls follow the session's state until tracks publish.
    listenSelf((_, _) {
      devices.syncWithSession();
      admission.sync();
    });

    ref
        .watch(sessionProvider(options.sessionSlug))
        .whenData((event) => session = event);

    ref.onDispose(() {
      _admissionCleanup = _admission?.close();
      _admission = null;
      final pendingRoom = _pendingConnectedRoom;
      _pendingConnectedRoom = null;
      if (pendingRoom != null && !identical(pendingRoom.room, room)) {
        unawaited(pendingRoom.dispose());
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
    if (_transport?.localIdentity == null) {
      logger.i('Local participant is null on connected.');
      return;
    }

    logger.i(
      'Connected to LiveKit room as '
      '"${_transport?.localIdentity}".',
    );

    _updateRoomState();
    _applyMediaSubscriptionPermissions();

    unawaited(_applyJoinMediaState());
    // A transferred pre-join track is already rendering in the loading screen.
    // Keep that renderer mounted until LiveKit has accepted the track below;
    // otherwise the room replaces it with an avatar-only tile before the
    // publication becomes available.
    final hasPendingPreJoinMedia =
        compatibility.cameraTrack(_joinMediaOwner) != null ||
        compatibility.microphoneTrack(_joinMediaOwner) != null;
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

  void _onError(SessionTransportFailure error) {
    _dispatch(SessionErrorChanged(compatibility.legacyCompatibleError(error)));
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
        metadata: _transport?.metadata,
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

  void _onParticipantDisconnected(ParticipantInfo participant) {
    _attemptReconcile();
    _updateParticipantsList();
  }

  void _onParticipantConnected(ParticipantInfo participant) {
    final identity = participant.identity;
    if (_isMediaRecipientOrKeeper(identity)) _attemptReconcile();
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

  Future<SessionJoinResult> _publishInitialMedia(
    SessionJoinMedia? joinMedia,
  ) async {
    final initialCameraTrack = compatibility.cameraTrack(_joinMediaOwner);
    final initialMicrophoneTrack = compatibility.microphoneTrack(
      _joinMediaOwner,
    );

    try {
      if (!_canPublishInitialMedia) return SessionJoinResult.retryableFailure;
      if (options.cameraEnabled) {
        final published = await compatibility.publishCamera(
          _transport!,
          initialCameraTrack,
          defaultVideoPublishOptions,
        );
        if (!ref.mounted) return SessionJoinResult.retryableFailure;
        if (published) _joinMediaOwner.releaseToRoom(initialCameraTrack);
      } else if (initialCameraTrack != null) {
        _detachJoinMediaPreview(joinMedia);
        await _joinMediaOwner.disposeTrack(initialCameraTrack);
      }

      if (!_canPublishInitialMedia) return SessionJoinResult.retryableFailure;
      if (initialMicrophoneTrack != null || options.microphoneEnabled) {
        final published = await compatibility.publishMicrophone(
          _transport!,
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

      await _transport!.connect(AppConfig.instance.liveKitUrl, options.token);
      if (!ref.mounted) return SessionJoinResult.retryableFailure;

      if (!localMedia.isAvailable) {
        throw StateError('Room connected without a local participant');
      }

      return await _publishInitialMedia(joinMedia);
    } on SessionTransportFailure catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Session transport connection failed',
      );
      if (error.connectionFailure ==
              SessionTransportConnectionFailure.timeout ||
          error.kind == SessionTransportFailureKind.mediaConnection) {
        return SessionJoinResult.retryableFailure;
      }
      if (error.kind == SessionTransportFailureKind.unexpected) {
        return SessionJoinResult.retryableFailure;
      }
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
  /// reach the transport. Its disconnect operation sends the leave request before its
  /// first await, so the server removes this participant at once instead of
  /// after its connection timeout. Capture stops with the page.
  void leaveOnPageExit() {
    unawaited(_transport?.disconnect());
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

    _admittedMediaRecipients = null;
    _appliedMediaRecipients = null;
    _appliedAllParticipantsAllowed = null;
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
    required compatibility.LegacySessionRoom room,
    SessionJoinMedia? joinMedia,
  }) async {
    final retainedJoinMedia = _joinMediaOwner.retain(joinMedia);
    final pendingRoom = _pendingConnectedRoom;
    final hasActiveRoom =
        _leaveFuture == null &&
        (_transport != null ||
            state.connectionState == RoomConnectionState.connected ||
            state.connectionState == RoomConnectionState.connecting);
    if (pendingRoom != null || hasActiveRoom) {
      final existingRoom = pendingRoom?.room ?? this.room;
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
    _pendingConnectedRoom = compatibility.LegacyConnectedRoomOffer(room);
    _dispatch(
      const ConnectionChanged(
        RoomConnectionState.connecting,
        SessionPhase.connecting,
      ),
    );

    try {
      await _waitForPreviousConnectionCleanup();
      if (!identical(_pendingConnectedRoom?.room, room)) {
        return SessionJoinResult.retryableFailure;
      }
      if (!_isRoomConnected(room)) {
        throw StateError('Connected room disconnected before activation');
      }
      _transport = _pendingConnectedRoom!.adopt(
        localMedia: localMedia,
        roomMedia: roomMedia,
        cameraOptions: options.cameraOptions,
      );
      _pendingConnectedRoom = null;
      _registerTransportEvents(_transport!);
      if (!await _initializeSessionInfrastructure()) {
        throw StateError(
          'Session controller was disposed during room activation',
        );
      }
      if (!localMedia.isAvailable) {
        throw StateError('Connected room has no local participant');
      }
      if (!_isRoomConnected(room)) {
        throw StateError('Connected room disconnected during activation');
      }

      _onConnected();
      final result = await _publishInitialMedia(joinMedia);
      if (result != SessionJoinResult.success) return result;
      if (!_isRoomConnected(room)) return SessionJoinResult.retryableFailure;

      unawaited(_subscribeRemoteMedia());
      return SessionJoinResult.success;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to activate connected session room',
      );
      if (!identical(this.room, room)) {
        _pendingConnectedRoom = null;
        await _releaseOfferedRoom(room);
      }
      return SessionJoinResult.retryableFailure;
    } finally {
      if (retainedJoinMedia.hasOwnedTracks) {
        _detachJoinMediaPreview(joinMedia);
      }
      await retainedJoinMedia.dispose();
    }
  }

  bool _isRoomConnected(compatibility.LegacySessionRoom room) =>
      compatibility.legacyRoomConnected(room);
  Future<void> _releaseOfferedRoom(compatibility.LegacySessionRoom room) =>
      compatibility.releaseRejectedLegacyRoom(room);

  @visibleForTesting
  Future<SessionTransport> initializeConnection({
    required compatibility.LegacyRoomOptions roomOptions,
    required String url,
    required String token,
  }) async {
    final transport = _transport ??= _transportFactory.create();
    _registerTransportEvents(transport);
    await transport.prepare(url, token);
    return transport;
  }

  void _registerTransportEvents(SessionTransport transport) {
    _listener ??= transport.events.listen(
      (event) {
        if (!ref.mounted || !identical(_transport, transport)) return;
        switch (event) {
          case TransportMetadataChanged():
            _updateRoomState();
          case TransportConnectionChanged(
            :final state,
            :final reason,
            :final reconnected,
          ):
            switch (state) {
              case SessionTransportConnectionState.connected:
                if (!reconnected) {
                  _onConnected();
                } else {
                  _applyMediaSubscriptionPermissions(force: true);
                }
              case SessionTransportConnectionState.disconnected:
                if (reason != null) {
                  _dispatch(
                    SessionErrorChanged(
                      compatibility.legacyDisconnectError(reason),
                    ),
                  );
                }
                if (_leaveFuture != null) return;
                if (this.state.connectionState ==
                        RoomConnectionState.connecting &&
                    {
                      SessionTransportDisconnectReason.joinFailure,
                      SessionTransportDisconnectReason.clientInitiated,
                      SessionTransportDisconnectReason
                          .signalingConnectionFailure,
                    }.contains(reason)) {
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
              default:
                break;
            }
          case TransportPacketReceived(:final packet):
            compatibility.deliverLegacyPacket(messaging, packet, transport);
          case TransportParticipantChanged(:final participant, :final present):
            if (present) {
              _onParticipantConnected(participant);
            } else {
              _onParticipantDisconnected(participant);
            }
          case TransportParticipantUpdated():
            _updateParticipantsList();
          case TransportMediaChanged():
            _applyMediaSubscriptionPermissions(force: true);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!ref.mounted || !identical(_transport, transport)) return;
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Session transport event failed',
        );
      },
    );
  }

  Future<void> _subscribeRemoteMedia() async {
    try {
      await _transport?.subscribeToExistingMedia();
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Could not subscribe to remote session media',
      );
    }
  }

  bool get _isLocalUserKeeper {
    final keeperIdentity = state.roomState.keeper;
    return keeperIdentity.isNotEmpty &&
        _transport?.localIdentity == keeperIdentity;
  }

  void _applyMediaSubscriptionPermissions({bool force = false}) {
    final localIdentity = _transport?.localIdentity;
    if (!ref.mounted || localIdentity == null) return;

    final isKeeper = _isLocalUserKeeper;
    final allParticipantsAllowed = isKeeper && _admittedMediaRecipients == null;
    final recipients = <String>{...?_admittedMediaRecipients};
    final keeperIdentity = state.roomState.keeper;
    if (!isKeeper && keeperIdentity.isNotEmpty) {
      recipients.add(keeperIdentity);
    }
    recipients.remove(localIdentity);
    if (!force &&
        _appliedAllParticipantsAllowed == allParticipantsAllowed &&
        _appliedMediaRecipients != null &&
        setEquals(_appliedMediaRecipients, recipients)) {
      return;
    }

    try {
      _transport!.setSubscriptionPermissions(
        allowEveryone: allParticipantsAllowed,
        recipients: recipients,
      );
      _appliedMediaRecipients = Set.unmodifiable(recipients);
      _appliedAllParticipantsAllowed = allParticipantsAllowed;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Failed to update local media subscription permissions',
      );
    }
  }

  Future<void> _disconnect() async {
    await _disableLocalMediaTracks();
    await _transport?.disconnect();
  }

  Future<void> _disableLocalMediaTracks() async {
    try {
      await localMedia.release();
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
    await _admissionCleanup;
    await _admission?.disconnect();
    await _messaging?.disposeAdmissionTransport();
    await _disableLocalMediaTracks();

    await _listener?.cancel();
    _listener = null;
    final transport = _transport;
    _transport = null;
    await transport?.dispose();

    await _joinMediaOwner.disposeAll();
  }

  /// Whether the microphone should be on when joining: the user's preference,
  /// limited by the room's turn rules.
  bool shouldEnableMicrophone() {
    if (state.roomState.status == RoomStatus.waitingRoom && !state.hasKeeper) {
      return options.microphoneEnabled;
    }
    if (state.roomState.status == RoomStatus.active) {
      if (state.speakingNow == _transport?.localIdentity) {
        return options.microphoneEnabled;
      }
      return false;
    }
    return isCurrentUserKeeper() && options.microphoneEnabled;
  }

  Future<void> _applyJoinMediaState() async {
    if (_transport == null) return;

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
    final participants = _transport?.participants ?? const <ParticipantInfo>[];

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

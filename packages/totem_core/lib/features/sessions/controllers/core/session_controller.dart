import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/auth/controllers/auth_controller.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/config/app_config.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/core/repositories/space_repository.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/controllers/core/join_media_owner.dart';
import 'package:totem_core/features/sessions/controllers/core/session_runtime.dart';
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
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/features/sessions/services/session_chat_service.dart';
import 'package:totem_core/features/sessions/services/session_packet_router.dart';
import 'package:totem_core/features/sessions/services/session_reaction_buffer.dart';
import 'package:totem_core/features/sessions/services/session_reactions_service.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';
import 'package:totem_core/shared/logger.dart';

export 'package:totem_core/features/sessions/controllers/core/session_runtime.dart'
    show SessionJoinResult;
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

@riverpod
class SessionController extends _$SessionController {
  SessionRoomState get admissionState => state;
  SessionRuntime? _runtime;
  SessionRuntime get runtime =>
      _runtime ?? (throw StateError('Session runtime is not initialized'));
  SessionAdmissionService get admission =>
      runtime.admission ??= SessionAdmissionService(ref, this);
  SessionTransport? get _transport => _runtime?.transport;
  set _transport(SessionTransport? value) {
    if (value != null) runtime.installCompatibilityTransport(value);
  }

  SessionTransport? get transport => _transport;
  SessionAttempt? get activeAttempt => _runtime?.activeAttempt;
  // B2/C2 compatibility only: this getter never owns the SDK room.
  compatibility.LegacySessionRoom? get room =>
      compatibility.legacyRoom(_transport);
  @visibleForTesting
  set room(compatibility.LegacySessionRoom? value) {
    if (identical(room, value)) return;
    if (value == null) return;
    _transport = compatibility.wrapLegacyRoom(
      value,
      options.cameraOptions,
      localMedia: localMedia,
      roomMedia: roomMedia,
    );
  }

  late SessionTransportFactory _transportFactory;
  LocalMedia get localMedia => _transportFactory.localMedia;
  RoomMedia get roomMedia => _transportFactory.roomMedia;
  Set<String>? _admittedMediaRecipients;
  Set<String>? _appliedMediaRecipients;
  bool? _appliedAllParticipantsAllowed;

  JoinMediaOwner get _joinMediaOwner => runtime.media;

  /// The sync timer periodically checks for changes in the room state
  /// and participants list, to keep the UI up to date.
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

  late SessionChatService _chat;
  SessionChatService get chat => _chat;
  late SessionReactionsService _reactions;
  SessionReactionsService get reactions => _reactions;
  SessionReactionBuffer? _reactionBuffer;
  SessionReactionBuffer? get reactionBuffer => _reactionBuffer;
  late SessionPacketRouter _packets;
  void addSessionChatMessage(SessionChatMessage message) => chat.add(message);

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

  Future<void> disconnectFromRoom() => leave();

  void _dispatch(SessionEvent event) {
    state = _stateReducer.reduceState(state, event);
  }

  @override
  SessionRoomState build(SessionOptions options) {
    _transportFactory = ref.read(sessionTransportFactoryProvider(options));
    _chat = SessionChatService(
      transport: () => transport,
      keeperIdentity: () => state.roomState.keeper,
      isKeeper: isCurrentUserKeeper,
    );
    final ownedReactionBuffer = _reactionBuffer = SessionReactionBuffer(
      now: ref.read(emojiReactionClockProvider),
    );
    _reactions = SessionReactionsService(
      transport: () => transport,
      hasKeeper: () => state.hasKeeper,
      emit: ownedReactionBuffer.emitIncomingReaction,
      onError: (error, stack) => ErrorHandler.logError(
        error,
        stackTrace: stack,
        message: 'Session reaction failed',
      ),
    );
    final ownedChat = chat;
    final ownedReactions = reactions;
    ref.onDispose(() {
      ownedChat.dispose();
      ownedReactions.dispose();
      ownedReactionBuffer.dispose();
    });
    _packets = SessionPacketRouter(
      chat: chat.receive,
      reaction: reactions.receive,
      removal: (packet) => keeper.moderation.receive(packet),
      admission: (event) => admission.handleTransportEvent(event),
    );
    final infrastructure = ref.read(sessionInfraControllerProvider.notifier);
    // A provider rebuild must release the old media facades before reusing them.
    final previousEntryCleanup = _runtime?.dispose().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Previous session runtime cleanup failed before rebuild',
      );
    });
    late final SessionRuntime ownedRuntime;
    _runtime = ownedRuntime = SessionRuntime(
      factory: _transportFactory,
      previousEntryCleanup: previousEntryCleanup,
      onEvent: _onTransportEvent,
      onCancel: () {
        if (!ref.mounted || !identical(_runtime, ownedRuntime)) return;
        keeper.disposePresenceTracking();
        devices.cancelPendingOperations();
        chat.cancelPending();
        reactions.cancelPending();
      },
      onCleanup: () => _performCleanup(ownedRuntime),
      activateInfrastructure: (owner) =>
          infrastructure.activate(event: session, owner: owner),
      deactivateInfrastructure: (owner) =>
          infrastructure.deactivate(owner: owner),
      onError: (error, stackTrace) => ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Session runtime operation failed',
      ),
      onJoined: () {
        if (!ref.mounted || !identical(runtime, ownedRuntime)) return;
        _dispatch(
          const ConnectionChanged(
            RoomConnectionState.connected,
            SessionPhase.connected,
          ),
        );
        unawaited(_scheduleServerStatePoll());
      },
      retainEntry: () {
        final link = ref.keepAlive();
        return link.close;
      },
    );
    ref
      ..listen(sessionDeviceControllerProvider(this), (_, _) {})
      ..listen(sessionInfraControllerProvider, (_, _) {})
      ..listen(sessionKeeperControllerProvider(this), (_, _) {})
      ..listen(sessionMessagingControllerProvider(this), (_, _) {});
    // The device controls follow the session's state until tracks publish.
    SessionTransport? observedAdmissionTransport;
    (RoomConnectionState, RoomStatus, String, bool?, String?, bool)?
    admissionInputs;
    listenSelf((_, next) {
      devices.syncWithSession();
      final connection = transport;
      final inputs = (
        next.connection.state,
        next.roomState.status,
        next.roomState.keeper,
        session?.ended,
        connection?.localIdentity,
        runtime.acceptsEvents,
      );
      if (inputs == admissionInputs &&
          identical(connection, observedAdmissionTransport)) {
        return;
      }
      admissionInputs = inputs;
      observedAdmissionTransport = connection;
      if (runtime.acceptsEvents) {
        admission.sync();
      } else {
        runtime.admission?.sync();
      }
    });

    ref.listen(sessionProvider(options.sessionSlug), (_, next) {
      next.whenData((event) => session = event);
    }, fireImmediately: true);

    ref.onDispose(() {
      unawaited(
        ownedRuntime.dispose().catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          ErrorHandler.logError(
            error,
            stackTrace: stackTrace,
            message: 'Failed to dispose session runtime',
          );
        }),
      );
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

    final speakerPref = options.speakerEnabled;
    devices.resetSpeakerRoutingDefaults(speakerPref);
    runtime.scheduleDeviceSetup(const Duration(milliseconds: 500), () {
      if (ref.mounted) unawaited(devices.setupDeviceChangeListener());
    });

    _updateParticipantsList();
  }

  void _onDisconnected() {
    if (runtime.isLeaving) return;

    _dispatch(
      const ConnectionChanged(
        RoomConnectionState.disconnected,
        SessionPhase.disconnected,
      ),
    );
    _cleanUpInBackground('Failed to clean up disconnected session');
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
      final previous = state;
      _dispatch(RoomStateChanged(nextState, observedAt: DateTime.now()));
      if (identical(state, previous)) return false;
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
    required SessionRuntime owner,
    bool attemptReconcile = false,
  }) async {
    if (!ref.mounted ||
        !identical(_runtime, owner) ||
        connectionGeneration != owner.generation) {
      return;
    }
    if (state.connectionState != RoomConnectionState.connected) return;

    try {
      final roomState = await ref.read(
        roomStateProvider(
          options.sessionSlug,
          attemptReconcile: attemptReconcile,
        ).future,
      );
      if (!ref.mounted ||
          !identical(_runtime, owner) ||
          connectionGeneration != owner.generation) {
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
      if (!ref.mounted ||
          !identical(_runtime, owner) ||
          connectionGeneration != owner.generation) {
        return;
      }
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

  Future<void> _scheduleServerStatePoll({bool attemptReconcile = false}) =>
      runtime.polling.request(reconcile: attemptReconcile);

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

  Future<bool> _initializeSessionInfrastructure() async {
    final owner = runtime;
    final generation = owner.generation;
    await owner.activate();
    if (!ref.mounted ||
        !identical(runtime, owner) ||
        generation != owner.generation ||
        !owner.acceptsEvents) {
      return false;
    }

    runtime.polling.start(
      syncInterval: syncTimerDuration,
      pollInterval: _statePollInterval,
      synchronize: () {
        if (!ref.mounted) return;
        _updateRoomState();
        _updateParticipantsList();
      },
      fetch: (reconcile) => _pollServerState(
        connectionGeneration: generation,
        owner: owner,
        attemptReconcile: reconcile,
      ),
    );
    return true;
  }

  Future<SessionJoinResult> _publishInitialMedia(
    SessionJoinMedia? joinMedia,
    SessionAttempt attempt,
  ) async {
    final connection = _transport!;
    final initialCameraTrack = compatibility.cameraTrack(_joinMediaOwner);
    final initialMicrophoneTrack = compatibility.microphoneTrack(
      _joinMediaOwner,
    );

    try {
      if (!attempt.isCurrent || !_canPublishInitialMedia) {
        return SessionJoinResult.retryableFailure;
      }
      if (options.cameraEnabled) {
        final accepted = await _joinMediaOwner.publish(
          initialCameraTrack,
          () => compatibility.publishCamera(
            connection,
            initialCameraTrack,
            defaultVideoPublishOptions,
          ),
        );
        if (!accepted || !ref.mounted || !attempt.isCurrent) {
          return SessionJoinResult.retryableFailure;
        }
      } else if (initialCameraTrack != null) {
        await _joinMediaOwner.disposeTrack(initialCameraTrack);
      }

      if (!attempt.isCurrent || !_canPublishInitialMedia) {
        return SessionJoinResult.retryableFailure;
      }
      if (initialMicrophoneTrack != null || options.microphoneEnabled) {
        final accepted = await _joinMediaOwner.publish(
          initialMicrophoneTrack,
          () => compatibility.publishMicrophone(
            connection,
            initialMicrophoneTrack,
            muted: !shouldEnableMicrophone(),
          ),
        );
        if (!accepted || !ref.mounted || !attempt.isCurrent) {
          return SessionJoinResult.retryableFailure;
        }
      }

      if (!attempt.isCurrent || !_canPublishInitialMedia) {
        return SessionJoinResult.retryableFailure;
      }
      await _applyJoinMediaState();
      if (!ref.mounted || !attempt.isCurrent) {
        return SessionJoinResult.retryableFailure;
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

  Future<SessionJoinResult> join({SessionJoinMedia? joinMedia}) => runtime.join(
    media: joinMedia,
    operation: (attempt) => _join(attempt, joinMedia),
  );

  Future<SessionJoinResult> _join(
    SessionAttempt attempt,
    SessionJoinMedia? joinMedia,
  ) async {
    _dispatch(
      const ConnectionChanged(
        RoomConnectionState.connecting,
        SessionPhase.connecting,
      ),
    );

    try {
      await initializeConnection(
        attempt: attempt,
        roomOptions: sessionRoomOptions(
          cameraOptions: options.cameraOptions,
          speakerEnabled: options.speakerEnabled,
        ),
        url: AppConfig.instance.liveKitUrl,
        token: options.token,
      );
      if (!ref.mounted ||
          !attempt.isCurrent ||
          !await _initializeSessionInfrastructure()) {
        return SessionJoinResult.retryableFailure;
      }

      attempt.requireCurrent();
      await _transport!.connect(AppConfig.instance.liveKitUrl, options.token);
      if (!ref.mounted || !attempt.isCurrent) {
        return SessionJoinResult.retryableFailure;
      }

      if (!localMedia.isAvailable) {
        throw StateError('Room connected without a local participant');
      }

      return await _publishInitialMedia(joinMedia, attempt);
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
      if (attempt.isCurrent) _onError(error);
      return SessionJoinResult.fatalFailure;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Unexpected error occurred',
      );
      return SessionJoinResult.retryableFailure;
    }
  }

  /// Tears down a failed connection attempt while keeping the controller
  /// available for another join from the pre-join screen.
  Future<void> resetAfterFailedJoin() async {
    final owner = runtime;
    final resetting = owner.reset();
    final cancelledGeneration = owner.generation;
    await resetting;
    if (ref.mounted &&
        identical(_runtime, owner) &&
        owner.generation == cancelledGeneration &&
        !owner.isJoining) {
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
    final owner = runtime;
    if (owner.leaving case final pending?) return pending;
    final entry = owner.entryIdentity;
    final leaving = owner.leave(disconnect: _disconnect);
    unawaited(
      leaving
          .whenComplete(() {
            if (ref.mounted &&
                identical(runtime, owner) &&
                identical(owner.entryIdentity, entry) &&
                !owner.isJoining) {
              _dispatch(
                const ConnectionChanged(
                  RoomConnectionState.disconnected,
                  SessionPhase.disconnected,
                ),
              );
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            ErrorHandler.logError(
              error,
              stackTrace: stackTrace,
              message: 'Failed to leave session',
            );
          }),
    );
    return leaving;
  }

  void leaveOnPageExit() => runtime.leaveOnPageExit();
  void _cleanUpInBackground(String message) {
    unawaited(
      runtime.cleanup().catchError((Object error, StackTrace stackTrace) {
        ErrorHandler.logError(error, stackTrace: stackTrace, message: message);
      }),
    );
  }

  Future<void> _performCleanup(SessionRuntime owner) async {
    if (!identical(runtime, owner)) return;
    logger.d('Disposing SessionService and closing connections.');

    _admittedMediaRecipients = null;
    _appliedMediaRecipients = null;
    _appliedAllParticipantsAllowed = null;

    if (ref.mounted && identical(runtime, owner)) {
      try {
        reactionBuffer?.clear();
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
        keeper.disposePresenceTracking();
      } catch (_) {}
      try {
        await devices.stopDeviceChangeListener();
      } catch (_) {}
    }
  }

  Future<SessionJoinResult> activateConnectedRoom({
    required compatibility.LegacySessionRoom room,
    SessionJoinMedia? joinMedia,
  }) {
    if (identical(this.room, room) && runtime.isJoining) {
      return join(joinMedia: joinMedia);
    }
    if (identical(this.room, room) &&
        runtime.phase == SessionRuntimePhase.connected) {
      return join(joinMedia: joinMedia);
    }
    // The offer checks connectivity before ownership can be accepted.
    try {
      final lease = compatibility.offerConnectedRoom(
        room,
        localMedia: localMedia,
        roomMedia: roomMedia,
        cameraOptions: options.cameraOptions,
      );
      return adoptConnectedSession(lease, joinMedia: joinMedia);
    } catch (error, stack) {
      return () async {
        await compatibility.releaseRejectedLegacyRoom(room);
        await runtime.media.retain(joinMedia).dispose();
        ErrorHandler.logError(
          error,
          stackTrace: stack,
          message: 'Could not offer connected session',
        );
        return SessionJoinResult.retryableFailure;
      }();
    }
  }

  Future<SessionJoinResult> adoptConnectedSession(
    ConnectedSessionLease lease, {
    SessionJoinMedia? joinMedia,
  }) => runtime.join(
    media: joinMedia,
    offer: lease,
    operation: (attempt) async {
      _dispatch(
        const ConnectionChanged(
          RoomConnectionState.connecting,
          SessionPhase.connecting,
        ),
      );
      if (!await _initializeSessionInfrastructure() || !attempt.isCurrent) {
        return SessionJoinResult.retryableFailure;
      }
      if (_transport?.connectionState !=
              SessionTransportConnectionState.connected ||
          !localMedia.isAvailable) {
        return SessionJoinResult.retryableFailure;
      }
      _onConnected();
      final result = await _publishInitialMedia(joinMedia, attempt);
      if (!attempt.isCurrent ||
          _transport?.connectionState !=
              SessionTransportConnectionState.connected) {
        return SessionJoinResult.retryableFailure;
      }
      if (result == SessionJoinResult.success) {
        unawaited(_subscribeRemoteMedia());
      }
      return result;
    },
  );

  @visibleForTesting
  Future<SessionTransport> initializeConnection({
    required compatibility.LegacyRoomOptions roomOptions,
    required String url,
    required String token,
    SessionAttempt? attempt,
  }) async {
    if (attempt != null) return await runtime.prepare(attempt, url, token);
    _transport ??= _transportFactory.create();
    runtime.observeCompatibilityTransport();
    await _transport!.prepare(url, token);
    return _transport!;
  }

  void _onTransportEvent(SessionTransportEvent event) {
    if (!ref.mounted) return;
    _packets.handle(event);
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
            if (runtime.isLeaving) return;
            if (this.state.connectionState == RoomConnectionState.connecting &&
                {
                  null,
                  SessionTransportDisconnectReason.joinFailure,
                  SessionTransportDisconnectReason.clientInitiated,
                  SessionTransportDisconnectReason.signalingConnectionFailure,
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
      case TransportPacketReceived():
        break;
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
  Future<void> disposeConnection() => runtime.cleanup();

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

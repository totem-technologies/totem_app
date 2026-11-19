import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/features/sessions/media/livekit_local_media.dart';
import 'package:totem_core/features/sessions/media/livekit_room_media.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

// Operations are serialized per SDK publication, including revocation cleanup.
// The transport's strong cache contains only current, authorized publications.
class _RemoteSubscription {
  _RemoteSubscription(this.participant);
  sdk.RemoteParticipant participant;
  Future<void>? operation;
  bool dirty = false;
  bool requested = false;
  bool mayBeSubscribed = false;
  int permissionRevision = 0;
  String? blockedPath;
}

class LiveKitSessionTransportFactory implements SessionTransportFactory {
  LiveKitSessionTransportFactory({this.roomOptions = const sdk.RoomOptions()})
    : localMedia = LiveKitLocalMedia(
        cameraCaptureOptions: roomOptions.defaultCameraCaptureOptions,
      );
  @override
  final LiveKitLocalMedia localMedia;
  @override
  final LiveKitRoomMedia roomMedia = LiveKitRoomMedia();
  final sdk.RoomOptions roomOptions;
  @override
  SessionTransport create() => LiveKitSessionTransport(
    room: sdk.Room(
      roomOptions: LiveKitLocalMedia.applyCapturePolicy(roomOptions),
    ),
    cameraOptions: roomOptions.defaultCameraCaptureOptions,
    localMedia: localMedia,
    roomMedia: roomMedia,
  );
}

/// The SDK room never escapes through the SessionTransport contract.
class LiveKitSessionTransport implements SessionTransport {
  LiveKitSessionTransport({
    required sdk.Room room,
    required sdk.CameraCaptureOptions cameraOptions,
    LiveKitLocalMedia? localMedia,
    LiveKitRoomMedia? roomMedia,
  }) : _room = room,
       localMedia =
           localMedia ?? LiveKitLocalMedia(cameraCaptureOptions: cameraOptions),
       roomMedia = roomMedia ?? LiveKitRoomMedia() {
    this.localMedia.attach(room);
    this.roomMedia.attach(room);
    _mediaConnection = connectionState;
    _listener = room.createListener()
      ..on<sdk.RoomConnectedEvent>(
        (_) => _connection(SessionTransportConnectionState.connected),
      )
      ..on<sdk.RoomReconnectingEvent>(
        (_) => _connection(SessionTransportConnectionState.reconnecting),
      )
      ..on<sdk.RoomResumingEvent>(
        (_) => _connection(SessionTransportConnectionState.reconnecting),
      )
      ..on<sdk.RoomReconnectedEvent>((_) {
        _connection(
          SessionTransportConnectionState.connected,
          reconnected: true,
        );
      })
      ..on<sdk.RoomDisconnectedEvent>((event) {
        _subscribeExisting = false;
        _connection(
          SessionTransportConnectionState.disconnected,
          reason: event.reason?.name,
        );
      })
      ..on<sdk.RoomMetadataChangedEvent>(
        (event) => _emit(TransportMetadataChanged(event.metadata)),
      )
      ..on<sdk.ParticipantConnectedEvent>((event) {
        _departedParticipants[event.participant] = false;
        _participant(event.participant, true);
        if (_subscribeExisting) {
          _subscribeInBackground(subscribeToExistingMedia());
        }
      })
      ..on<sdk.ParticipantDisconnectedEvent>((event) {
        _departedParticipants[event.participant] = true;
        _pruneSubscriptions();
        _participant(event.participant, false);
      })
      ..on<sdk.ParticipantNameUpdatedEvent>(
        (event) => _emit(
          TransportParticipantUpdated(
            event.participant.toInfo(),
            metadata: event.participant.metadata,
          ),
        ),
      )
      ..on<sdk.ParticipantMetadataUpdatedEvent>(
        (event) => _emit(
          TransportParticipantUpdated(
            event.participant.toInfo(),
            metadata: event.participant.metadata,
          ),
        ),
      )
      ..on<sdk.DataReceivedEvent>((event) {
        if (_disposed) return;
        final packet = SessionTransportPacket(
          bytes: event.data,
          topic: event.topic ?? '',
          sender: event.participant?.toInfo(),
        );
        _emit(TransportPacketReceived(packet));
      })
      ..on<sdk.LocalTrackPublishedEvent>(
        (_) => _emit(const TransportMediaChanged()),
      )
      ..on<sdk.TrackPublishedEvent>((event) {
        _removedPublications[event.publication] = false;
        _emit(const TransportMediaChanged());
        if (_subscribeExisting) {
          _subscribeInBackground(
            _subscribe(event.participant, event.publication),
          );
        }
      })
      ..on<sdk.TrackUnpublishedEvent>((event) {
        _removedPublications[event.publication] = true;
        _pruneSubscriptions();
        _emit(const TransportMediaChanged());
      })
      ..on<sdk.TrackSubscriptionPermissionChangedEvent>((event) {
        final participant = event.participant;
        final publication = event.publication;
        if (participant is! sdk.RemoteParticipant ||
            !identical(
              _room.remoteParticipants[participant.identity],
              participant,
            ) ||
            !participant.getTrackPublications().any(
              (p) => identical(p, publication),
            )) {
          return;
        }
        if (event.state == sdk.TrackSubscriptionState.notAllowed) {
          final pending = _subscriptionOperations[publication];
          if (pending != null) {
            pending.permissionRevision++;
            pending.requested = false;
          }
        }
        if (_subscribeExisting ||
            _subscriptionOperations[publication] != null) {
          _subscribeInBackground(_subscribe(participant, publication));
        }
      })
      ..on<sdk.TrackSubscriptionExceptionEvent>((event) {
        final participant = event.participant;
        if (participant == null || event.sid == null) return;
        for (final publication in participant.getTrackPublications()) {
          if (publication.sid != event.sid ||
              !_currentPublication(participant, publication)) {
            continue;
          }
          final state = _subscriptionState(participant, publication)
            ..requested = false;
          _scheduleSubscriptionRetry(publication, state);
        }
      })
      ..on<sdk.TrackSubscribedEvent>((event) {
        _subscriptionState(
          event.participant,
          event.publication,
        ).mayBeSubscribed = true;
        _forgetSubscriptionRetry(event.publication);
        _subscribeInBackground(
          _subscribe(event.participant, event.publication),
        );
      })
      ..on<sdk.TrackUnsubscribedEvent>((event) {
        final participant = event.participant;
        final publication = event.publication;
        if (!_currentPublication(participant, publication) ||
            publication.subscribed) {
          return;
        }
        final state = _subscriptionOperations[publication];
        if (state != null) {
          state
            ..requested = false
            ..mayBeSubscribed = false;
        }
        if (_subscribeExisting || state != null) {
          _subscribeInBackground(_subscribe(participant, publication));
        }
      });
  }
  final sdk.Room _room;

  /// Infrastructure compatibility access only; remove with B2/C2 consumers.
  sdk.Room get legacyRoomForB2AndC2 => _room;
  late final sdk.EventsListener<sdk.RoomEvent> _listener;
  final _events = StreamController<SessionTransportEvent>.broadcast(sync: true);
  final Map<sdk.RemoteTrackPublication, _RemoteSubscription> _subscriptions =
      Map.identity();
  // Weak keys let removed publications go once SDK/in-flight work releases them.
  final _subscriptionOperations = Expando<_RemoteSubscription>();
  final Map<sdk.RemoteTrackPublication, _RemoteSubscription> _pendingCleanup =
      Map.identity();
  final Map<sdk.RemoteTrackPublication, _RemoteSubscription>
  _failedSubscriptions = Map.identity();
  Timer? _cleanupRetry;
  Timer? _subscriptionRetry;
  var _cleanupRetryAttempt = 0;
  var _subscriptionRetryAttempt = 0;
  final _departedParticipants = Expando<bool>();
  final _removedPublications = Expando<bool>();
  // Replacement SDK objects can address the same server-side track SID. Keep
  // their cleanup and new subscriptions in the same ordered lane.
  final _subscriptionLanes = <(String, String), Future<void>>{};
  late SessionTransportConnectionState _mediaConnection;
  int _mediaGeneration = 0;
  final _authorization = <String, Object>{};
  Set<String> _incomingMediaParticipants = const {};
  bool _subscribeExisting = false;
  bool _disposed = false;
  Future<void>? _disposal;
  @override
  final LiveKitLocalMedia localMedia;
  @override
  final LiveKitRoomMedia roomMedia;
  @visibleForTesting
  int get cachedRemotePublicationCount => _subscriptions.length;

  int get _remotePublicationCount => _room.remoteParticipants.values.fold(
    0,
    (count, participant) => count + participant.getTrackPublications().length,
  );

  int get _activeSubscriptionCount => _subscriptions.values
      .where(
        (subscription) =>
            subscription.requested || subscription.mayBeSubscribed,
      )
      .length;

  void _reportMediaRecovery(
    String outcome, {
    SentryLevel level = SentryLevel.info,
    Map<String, Object?> data = const {},
  }) {
    // Diagnostics must never affect media recovery, including with partial SDK
    // objects during teardown or tests.
    try {
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            category: 'session.media_recovery',
            message: outcome,
            level: level,
            data: {
              'room_name': _room.name,
              'local_identity': localIdentity,
              'connection_generation': _mediaGeneration,
              'remote_participant_count': _room.remoteParticipants.length,
              'remote_publication_count': _remotePublicationCount,
              'active_subscription_count': _activeSubscriptionCount,
              'authorized_participant_count': _incomingMediaParticipants.length,
              ...data,
            },
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Stream<SessionTransportEvent> get events => _events.stream;
  @override
  SessionTransportConnectionState get connectionState =>
      switch (_room.connectionState) {
        sdk.ConnectionState.connected =>
          SessionTransportConnectionState.connected,
        sdk.ConnectionState.connecting =>
          SessionTransportConnectionState.connecting,
        sdk.ConnectionState.reconnecting =>
          SessionTransportConnectionState.reconnecting,
        sdk.ConnectionState.disconnected =>
          SessionTransportConnectionState.disconnected,
      };
  @override
  String? get localIdentity => _room.localParticipant?.identity;
  @override
  String? get metadata => _room.metadata;
  @override
  List<ParticipantInfo> get participants => List.unmodifiable([
    if (_room.localParticipant case final local?) local.toInfo(),
    ..._room.remoteParticipants.values.map((p) => p.toInfo()),
  ]);
  void _emit(SessionTransportEvent event) {
    if (!_disposed) _events.add(event);
  }

  void _connection(
    SessionTransportConnectionState state, {
    String? reason,
    bool reconnected = false,
  }) {
    final transitioned = _mediaConnection != state;
    if (transitioned) _mediaGeneration++;
    if (reconnected) {
      for (final subscription in _subscriptions.values) {
        subscription.requested = false;
      }
    }
    _mediaConnection = state;
    if (transitioned || reconnected) {
      _reportMediaRecovery(
        reconnected ? 'reconnected' : 'connection_${state.name}',
        data: {'disconnect_reason': reason},
      );
    }
    if (state != SessionTransportConnectionState.connected) {
      _cleanupRetry?.cancel();
      _cleanupRetry = null;
      _subscriptionRetry?.cancel();
      _subscriptionRetry = null;
    }
    if (state == SessionTransportConnectionState.disconnected) {
      _pruneSubscriptions();
    }
    _emit(
      TransportConnectionChanged(
        state,
        reconnected: reconnected,
        reason: reason == null
            ? null
            : SessionTransportDisconnectReason.values.firstWhere(
                (value) => value.name == reason,
                orElse: () => SessionTransportDisconnectReason.unknown,
              ),
      ),
    );
    if (state == SessionTransportConnectionState.connected &&
        _subscribeExisting) {
      _subscribeInBackground(
        reconnected
            ? _recoverRemoteSubscriptions()
            : subscribeToExistingMedia(),
      );
    }
  }

  Future<void> _recoverRemoteSubscriptions() async {
    _reportMediaRecovery('subscription_reconciliation_started');
    try {
      await subscribeToExistingMedia();
      _reportMediaRecovery('subscription_reconciliation_succeeded');
    } catch (_) {
      _reportMediaRecovery(
        'subscription_reconciliation_failed',
        level: SentryLevel.warning,
      );
      rethrow;
    }
  }

  void _participant(sdk.Participant participant, bool present) => _emit(
    TransportParticipantChanged(participant.toInfo(), present: present),
  );
  void _requireActive() {
    if (_disposed) throw StateError('Transport disposed');
  }

  static SessionTransportFailure failure(
    Object error,
    StackTrace stackTrace, {
    SessionTransportFailureKind fallback =
        SessionTransportFailureKind.unexpected,
  }) => SessionTransportFailure(
    switch (error) {
      sdk.ConnectException() => SessionTransportFailureKind.connection,
      sdk.MediaConnectException() =>
        SessionTransportFailureKind.mediaConnection,
      sdk.LiveKitException() =>
        fallback == SessionTransportFailureKind.unexpected
            ? SessionTransportFailureKind.connection
            : fallback,
      _ => fallback,
    },
    error is sdk.LiveKitException ? error.message : error.toString(),
    cause: error,
    stackTrace: stackTrace,
    connectionFailure: error is sdk.ConnectException
        ? switch (error.reason) {
            sdk.ConnectionErrorReason.NotAllowed =>
              SessionTransportConnectionFailure.notAllowed,
            sdk.ConnectionErrorReason.InternalError =>
              SessionTransportConnectionFailure.internal,
            sdk.ConnectionErrorReason.Timeout =>
              SessionTransportConnectionFailure.timeout,
          }
        : null,
  );
  (String, String)? _prepared;
  @override
  Future<void> prepare(String url, String token) async {
    _requireActive();
    if (_prepared == (url, token)) return;
    try {
      await _room.prepareConnection(url, token);
      _requireActive();
      _prepared = (url, token);
    } catch (error, stackTrace) {
      throw failure(error, stackTrace);
    }
  }

  @override
  Future<void> connect(
    String url,
    String token, {
    bool autoSubscribe = true,
  }) async {
    _requireActive();
    try {
      await prepare(url, token);
      _requireActive();
      await _room.connect(
        url,
        token,
        connectOptions: sdk.ConnectOptions(
          autoSubscribe: autoSubscribe,
          timeouts: defaultTargetPlatform == TargetPlatform.iOS
              ? const sdk.Timeouts(
                  connection: Duration(seconds: 30),
                  debounce: Duration(milliseconds: 20),
                  publish: Duration(seconds: 10),
                  subscribe: Duration(seconds: 10),
                  peerConnection: Duration(seconds: 10),
                  iceRestart: Duration(seconds: 10),
                )
              : (const sdk.ConnectOptions()).timeouts,
        ),
      );
      _requireActive();
    } catch (error, stackTrace) {
      throw failure(error, stackTrace);
    }
  }

  @override
  Future<void> publish(SessionTransportPacket packet) async {
    _requireActive();
    final local = _room.localParticipant;
    if (local == null ||
        connectionState != SessionTransportConnectionState.connected) {
      throw StateError('Transport is not connected');
    }
    try {
      await local.publishData(
        packet.bytes,
        topic: packet.topic,
        reliable: packet.reliable,
        destinationIdentities: packet.recipients,
      );
    } catch (error, stackTrace) {
      throw failure(
        error,
        stackTrace,
        fallback: SessionTransportFailureKind.publication,
      );
    }
  }

  @override
  void setSubscriptionPermissions({
    required bool allowEveryone,
    required Set<String> recipients,
  }) {
    _requireActive();
    final local = _room.localParticipant;
    if (local == null) throw StateError('Transport has no local participant');
    local.setTrackSubscriptionPermissions(
      allParticipantsAllowed: allowEveryone,
      trackPermissions: recipients
          .map((id) => sdk.ParticipantTrackPermission(id, true, null))
          .toList(),
    );
  }

  void _subscribeInBackground(Future<void> subscription) {
    unawaited(
      subscription.catchError((Object error, StackTrace stackTrace) {
        if (!_disposed) _events.addError(error, stackTrace);
      }),
    );
  }

  bool _currentPublication(
    sdk.RemoteParticipant participant,
    sdk.RemoteTrackPublication publication,
  ) =>
      !(_departedParticipants[participant] ?? false) &&
      !(_removedPublications[publication] ?? false) &&
      identical(_room.remoteParticipants[participant.identity], participant) &&
      participant.getTrackPublications().any((p) => identical(p, publication));

  bool _authorizedPublication(
    sdk.RemoteParticipant participant,
    sdk.RemoteTrackPublication publication,
  ) => _subscriptionBlockedPath(participant, publication) == null;

  String? _subscriptionBlockedPath(
    sdk.RemoteParticipant participant,
    sdk.RemoteTrackPublication publication,
  ) {
    if (_disposed ||
        !_subscribeExisting ||
        !_incomingMediaParticipants.contains(participant.identity)) {
      return 'authorization';
    }
    if (!_currentPublication(participant, publication)) return 'current';
    if (!publication.subscriptionAllowed) return 'publication_ineligible';
    return null;
  }

  void _reportSubscriptionBlock(
    _RemoteSubscription state,
    String? blockedPath,
  ) {
    if (state.blockedPath == blockedPath) return;
    state.blockedPath = blockedPath;
    if (blockedPath == null) return;
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'admission.subscription_blocked',
          message: 'Subscription blocked',
          level: SentryLevel.info,
          data: {'path': blockedPath},
        ),
      ),
    );
  }

  _RemoteSubscription _subscriptionState(
    sdk.RemoteParticipant participant,
    sdk.RemoteTrackPublication publication,
  ) {
    final state = _subscriptionOperations[publication] ??= (_RemoteSubscription(
      participant,
    )..mayBeSubscribed = publication.subscribed);
    return state..participant = participant;
  }

  Future<void> _subscribe(
    sdk.RemoteParticipant participant,
    sdk.RemoteTrackPublication publication,
  ) {
    final state = _subscriptionState(participant, publication)..dirty = true;
    if (!_authorizedPublication(participant, publication)) {
      _subscriptions.remove(publication);
    } else {
      _subscriptions[publication] = state;
    }
    if (state.operation case final operation?) return operation;
    final completion = Completer<void>();
    state.operation = completion.future;
    final key = (participant.identity, publication.sid);
    final previous = _subscriptionLanes[key];
    final released = Completer<void>();
    _subscriptionLanes[key] = released.future;
    Future<void> run() async {
      try {
        do {
          state.dirty = false;
          await _reconcileSubscription(publication, state);
        } while (state.dirty);
        state.operation = null;
        completion.complete();
      } catch (error, stack) {
        state.operation = null;
        if (identical(_subscriptions[publication], state)) {
          _subscriptions.remove(publication);
        }
        _scheduleSubscriptionRetry(publication, state);
        completion.completeError(
          failure(
            error,
            stack,
            fallback: SessionTransportFailureKind.subscription,
          ),
          stack,
        );
      } finally {
        if (identical(_subscriptionLanes[key], released.future)) {
          _subscriptionLanes.remove(key);
        }
        released.complete();
      }
    }

    if (previous == null) {
      unawaited(run());
    } else {
      unawaited(previous.then((_) => run()));
    }
    return completion.future;
  }

  Future<void> _reconcileSubscription(
    sdk.RemoteTrackPublication publication,
    _RemoteSubscription state,
  ) async {
    var cleanupFailures = 0;
    while (true) {
      final participant = state.participant;
      final blockedPath = _subscriptionBlockedPath(participant, publication);
      _reportSubscriptionBlock(state, blockedPath);
      if (blockedPath != null ||
          _mediaConnection == SessionTransportConnectionState.disconnected) {
        _subscriptions.remove(publication);
        // A late SDK event for an obsolete object may address the same server
        // track as a newer subscription. Never send stale cleanup over it.
        if (_hasAuthorizedReplacement(participant, publication)) {
          state
            ..requested = false
            ..mayBeSubscribed = false;
          _forgetCleanup(publication);
          return;
        }
        if (!state.requested && !state.mayBeSubscribed) {
          _forgetCleanup(publication);
          return;
        }
        state
          ..requested = false
          ..mayBeSubscribed = false;
        if (!_disposed && _currentPublication(participant, publication)) {
          _pendingCleanup[publication] = state;
        }
        try {
          await publication.unsubscribe();
          _forgetCleanup(publication);
        } catch (_) {
          state.mayBeSubscribed = true;
          // A single immediate retry handles a transient cleanup failure. Keep
          // current failed cleanup discoverable for later reconciliation.
          if (++cleanupFailures < 2) continue;
          _scheduleCleanupRetry();
          rethrow;
        }
        // A newer grant waits behind this cleanup instead of being undone by it.
        continue;
      }
      _forgetCleanup(publication);
      // Keep working media during SDK reconnect; only new work is paused.
      if (_mediaConnection != SessionTransportConnectionState.connected) return;
      if (publication.subscribed) {
        state.requested = true;
        _subscriptions[publication] = state;
        _forgetSubscriptionRetry(publication);
        return;
      }
      if (state.requested) {
        _scheduleSubscriptionRetry(publication, state);
        return;
      }
      final generation = _mediaGeneration;
      final authorization = _authorization[participant.identity];
      final permission = state.permissionRevision;
      state.mayBeSubscribed = true;
      try {
        await publication.subscribe();
      } catch (_) {
        state.requested = false;
        if (generation != _mediaGeneration ||
            !identical(authorization, _authorization[participant.identity]) ||
            permission != state.permissionRevision ||
            !_currentPublication(participant, publication)) {
          continue;
        }
        rethrow;
      }
      // Revalidate against current authority and SDK ownership after every await.
      // A changed scope may adopt this result only if the same object is still
      // eligible; otherwise the loop performs serialized revocation cleanup.
      state.requested =
          generation == _mediaGeneration &&
          permission == state.permissionRevision &&
          publication.subscriptionAllowed;
      if (!_authorizedPublication(participant, publication) ||
          _mediaConnection == SessionTransportConnectionState.disconnected) {
        state.requested = true;
        continue;
      }
      if (permission != state.permissionRevision) {
        state.requested = publication.subscribed;
      }
    }
  }

  void _forgetCleanup(sdk.RemoteTrackPublication publication) {
    _pendingCleanup.remove(publication);
    if (_pendingCleanup.isEmpty) {
      _cleanupRetry?.cancel();
      _cleanupRetry = null;
      _cleanupRetryAttempt = 0;
    }
  }

  void _forgetSubscriptionRetry(sdk.RemoteTrackPublication publication) {
    _failedSubscriptions.remove(publication);
    if (_failedSubscriptions.isEmpty) {
      _subscriptionRetry?.cancel();
      _subscriptionRetry = null;
      _subscriptionRetryAttempt = 0;
    }
  }

  void _scheduleSubscriptionRetry(
    sdk.RemoteTrackPublication publication,
    _RemoteSubscription state,
  ) {
    if (_disposed ||
        _mediaConnection != SessionTransportConnectionState.connected ||
        !_authorizedPublication(state.participant, publication)) {
      return;
    }
    _failedSubscriptions[publication] = state;
    if (_subscriptionRetry != null) return;
    final seconds = _subscriptionRetryAttempt < 5
        ? 1 << _subscriptionRetryAttempt
        : 30;
    if (_subscriptionRetryAttempt < 5) _subscriptionRetryAttempt++;
    _reportMediaRecovery(
      'subscription_retry_scheduled',
      level: SentryLevel.warning,
      data: {'retry_attempt': _subscriptionRetryAttempt},
    );
    _subscriptionRetry = Timer(Duration(seconds: seconds), () {
      _subscriptionRetry = null;
      final failed =
          Map<sdk.RemoteTrackPublication, _RemoteSubscription>.identity()
            ..addAll(_failedSubscriptions);
      for (final entry in failed.entries) {
        if (!_disposed &&
            _mediaConnection == SessionTransportConnectionState.connected &&
            _authorizedPublication(entry.value.participant, entry.key)) {
          entry.value.requested = false;
          _subscribeInBackground(
            _subscribe(entry.value.participant, entry.key),
          );
        }
      }
    });
  }

  void _scheduleCleanupRetry() {
    if (_disposed ||
        _mediaConnection != SessionTransportConnectionState.connected ||
        _pendingCleanup.isEmpty ||
        _cleanupRetry != null) {
      return;
    }
    final seconds = _cleanupRetryAttempt < 5 ? 1 << _cleanupRetryAttempt : 30;
    if (_cleanupRetryAttempt < 5) _cleanupRetryAttempt++;
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'subscription.cleanup_failure',
          message: 'Subscription cleanup retry scheduled',
          level: SentryLevel.warning,
          data: {'retry_attempt': _cleanupRetryAttempt},
        ),
      ),
    );
    _cleanupRetry = Timer(Duration(seconds: seconds), () {
      _cleanupRetry = null;
      if (!_disposed) _pruneSubscriptions();
    });
  }

  bool _hasAuthorizedReplacement(
    sdk.RemoteParticipant participant,
    sdk.RemoteTrackPublication publication,
  ) {
    if (_currentPublication(participant, publication)) return false;
    final current = _room.remoteParticipants[participant.identity];
    if (current == null) return false;
    return current.getTrackPublications().any(
      (candidate) =>
          !identical(candidate, publication) &&
          candidate.sid == publication.sid &&
          _authorizedPublication(current, candidate) &&
          ((_subscriptionOperations[candidate]?.requested ?? false) ||
              candidate.subscribed),
    );
  }

  void _pruneSubscriptions() {
    _failedSubscriptions.removeWhere(
      (publication, state) =>
          !_authorizedPublication(state.participant, publication),
    );
    if (_failedSubscriptions.isEmpty) {
      _subscriptionRetry?.cancel();
      _subscriptionRetry = null;
      _subscriptionRetryAttempt = 0;
    }
    final tracked =
        Map<sdk.RemoteTrackPublication, _RemoteSubscription>.identity()
          ..addAll(_subscriptions)
          ..addAll(_pendingCleanup);
    for (final entry in tracked.entries.toList()) {
      if (!_currentPublication(entry.value.participant, entry.key)) {
        _forgetCleanup(entry.key);
      }
      if (!_authorizedPublication(entry.value.participant, entry.key) ||
          _mediaConnection == SessionTransportConnectionState.disconnected) {
        _subscriptions.remove(entry.key);
        _subscribeInBackground(_subscribe(entry.value.participant, entry.key));
      }
    }
  }

  @override
  void setIncomingMediaParticipants(Set<String> identities) {
    _requireActive();
    if (setEquals(_incomingMediaParticipants, identities)) {
      _pruneSubscriptions();
      return;
    }
    _incomingMediaParticipants = Set.unmodifiable(identities);
    _authorization.removeWhere((identity, _) => !identities.contains(identity));
    for (final identity in identities) {
      _authorization.putIfAbsent(identity, Object.new);
    }
    _pruneSubscriptions();
    if (_subscribeExisting) _subscribeInBackground(subscribeToExistingMedia());
  }

  @override
  Future<void> subscribeToExistingMedia() async {
    _requireActive();
    _subscribeExisting = true;
    final current =
        Map<sdk.RemoteTrackPublication, sdk.RemoteParticipant>.identity();
    for (final participant in _room.remoteParticipants.values) {
      for (final publication in participant.getTrackPublications()) {
        current[publication] = participant;
      }
    }
    _pruneSubscriptions();
    await Future.wait(
      current.entries.map((entry) => _subscribe(entry.value, entry.key)),
      // Do not let one publisher's failure short-circuit the other recoveries.
      eagerError: false,
    );
  }

  @override
  Future<void> disconnect() async {
    _requireActive();
    _mediaGeneration++;
    _cleanupRetry?.cancel();
    _cleanupRetry = null;
    _subscriptionRetry?.cancel();
    _subscriptionRetry = null;
    _failedSubscriptions.clear();
    _mediaConnection = SessionTransportConnectionState.disconnected;
    _subscribeExisting = false;
    _pruneSubscriptions();
    await _room.disconnect();
  }

  @override
  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    _cleanupRetry?.cancel();
    _cleanupRetry = null;
    _subscriptionRetry?.cancel();
    _subscriptionRetry = null;
    _mediaGeneration++;
    _subscribeExisting = false;
    _authorization.clear();
    _pruneSubscriptions();
    try {
      await _listener.dispose();
    } finally {
      try {
        await localMedia.release();
      } finally {
        localMedia.attach(null);
        roomMedia.attach(null);
        _subscriptions.clear();
        _pendingCleanup.clear();
        _failedSubscriptions.clear();
        _subscriptionLanes.clear();
        try {
          await _room.dispose();
        } finally {
          await _events.close();
        }
      }
    }
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:totem_core/features/sessions/media/livekit_local_media.dart';
import 'package:totem_core/features/sessions/media/livekit_room_media.dart';
import 'package:totem_core/features/sessions/media/livekit_support.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

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
    _listener = room.createListener()
      ..on<sdk.RoomConnectedEvent>(
        (_) => _connection(SessionTransportConnectionState.connected),
      )
      ..on<sdk.RoomReconnectingEvent>(
        (_) => _connection(SessionTransportConnectionState.reconnecting),
      )
      ..on<sdk.RoomReconnectedEvent>(
        (_) => _connection(
          SessionTransportConnectionState.connected,
          reconnected: true,
        ),
      )
      ..on<sdk.RoomDisconnectedEvent>(
        (event) => _connection(
          SessionTransportConnectionState.disconnected,
          reason: event.reason?.name,
        ),
      )
      ..on<sdk.RoomMetadataChangedEvent>(
        (event) => _emit(TransportMetadataChanged(event.metadata)),
      )
      ..on<sdk.ParticipantConnectedEvent>(
        (event) => _participant(event.participant, true),
      )
      ..on<sdk.ParticipantDisconnectedEvent>(
        (event) => _participant(event.participant, false),
      )
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
        _emit(const TransportMediaChanged());
        if (_subscribeExisting) {
          unawaited(
            _subscribe(event.publication).catchError((
              Object error,
              StackTrace stackTrace,
            ) {
              if (!_disposed) _events.addError(error, stackTrace);
            }),
          );
        }
      })
      ..on<sdk.TrackUnpublishedEvent>((event) {
        _subscriptions.remove(event.publication);
        _emit(const TransportMediaChanged());
      });
  }
  final sdk.Room _room;

  /// Infrastructure compatibility access only; remove with B2/C2 consumers.
  sdk.Room get legacyRoomForB2AndC2 => _room;
  late final sdk.EventsListener<sdk.RoomEvent> _listener;
  final _events = StreamController<SessionTransportEvent>.broadcast(sync: true);
  final Map<sdk.RemoteTrackPublication, Object> _subscriptions = Map.identity();
  bool _subscribeExisting = false;
  bool _disposed = false;
  Future<void>? _disposal;
  @override
  final LiveKitLocalMedia localMedia;
  @override
  final LiveKitRoomMedia roomMedia;
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
  }) => _emit(
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

  Future<void> _subscribe(sdk.RemoteTrackPublication publication) async {
    if (_disposed || _subscriptions.containsKey(publication)) return;
    final token = Object();
    _subscriptions[publication] = token;
    try {
      await publication.subscribe();
    } catch (error, stackTrace) {
      if (identical(_subscriptions[publication], token)) {
        _subscriptions.remove(publication);
      }
      throw failure(
        error,
        stackTrace,
        fallback: SessionTransportFailureKind.subscription,
      );
    }
  }

  @override
  Future<void> subscribeToExistingMedia() async {
    _requireActive();
    _subscribeExisting = true;
    await Future.wait(
      _room.remoteParticipants.values
          .expand((p) => p.getTrackPublications())
          .map(_subscribe),
    );
  }

  @override
  Future<void> disconnect() async {
    _requireActive();
    await _room.disconnect();
  }

  @override
  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    try {
      await _listener.dispose();
    } finally {
      try {
        await localMedia.release();
      } finally {
        localMedia.attach(null);
        roomMedia.attach(null);
        _subscriptions.clear();
        try {
          await _room.dispose();
        } finally {
          await _events.close();
        }
      }
    }
  }
}

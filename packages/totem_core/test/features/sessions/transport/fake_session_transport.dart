import 'dart:async';
import 'package:totem_core/features/sessions/media/local_media.dart';
import 'package:totem_core/features/sessions/media/participant_info.dart';
import 'package:totem_core/features/sessions/media/room_media.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';
import '../media/fake_local_media.dart';
import '../media/fake_room_media.dart';

class FakeSessionTransportFactory implements SessionTransportFactory {
  FakeSessionTransportFactory({this.configure});
  final void Function(FakeSessionTransport)? configure;
  @override
  final FakeLocalMedia localMedia = FakeLocalMedia();
  @override
  final FakeRoomMedia roomMedia = FakeRoomMedia();
  final created = <FakeSessionTransport>[];
  @override
  FakeSessionTransport create() {
    final transport = FakeSessionTransport(
      localMedia: localMedia,
      roomMedia: roomMedia,
    );
    configure?.call(transport);
    created.add(transport);
    return transport;
  }
}

class FakeSessionTransport implements SessionTransport {
  FakeSessionTransport({LocalMedia? localMedia, RoomMedia? roomMedia})
    : localMedia = localMedia ?? FakeLocalMedia(),
      roomMedia = roomMedia ?? FakeRoomMedia();
  final _events = StreamController<SessionTransportEvent>.broadcast(sync: true);
  bool _disposed = false;
  Future<void>? _disposal;
  Completer<void>? connectCompletion;
  Completer<void>? connectStarted;
  Exception? connectFailure;
  Exception? publishFailure;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int underlyingDisposals = 0;
  int subscribeCalls = 0;
  bool? autoSubscribe;
  int permissionUpdates = 0;
  bool allowEveryone = false;
  Set<String> recipients = {};
  final publications = <SessionTransportPacket>[];
  @override
  SessionTransportConnectionState connectionState =
      SessionTransportConnectionState.disconnected;
  @override
  String? localIdentity = 'local';
  @override
  String? metadata;
  @override
  List<ParticipantInfo> participants = [];
  @override
  final LocalMedia localMedia;
  @override
  final RoomMedia roomMedia;
  @override
  Stream<SessionTransportEvent> get events => _events.stream;
  void _active() {
    if (_disposed) throw StateError('Transport disposed');
  }

  void emit(SessionTransportEvent event) {
    if (_disposed) return;
    switch (event) {
      case TransportConnectionChanged(:final state):
        connectionState = state;
      case TransportMetadataChanged(:final metadata):
        this.metadata = metadata;
      case TransportParticipantChanged(:final participant, :final present):
        participants = [
          ...participants.where((p) => p.identity != participant.identity),
          if (present) participant,
        ];
      case TransportParticipantUpdated(:final participant):
        participants = [
          for (final current in participants)
            if (current.identity == participant.identity)
              participant
            else
              current,
        ];
      default:
        break;
    }
    _events.add(event);
  }

  @override
  Future<void> prepare(String url, String token) async {
    _active();
  }

  @override
  Future<void> connect(
    String url,
    String token, {
    bool autoSubscribe = true,
  }) async {
    _active();
    connectCalls++;
    connectStarted?.complete();
    this.autoSubscribe = autoSubscribe;
    emit(
      const TransportConnectionChanged(
        SessionTransportConnectionState.connecting,
      ),
    );
    await connectCompletion?.future;
    _active();
    if (connectFailure case final failure?) {
      emit(
        const TransportConnectionChanged(
          SessionTransportConnectionState.disconnected,
        ),
      );
      throw failure;
    }
    emit(
      const TransportConnectionChanged(
        SessionTransportConnectionState.connected,
      ),
    );
  }

  @override
  Future<void> publish(SessionTransportPacket packet) async {
    _active();
    if (connectionState != SessionTransportConnectionState.connected) {
      throw StateError('Not connected');
    }
    if (publishFailure case final failure?) throw failure;
    publications.add(packet);
  }

  @override
  void setSubscriptionPermissions({
    required bool allowEveryone,
    required Set<String> recipients,
  }) {
    _active();
    permissionUpdates++;
    this.allowEveryone = allowEveryone;
    this.recipients = Set.unmodifiable(recipients);
  }

  Set<String> incomingMediaParticipants = const {};

  @override
  void setIncomingMediaParticipants(Set<String> identities) {
    _active();
    incomingMediaParticipants = Set.unmodifiable(identities);
  }

  @override
  Future<void> subscribeToExistingMedia() async {
    _active();
    subscribeCalls++;
  }

  @override
  Future<void> disconnect() async {
    _active();
    disconnectCalls++;
    emit(
      const TransportConnectionChanged(
        SessionTransportConnectionState.disconnected,
      ),
    );
  }

  @override
  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    underlyingDisposals++;
    connectionState = SessionTransportConnectionState.disconnected;
    await _events.close();
  }
}

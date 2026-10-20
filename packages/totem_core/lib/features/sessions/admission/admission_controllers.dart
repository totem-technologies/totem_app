import 'dart:async';

import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:uuid/uuid.dart';

enum AdmissionStatus {
  idle,
  pending,
  approved,
  denied,
  expired,
  cancelled,
  ended,
  failed,
}

/// The caller owns [channel] and must dispose this controller before the room.
/// Changes are emitted for UI consumers; read [status] after subscribing.
class PendingAdmissionController {
  new({
    required this.channel,
    required this.keeperIdentity,
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? const Uuid().v4,
       _status = channel.hasEnded
           ? AdmissionStatus.ended
           : AdmissionStatus.idle {
    _subscription = channel.events.listen(_onEvent);
  }

  final AdmissionChannel channel;
  final String Function() keeperIdentity;
  final DateTime Function() _now;
  final String Function() _newId;
  final _changes = StreamController<AdmissionStatus>.broadcast();
  late final StreamSubscription<AdmissionEvent> _subscription;
  Timer? _expiration;
  AdmissionRequest? _request;
  AdmissionCancel? _cancellation;
  AdmissionStatus _status;
  bool _disposed = false;

  Stream<AdmissionStatus> get changes => _changes.stream;
  AdmissionStatus get status => _status;
  AdmissionRequest? get request => _request;

  Future<AdmissionRequest> requestAdmission({
    required String displayName,
  }) async {
    if (_disposed ||
        channel.hasEnded ||
        _status == AdmissionStatus.pending ||
        _status == AdmissionStatus.ended ||
        _status == AdmissionStatus.failed) {
      throw StateError('Admission unavailable');
    }
    final keeper = keeperIdentity();
    final local = channel.localIdentity;
    final name = displayName.trim();
    if (keeper.isEmpty ||
        local.isEmpty ||
        keeper == local ||
        name.isEmpty ||
        name.length > 120) {
      throw ArgumentError('Invalid admission identities or display name');
    }
    final candidate = _now()
        .add(AdmissionProtocol.lifetime)
        .millisecondsSinceEpoch;
    final previous = _request?.expiresAt.millisecondsSinceEpoch;
    final expirationMillis = previous != null && candidate <= previous
        ? previous + 1
        : candidate;
    if (expirationMillis - _now().millisecondsSinceEpoch >
        AdmissionProtocol.maxLifetime.inMilliseconds) {
      throw StateError('Too many admission requests in a short time');
    }
    _expiration?.cancel();
    _cancellation = null;
    final packet = AdmissionRequest(
      id: _newId(),
      senderIdentity: local,
      recipientIdentity: keeper,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expirationMillis),
      displayName: name,
    );
    _request = packet;
    _setStatus(AdmissionStatus.pending);
    _expiration = Timer(packet.expiresAt.difference(_now()), _expire);
    if (channel.isPresent(keeper)) await _sendBestEffort(packet);
    return packet;
  }

  /// Cancels locally even when the keeper is offline; sends a targeted cancel
  /// now and again on presence/reconnect until the request expires.
  Future<void> cancel() async {
    if (_disposed ||
        (_status != AdmissionStatus.pending &&
            _status != AdmissionStatus.cancelled)) {
      return;
    }
    final request = _request!;
    _cancellation ??= AdmissionCancel(
      id: request.id,
      senderIdentity: request.senderIdentity,
      recipientIdentity: request.recipientIdentity,
      expiresAt: request.expiresAt,
    );
    _expiration?.cancel();
    if (_status != AdmissionStatus.cancelled) {
      _setStatus(AdmissionStatus.cancelled);
    }
    if (_now().isBefore(request.expiresAt) &&
        channel.isPresent(request.recipientIdentity)) {
      await _sendBestEffort(_cancellation!);
    }
  }

  Future<void> _sendBestEffort(AdmissionPacket packet) async {
    try {
      await channel.send(packet);
    } catch (_) {
      // The pending request/cancel is retried on presence or reconnect.
    }
  }

  void _onEvent(AdmissionEvent event) {
    if (_disposed) return;
    if (event is AdmissionRoomEnded) {
      _expiration?.cancel();
      if (_status != AdmissionStatus.ended) _setStatus(AdmissionStatus.ended);
      return;
    }
    if (_status != AdmissionStatus.pending &&
        _status != AdmissionStatus.cancelled) {
      return;
    }
    if (event is AdmissionRoomDisconnected) {
      if (_status == AdmissionStatus.pending) {
        _expiration?.cancel();
        _setStatus(AdmissionStatus.failed);
      }
      return;
    }
    final request = _request!;
    if (!_now().isBefore(request.expiresAt)) {
      if (_status == AdmissionStatus.pending) _expire();
      return;
    }
    switch (event) {
      case AdmissionPacketReceived(packet: final AdmissionDecision decision):
        if (_status != AdmissionStatus.pending ||
            decision.id != request.id ||
            decision.senderIdentity != request.recipientIdentity ||
            decision.senderIdentity != keeperIdentity() ||
            decision.recipientIdentity != channel.localIdentity ||
            decision.expiresAt != request.expiresAt) {
          return;
        }
        _expiration?.cancel();
        _setStatus(
          decision.approved ? AdmissionStatus.approved : AdmissionStatus.denied,
        );
      case AdmissionPacketReceived(packet: final AdmissionHello hello):
        if (hello.senderIdentity == request.recipientIdentity &&
            hello.senderIdentity == keeperIdentity() &&
            hello.recipientIdentity == channel.localIdentity) {
          _resendIfPresent();
        }
      case AdmissionConnectionRestored():
        _resendIfPresent();
      case AdmissionPresenceChanged(:final identity, present: true):
        if (identity == request.recipientIdentity) _resendIfPresent();
      default:
        break;
    }
  }

  void _resendIfPresent() {
    final request = _request!;
    if (keeperIdentity() == request.recipientIdentity &&
        channel.isPresent(request.recipientIdentity)) {
      // A lost packet is retried only on presence/reconnect, never by polling.
      unawaited(_sendBestEffort(_cancellation ?? request));
    }
  }

  void _expire() {
    if (_status == AdmissionStatus.pending) _setStatus(AdmissionStatus.expired);
  }

  void _setStatus(AdmissionStatus next) {
    _status = next;
    _changes.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _expiration?.cancel();
    await _subscription.cancel();
    await _changes.close();
  }
}

/// Keeper-side queue with one decision per sender + request ID. Decisions are
/// retained until their request expires so reconnect resends get the same reply.
class KeeperAdmissionController {
  new({
    required this.channel,
    required this.keeperIdentity,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _ended = channel.hasEnded {
    _subscription = channel.events.listen(_onEvent);
    _advertise();
  }

  final AdmissionChannel channel;
  final String Function() keeperIdentity;
  final DateTime Function() _now;
  final _changes = StreamController<void>.broadcast();
  // At most one active request per participant identity. Keep the latest
  // packet across disconnects so an older request cannot resurrect the queue.
  final _latest = <String, AdmissionPacket>{};
  final _pending = <String, AdmissionRequest>{};
  final _decisions = <String, AdmissionDecision>{};
  final _expirations = <String, Timer>{};
  final _inFlight = <String>{};
  late final StreamSubscription<AdmissionEvent> _subscription;
  bool _disposed = false;
  bool _ended;

  Stream<void> get changes => _changes.stream;
  List<AdmissionRequest> get requests => List.unmodifiable(_pending.values);

  String _key(String sender, String id) => '$sender\u0000$id';

  void _advertise() {
    final keeper = channel.localIdentity;
    if (_disposed || _ended || keeper.isEmpty || keeperIdentity() != keeper) {
      return;
    }
    for (final identity in channel.remoteIdentities) {
      if (identity.isEmpty || identity == keeper) continue;
      unawaited(
        channel
            .send(
              AdmissionHello(
                id: const Uuid().v4(),
                senderIdentity: keeper,
                recipientIdentity: identity,
                expiresAt: _now().add(AdmissionProtocol.lifetime),
              ),
            )
            .catchError((Object _) {}),
      );
    }
  }

  void _onEvent(AdmissionEvent event) {
    if (_disposed || _ended) return;
    if (event is AdmissionRoomEnded) {
      _ended = true;
      for (final timer in _expirations.values) {
        timer.cancel();
      }
      _expirations.clear();
      _latest.clear();
      _pending.clear();
      _decisions.clear();
      _changes.add(null);
      return;
    }
    switch (event) {
      case AdmissionConnectionRestored():
        _advertise();
      case AdmissionPresenceChanged(:final identity, present: false):
        // A reconnecting participant can re-advertise this same request.
        if (_pending.remove(identity) != null) _changes.add(null);
      case AdmissionPacketReceived(:final packet)
          when packet is AdmissionRequest || packet is AdmissionCancel:
        if (keeperIdentity() != channel.localIdentity ||
            packet.senderIdentity == channel.localIdentity ||
            packet.recipientIdentity != channel.localIdentity ||
            !_now().isBefore(packet.expiresAt)) {
          return;
        }
        final sender = packet.senderIdentity;
        final latest = _latest[sender];
        if (latest == null) {
          _record(packet);
          return;
        }
        if (latest.id != packet.id) {
          if (packet.expiresAt.isAfter(latest.expiresAt)) _record(packet);
          return;
        }
        if (packet.expiresAt != latest.expiresAt) return;
        if (packet is AdmissionCancel) {
          if (latest is! AdmissionCancel) _record(packet);
        } else if (packet is AdmissionRequest &&
            latest is AdmissionRequest &&
            latest.displayName == packet.displayName) {
          final decision = _decisions[sender];
          if (decision != null) {
            unawaited(channel.send(decision).catchError((Object _) {}));
          } else if (_pending[sender] == null) {
            _pending[sender] = latest;
            _changes.add(null);
          }
        }
      default:
        break;
    }
  }

  void _record(AdmissionPacket packet) {
    final sender = packet.senderIdentity;
    _expirations.remove(sender)?.cancel();
    _latest[sender] = packet;
    _decisions.remove(sender);
    if (packet is AdmissionRequest) {
      _pending[sender] = packet;
    } else {
      _pending.remove(sender);
    }
    _expirations[sender] = Timer(packet.expiresAt.difference(_now()), () {
      if (!identical(_latest[sender], packet)) return;
      _latest.remove(sender);
      _pending.remove(sender);
      _decisions.remove(sender);
      _expirations.remove(sender);
      if (!_disposed) _changes.add(null);
    });
    _changes.add(null);
  }

  Future<void> approve(String requestId, String participantIdentity) =>
      _decide(requestId, participantIdentity, true);

  Future<void> deny(String requestId, String participantIdentity) =>
      _decide(requestId, participantIdentity, false);

  Future<void> _decide(String id, String sender, bool approved) async {
    if (_disposed || _ended || keeperIdentity() != channel.localIdentity) {
      throw StateError('Not the current keeper');
    }
    final request = _pending[sender];
    if (request == null ||
        request.id != id ||
        !_now().isBefore(request.expiresAt)) {
      throw StateError('Request is no longer pending');
    }
    final key = _key(sender, id);
    if (!_inFlight.add(key)) throw StateError('Decision already in progress');
    try {
      final decision = AdmissionDecision(
        id: id,
        senderIdentity: channel.localIdentity,
        recipientIdentity: sender,
        expiresAt: request.expiresAt,
        approved: approved,
      );
      await channel.send(decision);
      if (_disposed ||
          _ended ||
          keeperIdentity() != channel.localIdentity ||
          !identical(_latest[sender], request) ||
          !identical(_pending[sender], request) ||
          !_now().isBefore(request.expiresAt)) {
        throw StateError('Request changed while deciding');
      }
      _pending.remove(sender);
      _decisions[sender] = decision;
      _changes.add(null);
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final timer in _expirations.values) {
      timer.cancel();
    }
    _expirations.clear();
    _latest.clear();
    _pending.clear();
    _decisions.clear();
    _inFlight.clear();
    await _subscription.cancel();
    await _changes.close();
  }
}

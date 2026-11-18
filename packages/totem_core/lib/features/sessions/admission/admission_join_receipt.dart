import 'dart:async';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';

/// Shared receipt recovery for pending SDK and active application channels.
/// Owns no connection or subscriptions.
class AdmissionJoinReceipt {
  AdmissionJoinReceipt({
    required this.localIdentity,
    required this.send,
    required this.now,
  });
  final String Function() localIdentity;
  final Future<void> Function(AdmissionPacket) send;
  final DateTime Function() now;
  static const _initialRetryDelay = Duration(seconds: 2);
  static const _maximumRetryDelay = Duration(seconds: 30);

  AdmissionPacket? _receipt;
  Timer? _retry;
  var _retryAttempt = 0;
  bool _sending = false;
  bool _confirmed = false;
  bool _disposed = false;
  bool _ended = false;
  bool _interrupted = false;

  void handle(AdmissionEvent event) {
    switch (event) {
      case AdmissionPacketReceived(:final packet):
        if (packet is AdmissionHello &&
            packet.senderIdentity == _receipt?.recipientIdentity &&
            packet.recipientIdentity == localIdentity()) {
          retry();
        }
        if (packet is AdmissionRosterPacket &&
            packet.senderIdentity == _receipt?.recipientIdentity &&
            packet.recipientIdentity == localIdentity() &&
            packet.members.contains(localIdentity())) {
          _confirmed = true;
          _retry?.cancel();
          _retry = null;
        }
      case AdmissionPresenceChanged(:final identity, :final present):
        if (present && identity == _receipt?.recipientIdentity) retry();
      case AdmissionConnectionInterrupted():
        _interrupted = true;
        _retry?.cancel();
        _retry = null;
      case AdmissionConnectionRestored():
        _interrupted = false;
        retry();
      case AdmissionRoomEnded():
        _ended = true;
        stop();
      case AdmissionRoomDisconnected():
        stop();
    }
  }

  Future<void> sendOutcome(
    AdmissionRequest request, {
    bool joined = true,
  }) async {
    if (_disposed || _ended) {
      throw StateError('Admission transport unavailable');
    }
    if (_receipt != null) throw StateError('Join outcome already sent');
    final receipt = joined
        ? AdmissionProtocol.joined(request)
        : AdmissionProtocol.joinFailed(request);
    if (receipt.senderIdentity != localIdentity() ||
        receipt.recipientIdentity == localIdentity() ||
        AdmissionProtocol.decode(
              AdmissionProtocol.encode(receipt),
              senderIdentity: localIdentity(),
              now: now(),
            ) ==
            null) {
      throw ArgumentError('Invalid or expired admission receipt');
    }
    _receipt = receipt;
    _confirmed = false;
    _retryAttempt = 0;
    await _sendReceipt();
  }

  void retry() {
    final receipt = _receipt;
    if (_disposed ||
        _ended ||
        _interrupted ||
        _confirmed ||
        _sending ||
        receipt == null) {
      return;
    }
    if (!now().isBefore(receipt.expiresAt)) {
      stop();
      return;
    }
    _retry?.cancel();
    _retry = null;
    unawaited(_sendReceipt().catchError((Object _) {}));
  }

  Future<void> _sendReceipt() async {
    final receipt = _receipt;
    if (_disposed ||
        _ended ||
        _interrupted ||
        _confirmed ||
        _sending ||
        receipt == null) {
      return;
    }
    _sending = true;
    try {
      await send(receipt);
    } finally {
      _sending = false;
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    final receipt = _receipt;
    if (_disposed ||
        _ended ||
        _interrupted ||
        _confirmed ||
        receipt == null ||
        !now().isBefore(receipt.expiresAt)) {
      return;
    }
    _retry?.cancel();
    _retry = Timer(_retryDelay(receipt), retry);
  }

  Duration _retryDelay(AdmissionPacket receipt) {
    final exponent = _retryAttempt.clamp(0, 4);
    final base = Duration(
      milliseconds: _initialRetryDelay.inMilliseconds * (1 << exponent),
    );
    if (_retryAttempt < 5) _retryAttempt++;
    final capped = base > _maximumRetryDelay ? _maximumRetryDelay : base;
    final jitter = ((receipt.id.hashCode + _retryAttempt * 17) % 21) - 10;
    return Duration(
      milliseconds: capped.inMilliseconds * (100 + jitter) ~/ 100,
    );
  }

  void stop() {
    _retry?.cancel();
    _retry = null;
    _receipt = null;
    _retryAttempt = 0;
    _confirmed = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
  }
}

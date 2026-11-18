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
  AdmissionPacket? _receipt;
  Timer? _retry;
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
    try {
      await send(receipt);
    } finally {
      if (!_disposed && !_ended && !_interrupted && !_confirmed) {
        _retry = Timer(const Duration(seconds: 2), retry);
      }
    }
  }

  void retry() {
    final receipt = _receipt;
    if (_disposed || _ended || _interrupted || _confirmed || receipt == null) {
      return;
    }
    if (!now().isBefore(receipt.expiresAt)) {
      _receipt = null;
      return;
    }
    unawaited(send(receipt).catchError((Object _) {}));
  }

  void stop() {
    _retry?.cancel();
    _retry = null;
    _receipt = null;
    _confirmed = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
  }
}

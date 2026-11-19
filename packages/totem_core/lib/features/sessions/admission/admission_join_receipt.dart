import 'dart:async';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:uuid/uuid.dart';

/// Shared receipt recovery for pending SDK and active application channels.
/// Owns no connection or subscriptions.
class AdmissionJoinReceipt {
  AdmissionJoinReceipt({
    required this.localIdentity,
    required this.send,
    required this.now,
    String Function()? newId,
    this.onConfirmationFailed,
  }) : _newId = newId ?? const Uuid().v4;
  final String Function() localIdentity;
  final Future<void> Function(AdmissionPacket) send;
  final DateTime Function() now;
  final String Function() _newId;
  final void Function()? onConfirmationFailed;
  static const _initialRetryDelay = Duration(seconds: 2);
  static const _maximumRetryDelay = Duration(seconds: 30);

  AdmissionPacket? _receipt;
  AdmissionRequest? _request;
  bool _awaitingDecision = false;
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
        if (packet is AdmissionDecision &&
            _awaitingDecision &&
            packet.id == _request?.id &&
            packet.senderIdentity == _request?.recipientIdentity &&
            packet.recipientIdentity == localIdentity()) {
          _awaitingDecision = false;
          if (packet.approved) {
            final request = _request!;
            _receipt = AdmissionProtocol.joined(request);
            _retryAttempt = 0;
            retry();
          } else {
            _failConfirmation();
          }
        }
        if ((packet is AdmissionHello || packet is AdmissionDecision) &&
            packet.senderIdentity == _request?.recipientIdentity &&
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
    _request = request;
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
    if (_disposed || _ended || _interrupted || _confirmed || _sending) return;
    if (_awaitingDecision) {
      unawaited(_sendReapprovalRequest());
      return;
    }
    if (receipt == null) return;
    if (!now().isBefore(receipt.expiresAt)) {
      _requestReapproval();
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
    final packet = _awaitingDecision ? _request : _receipt;
    if (_disposed || _ended || _interrupted || _confirmed || packet == null) {
      return;
    }
    if (!now().isBefore(packet.expiresAt)) {
      if (_awaitingDecision) {
        _failConfirmation();
      } else {
        _requestReapproval();
      }
      return;
    }
    _retry?.cancel();
    final remaining = packet.expiresAt.difference(now());
    final delay = _retryDelay(packet);
    _retry = Timer(delay < remaining ? delay : remaining, retry);
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

  void _requestReapproval() {
    final previous = _request;
    if (_disposed || _ended || previous == null || _awaitingDecision) return;
    final renewed = AdmissionRequest(
      id: _newId(),
      senderIdentity: localIdentity(),
      recipientIdentity: previous.recipientIdentity,
      expiresAt: now().add(AdmissionProtocol.lifetime),
      displayName: previous.displayName,
    );
    _request = renewed;
    _receipt = null;
    _awaitingDecision = true;
    _retryAttempt = 0;
    unawaited(_sendReapprovalRequest());
  }

  Future<void> _sendReapprovalRequest() async {
    final request = _request;
    if (_disposed || _ended || !_awaitingDecision || request == null) return;
    if (!now().isBefore(request.expiresAt)) {
      _failConfirmation();
      return;
    }
    _sending = true;
    try {
      await send(request);
    } catch (_) {
      // Retry on bounded backoff while the same explicit decision is pending.
    } finally {
      _sending = false;
      _scheduleRetry();
    }
  }

  void _failConfirmation() {
    stop();
    onConfirmationFailed?.call();
  }

  void stop() {
    _retry?.cancel();
    _retry = null;
    _receipt = null;
    _request = null;
    _awaitingDecision = false;
    _retryAttempt = 0;
    _confirmed = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
  }
}

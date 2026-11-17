import 'dart:async';
import 'package:totem_core/core/api/api_client/api_client.dart';

class SessionKeeperPresence {
  SessionKeeperPresence({
    required this.mute,
    required this.leave,
    required this.onError,
    this.timeout = const Duration(minutes: 3),
  });
  final Future<void> Function() mute;
  final Future<void> Function() leave;
  final void Function(Object, StackTrace) onError;
  final Duration timeout;
  Timer? timer;
  bool _disposed = false;
  void disconnected(RoomStatus status) {
    if (_disposed || status != RoomStatus.active) return;
    cancel();
    unawaited(mute().catchError(onError));
    timer = Timer(timeout, () => unawaited(expired().catchError(onError)));
  }

  void connected() => cancel();
  Future<void> expired() async {
    cancel();
    if (!_disposed) await leave();
  }

  void cancel() {
    timer?.cancel();
    timer = null;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}

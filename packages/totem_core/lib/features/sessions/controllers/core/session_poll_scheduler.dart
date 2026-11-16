import 'dart:async';

/// One pair of low-frequency schedules and one coalesced fetch per connection.
class SessionPollScheduler {
  Timer? _sync;
  Timer? _poll;
  Future<void>? _fetch;
  Future<void> Function(bool reconcile)? _request;
  bool _pending = false;
  bool _reconcile = false;

  void start({
    required Duration syncInterval,
    required Duration pollInterval,
    required void Function() synchronize,
    required Future<void> Function(bool reconcile) fetch,
  }) {
    stop();
    _request = fetch;
    _sync = Timer.periodic(syncInterval, (_) => synchronize());
    _poll = Timer.periodic(pollInterval, (_) => unawaited(request()));
  }

  Future<void> request({bool reconcile = false}) {
    if (_request == null) return Future.value();
    _pending = true;
    _reconcile |= reconcile;
    return _fetch ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_pending && _request != null) {
        final reconcile = _reconcile;
        _pending = false;
        _reconcile = false;
        await _request?.call(reconcile);
      }
    } finally {
      _fetch = null;
      if (_pending && _request != null) {
        // This coalesced background retry has no caller to receive its error.
        unawaited(request().catchError((Object _, StackTrace _) {}));
      }
    }
  }

  void stop() {
    _sync?.cancel();
    _sync = null;
    _poll?.cancel();
    _poll = null;
    _request = null;
    _pending = false;
    _reconcile = false;
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/admission/admission_status.dart';
import 'package:totem_core/features/sessions/admission/server_admission_connection.dart';
import 'package:totem_core/features/sessions/repositories/participant_admission_repository.dart';
import 'package:uuid/uuid.dart';

export 'package:totem_core/features/sessions/admission/admission_status.dart';
export 'package:totem_core/features/sessions/admission/server_admission_connection.dart';

/// Synchronizes server admission with an externally owned signaling connection.
class ServerParticipantAdmission {
  ServerParticipantAdmission({
    required this.repository,
    required this.sessionSlug,
    required AdmissionJoinState initial,
    required this.connection,
    DateTime Function()? now,
    String Function()? newId,
  }) : _requestId = initial.requestId,
       _attemptId = initial.attemptId,
       _deadline = initial.status == 'pending' || initial.status == 'granting'
           ? initial.expiresAt
           : null,
       _now = now ?? DateTime.now,
       _newId = newId ?? const Uuid().v4;

  final ParticipantAdmissionRepository repository;
  final String sessionSlug;
  final ServerAdmissionConnection connection;
  final DateTime Function() _now;
  final String Function() _newId;
  final _changes = StreamController<AdmissionStatus>.broadcast();
  String _requestId;
  String _attemptId;
  DateTime? _deadline;
  AdmissionMeSnapshot? _snapshot;
  Object? _error;
  AdmissionStatus _status = AdmissionStatus.idle;
  AdmissionKeeperAvailability _keeper = AdmissionKeeperAvailability.checking;
  StreamSubscription<ServerAdmissionConnectionEvent>? _subscription;
  Timer? _retry;
  Timer? _expiration;
  Future<void>? _refreshing;
  Future<void>? _activation;
  Future<void>? _disposing;
  bool _queuedConfirm = false;
  bool _started = false;
  bool _disposed = false;
  bool _confirmed = false;
  bool _mediaActivated = false;
  bool _receiptSent = false;
  bool _recovering = false;
  bool _needsCreate = false;
  bool _cancelling = false;
  String? _confirmedSid;
  int _generation = 0;
  int _failures = 0;

  AdmissionStatus get status => _status;
  AdmissionKeeperAvailability get keeperAvailability => _keeper;
  bool get isReturningParticipant => _participant?.returning ?? false;
  bool? get sessionStartedAtAdmission =>
      _participant == null ||
          !['granting', 'approved', 'activated'].contains(_participant!.status)
      ? null
      : _participant!.sessionStarted;
  AdmissionMeSnapshot? get snapshot => _snapshot;
  Object? get error => _error;
  Stream<AdmissionStatus> get changes => _changes.stream;
  Participant? get _participant =>
      _snapshot?.me.isPresent == true ? _snapshot!.me.value : null;
  bool get _terminal => [
    AdmissionStatus.denied,
    AdmissionStatus.cancelled,
    AdmissionStatus.expired,
    AdmissionStatus.ended,
    AdmissionStatus.failed,
  ].contains(_status);

  Future<void> start() async {
    _ensureAlive();
    if (_started) return;
    _started = true;
    _subscription = connection.admissionEvents.listen(_onEvent);
    _setStatus(AdmissionStatus.pending);
    _scheduleExpiration();
    if (connection.isConnected) await refresh(confirm: true);
  }

  /// Concurrent refreshes coalesce; a confirmation requested during a fetch is
  /// performed afterwards, because a plain snapshot cannot confirm a SID.
  Future<void> refresh({bool confirm = false}) {
    _ensureAlive();
    if (!_started || _terminal || _cancelling) return Future.value();
    if (confirm) _queuedConfirm = true;
    final existing = _refreshing;
    if (existing != null) return existing;
    final generation = _generation;
    final future = _refreshLoop(generation);
    _refreshing = future;
    future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
    return future;
  }

  Future<void> _refreshLoop(int generation) async {
    do {
      final confirm = _queuedConfirm && connection.isConnected;
      _queuedConfirm = false;
      try {
        final sid = connection.localSid;
        if (confirm && _needsCreate) {
          final created = await repository.request(
            sessionSlug: sessionSlug,
            requestId: _requestId,
            attemptId: _attemptId,
          );
          if (!_valid(generation)) return;
          _accept(created);
          _needsCreate = false;
          if (!connection.isConnected || sid != connection.localSid) return;
        }
        final result = confirm
            ? await repository.request(
                sessionSlug: sessionSlug,
                requestId: _requestId,
                attemptId: _attemptId,
                connected: true,
              )
            : await repository.me(sessionSlug: sessionSlug);
        if (!_valid(generation)) return;
        _accept(result);
        if (confirm && connection.isConnected && sid == connection.localSid) {
          _confirmed = true;
          _confirmedSid = sid;
        }
        _error = null;
        if (_participant?.status != 'granting') _failures = 0;
        _retry?.cancel();
        _evaluate();
      } catch (e) {
        if (!_valid(generation)) return;
        _handleError(e, confirm: confirm);
      }
    } while (_valid(generation) && _queuedConfirm && !_terminal);
  }

  void _accept(AdmissionMeSnapshot value) {
    final me = value.me.isPresent ? value.me.value : null;
    if (value.sessionSlug != sessionSlug ||
        (me != null &&
            (me.requestId.value != _requestId ||
                me.attemptId.value != _attemptId))) {
      throw StateError('Admission snapshot does not match the current attempt');
    }
    final previous = _snapshot;
    if (previous != null &&
        (value.version < previous.version ||
            (value.version == previous.version &&
                value.observedAt.isBefore(previous.observedAt)))) {
      return;
    }
    _snapshot = value;
    if (me?.expiresAt.isPresent == true && me!.expiresAt.value != null) {
      _deadline = me.expiresAt.value;
    }
    _keeper = connection.isPresent(value.keeper)
        ? AdmissionKeeperAvailability.responsive
        : AdmissionKeeperAvailability.absent;
  }

  void _evaluate() {
    if (_disposed || !_started || _terminal) return;
    final snap = _snapshot;
    final me = _participant;
    if (snap?.roomStatus == 'ended') {
      _setStatus(AdmissionStatus.ended);
      return;
    }
    if (me != null && !me.eligible) {
      _setStatus(AdmissionStatus.denied);
      return;
    }
    final mapped = switch (me?.status) {
      'declined' ||
      'permanently_declined' ||
      'revoked' => AdmissionStatus.denied,
      'cancelled' || 'superseded' => AdmissionStatus.cancelled,
      'expired' => AdmissionStatus.expired,
      _ => null,
    };
    if (mapped != null) {
      _setStatus(mapped);
      return;
    }
    final authorized =
        me != null &&
        (me.identity == snap?.keeper || me.admissionState == 'admitted') &&
        (me.status == 'approved' || me.status == 'activated') &&
        me.permissionStatus == 'applied' &&
        me.appliedPermissionRevision.value == me.permissionRevision;
    if (authorized &&
        _confirmed &&
        connection.isConnected &&
        connection.localSid == _confirmedSid &&
        connection.hasMediaPermissions) {
      _expiration?.cancel();
      _retry?.cancel();
      _setStatus(AdmissionStatus.approved);
      if (_recovering && _mediaActivated && !_receiptSent) {
        unawaited(_activateRecovery());
      }
    } else {
      _setStatus(AdmissionStatus.pending);
      if (authorized) {
        _expiration?.cancel();
      } else {
        _scheduleExpiration();
      }
      _scheduleRetry(
        confirm: !_confirmed || connection.localSid != _confirmedSid,
        at: me?.nextRetryAt.isPresent == true ? me!.nextRetryAt.value : null,
        lowFrequency: me?.status != 'granting',
      );
    }
  }

  void _scheduleExpiration() {
    _expiration?.cancel();
    if (_terminal || _status == AdmissionStatus.approved) return;
    final deadline = _deadline;
    if (deadline == null) return;
    final delay = deadline.difference(_now());
    if (delay <= Duration.zero) {
      _setStatus(AdmissionStatus.expired);
      return;
    }
    _expiration = Timer(delay, () {
      if (!_disposed && _status == AdmissionStatus.pending) {
        _setStatus(AdmissionStatus.expired);
      }
    });
  }

  void _scheduleRetry({
    required bool confirm,
    DateTime? at,
    bool lowFrequency = false,
  }) {
    if (_disposed || _terminal || _retry?.isActive == true) return;
    final seconds = math.min(60, 2 * (1 << math.min(_failures, 5)));
    _failures++;
    var delay = Duration(seconds: lowFrequency ? 60 : seconds);
    if (at != null && at.difference(_now()) > delay) {
      delay = at.difference(_now());
    }
    _retry = Timer(delay, () {
      if (!_disposed && !_terminal) unawaited(refresh(confirm: confirm));
    });
  }

  void _handleError(Object e, {required bool confirm}) {
    _error = e;
    _confirmed = false;
    final api = e is ApiError<AdmissionMeSnapshot, ErrorSchema> ? e : null;
    final code = api?.error?.code;
    if (code == 'ended') {
      _setStatus(AdmissionStatus.ended);
      return;
    }
    if (code == 'permanently_declined' || code == 'not_eligible') {
      _setStatus(AdmissionStatus.denied);
      return;
    }
    if (api != null &&
        api.statusCode < 500 &&
        ![
          'stale_version',
          'permission_pending',
          'connection_required',
        ].contains(code)) {
      _setStatus(AdmissionStatus.failed);
      return;
    }
    _setStatus(AdmissionStatus.pending);
    _scheduleRetry(
      confirm: true,
      at: _participant?.nextRetryAt.isPresent == true
          ? _participant!.nextRetryAt.value
          : null,
    );
  }

  void _onEvent(ServerAdmissionConnectionEvent event) {
    if (_disposed || _terminal || _cancelling) return;
    if (event == ServerAdmissionConnectionEvent.terminated) {
      _generation++;
      _confirmed = false;
      _error = StateError('Waiting room connection was lost');
      _setStatus(AdmissionStatus.failed);
      return;
    }
    if (event == ServerAdmissionConnectionEvent.disconnected) {
      _generation++;
      _refreshing = null;
      _activation = null;
      _confirmed = false;
      _evaluate();
      return;
    }
    if (event == ServerAdmissionConnectionEvent.reconnected) {
      _generation++;
      _refreshing = null;
      _activation = null;
      _confirmed = false;
      if (!_recovering &&
          _receiptSent &&
          _confirmedSid != null &&
          connection.localSid != _confirmedSid) {
        _requestId = _newId();
        _attemptId = _newId();
        _snapshot = null;
        _deadline = null;
        _confirmedSid = null;
        _receiptSent = false;
        _recovering = true;
        _needsCreate = true;
      }
      _evaluate();
      unawaited(refresh(confirm: true));
      return;
    }
    if (event == ServerAdmissionConnectionEvent.presenceChanged &&
        _snapshot != null) {
      final previous = _keeper;
      _keeper = connection.isPresent(_snapshot!.keeper)
          ? AdmissionKeeperAvailability.responsive
          : AdmissionKeeperAvailability.absent;
      if (_keeper != previous) _changes.add(_status);
    }
    _evaluate();
    unawaited(refresh());
  }

  /// Call only after the parent has successfully activated local media.
  Future<void> activate() {
    _ensureAlive();
    if (_status != AdmissionStatus.approved ||
        !connection.isConnected ||
        !connection.hasMediaPermissions ||
        !_confirmed ||
        connection.localSid != _confirmedSid) {
      throw StateError('Admission is not currently authorized');
    }
    _mediaActivated = true;
    if (_receiptSent) return Future.value();
    return _activation ??= _sendActivation();
  }

  Future<void> _sendActivation() async {
    final generation = _generation;
    try {
      final result = await repository.activated(
        sessionSlug: sessionSlug,
        receipt: _receipt(),
      );
      if (!_valid(generation)) {
        throw StateError('Admission activation was superseded');
      }
      _accept(result);
      _receiptSent = true;
      _recovering = false;
      _error = null;
      _evaluate();
    } catch (e) {
      if (_valid(generation)) _handleError(e, confirm: false);
      rethrow;
    } finally {
      if (_valid(generation)) _activation = null;
    }
  }

  Future<void> _activateRecovery() async {
    try {
      await activate();
    } catch (_) {
      /* The parent can inspect error and retry. */
    }
  }

  AttemptReceiptInput _receipt() {
    final version = _participant?.attemptVersion.isPresent == true
        ? _participant!.attemptVersion.value
        : null;
    if (version == null) {
      throw StateError('No current admission attempt version');
    }
    return AttemptReceiptInput(
      requestId: _requestId,
      attemptId: _attemptId,
      expectedVersion: version,
    );
  }

  Future<void> cancel() async {
    _ensureAlive();
    if (_terminal) return;
    final generation = ++_generation;
    _cancelling = true;
    _refreshing = null;
    _activation = null;
    _retry?.cancel();
    try {
      if (_participant?.attemptVersion.value == null) {
        final current = await repository.me(sessionSlug: sessionSlug);
        if (!_valid(generation)) return;
        _accept(current);
      }
      AdmissionMeSnapshot result;
      try {
        result = await repository.cancel(
          sessionSlug: sessionSlug,
          receipt: _receipt(),
        );
      } on ApiError<AdmissionMeSnapshot, ErrorSchema> catch (e) {
        if (e.error?.code != 'stale_version' || !_valid(generation)) rethrow;
        final current = await repository.me(sessionSlug: sessionSlug);
        if (!_valid(generation)) return;
        _accept(current);
        result = await repository.cancel(
          sessionSlug: sessionSlug,
          receipt: _receipt(),
        );
      }
      if (!_valid(generation)) return;
      _accept(result);
      _evaluate();
    } catch (e) {
      if (_valid(generation)) _handleError(e, confirm: false);
      rethrow;
    } finally {
      _cancelling = false;
    }
  }

  void _setStatus(AdmissionStatus value) {
    if (_disposed || _status == value) return;
    _status = value;
    if (_terminal) {
      _retry?.cancel();
      _expiration?.cancel();
    }
    _changes.add(value);
  }

  bool _valid(int generation) =>
      !_disposed && !_terminal && generation == _generation;
  void _ensureAlive() {
    if (_disposed) throw StateError('Admission has been disposed');
  }

  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    _generation++;
    _retry?.cancel();
    _expiration?.cancel();
    await _subscription?.cancel();
    await connection.dispose();
    await _changes.close();
  }
}

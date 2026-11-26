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
  AdmissionMeSnapshot? _snapshot;
  Object? _error;
  AdmissionStatus _status = AdmissionStatus.idle;
  AdmissionKeeperAvailability _keeper = AdmissionKeeperAvailability.checking;
  StreamSubscription<ServerAdmissionConnectionEvent>? _subscription;
  Timer? _retry;
  Future<void>? _refreshing;
  Future<void>? _activation;
  Future<void>? _disposing;
  bool _queuedConfirm = false;
  bool _queuedRefresh = false;
  bool _started = false;
  bool _disposed = false;
  bool _confirmed = false;
  bool _mediaActivated = false;
  bool _receiptSent = false;

  String? _recoveryOperationId;
  Future<JoinResponse>? _recoveryJoin;
  String? _recoverySid;
  bool _readinessRecoveryAttempted = false;
  bool _cancelling = false;
  String? _confirmedSid;
  int _generation = 0;
  int _failures = 0;

  AdmissionStatus get status => _status;
  AdmissionKeeperAvailability get keeperAvailability => _keeper;
  bool get isReturningParticipant => _participant?.returning ?? false;
  bool? get sessionStartedAtAdmission =>
      _participant == null || !_participant!.status.hasAdmissionDecision
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
      final confirm =
          (_queuedConfirm || _recoveryOperationId != null) &&
          connection.isConnected;
      _queuedConfirm = false;
      _queuedRefresh = false;
      final sid = connection.localSid;
      try {
        if (_recoveryOperationId != null) {
          if (!confirm || sid != _recoverySid) return;
          final joining = _recoveryJoin ??= repository.rejoin(
            sessionSlug: sessionSlug,
            operationId: _recoveryOperationId!,
          );
          JoinResponse joined;
          try {
            joined = await joining;
          } finally {
            if (identical(_recoveryJoin, joining)) _recoveryJoin = null;
          }
          if (!_valid(generation) ||
              !connection.isConnected ||
              sid != connection.localSid) {
            return;
          }
          final admission = joined.admission.value;
          if (admission == null ||
              admission.requestId.isEmpty ||
              admission.attemptId.isEmpty) {
            throw StateError(
              'Rejoin response is missing admission attempt IDs',
            );
          }
          _requestId = admission.requestId;
          _attemptId = admission.attemptId;
          _recoveryOperationId = null;
        }
        final result = confirm
            ? await repository.request(
                sessionSlug: sessionSlug,
                requestId: _requestId,
                attemptId: _attemptId,
                connected: true,
              )
            : await repository.me(sessionSlug: sessionSlug);
        if (!_valid(generation) ||
            (confirm &&
                (!connection.isConnected || sid != connection.localSid))) {
          return;
        }
        _accept(result);
        if (confirm && connection.isConnected && sid == connection.localSid) {
          _confirmed = true;
          _confirmedSid = sid;
        }
        _error = null;
        if (result.readiness.state != ReadinessState.applyingPermissions) {
          _failures = 0;
        }
        _retry?.cancel();
        _evaluate();
      } catch (e) {
        if (!_valid(generation) ||
            (confirm &&
                (!connection.isConnected || sid != connection.localSid))) {
          return;
        }
        _handleError(e, confirm: confirm);
      }
    } while (_valid(generation) &&
        (_queuedConfirm || _queuedRefresh) &&
        !_terminal);
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
    _keeper = connection.isPresent(value.keeper)
        ? AdmissionKeeperAvailability.responsive
        : AdmissionKeeperAvailability.absent;
  }

  void _evaluate() {
    if (_disposed || !_started || _terminal) return;
    final me = _participant;
    final readiness = _snapshot?.readiness;
    final state = readiness?.state;
    final reason = readiness?.reason.value;
    if (state == ReadinessState.ended) {
      _setStatus(AdmissionStatus.ended);
      return;
    }
    if (state == ReadinessState.blocked &&
        (reason == ReadinessReason.permanentlyDeclined ||
            reason == ReadinessReason.requiresReapproval ||
            (reason == ReadinessReason.notEligible && !_mediaActivated))) {
      _setStatus(AdmissionStatus.denied);
      return;
    }
    if (state == ReadinessState.requiresNewAttempt) {
      AdmissionStatus? outcome;
      if (reason == ReadinessReason.requestPermanentlyDeclined ||
          reason == ReadinessReason.requestRevoked ||
          (reason == ReadinessReason.requestDeclined && !_mediaActivated)) {
        outcome = AdmissionStatus.denied;
      } else if (reason == ReadinessReason.requestSuperseded ||
          (reason == ReadinessReason.requestCancelled && !_mediaActivated)) {
        outcome = AdmissionStatus.cancelled;
      } else if (reason == ReadinessReason.requestExpired && !_mediaActivated) {
        outcome = AdmissionStatus.expired;
      } else if (reason == ReadinessReason.requestFailed ||
          reason == ReadinessReason.invalidRequest) {
        _error = StateError(
          'Admission requires a new attempt: ${reason?.value}',
        );
        outcome = AdmissionStatus.failed;
      }
      if (outcome != null) {
        _setStatus(outcome);
        return;
      }
    }
    if (_mediaActivated &&
        (state == ReadinessState.requiresNewAttempt ||
            state == ReadinessState.applyingPermissions) &&
        (reason == ReadinessReason.connectionRequired ||
            reason == ReadinessReason.connectionChanged) &&
        connection.isConnected) {
      if (_readinessRecoveryAttempted) {
        _error = StateError(
          'Admission reconnect recovery requires a new attempt',
        );
        _setStatus(AdmissionStatus.failed);
      } else {
        _readinessRecoveryAttempted = true;
        _confirmed = false;
        _receiptSent = false;
        _recoverySid = connection.localSid;
        _recoveryOperationId ??= _newId();
        _snapshot = null;
        _setStatus(AdmissionStatus.pending);
        unawaited(refresh(confirm: true));
      }
      return;
    }
    final authorized =
        me != null &&
        (state == ReadinessState.readyToActivate ||
            state == ReadinessState.activated) &&
        reason == null;
    if (authorized &&
        _confirmed &&
        connection.isConnected &&
        connection.localSid == _confirmedSid &&
        connection.hasMediaPermissions) {
      _retry?.cancel();
      _readinessRecoveryAttempted = false;
      _setStatus(AdmissionStatus.approved);
      if (_mediaActivated && !_receiptSent && _activation == null) {
        unawaited(_activateRecovery());
      }
    } else {
      _setStatus(AdmissionStatus.pending);
      _scheduleRetry(
        confirm: !_confirmed || connection.localSid != _confirmedSid,
        at: me?.nextRetryAt.isPresent == true ? me!.nextRetryAt.value : null,
        lowFrequency: state != ReadinessState.applyingPermissions,
      );
    }
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
    final roomApi = e is ApiError<JoinResponse, RoomErrorResponse> ? e : null;
    final roomError = roomApi?.error;
    final code =
        api?.error?.code ??
        (roomError?.detail.value == null
            ? null
            : ErrorSchemaCode.fromJson(roomError!.detail.value!));
    if (code == ErrorSchemaCode.ended ||
        roomError?.code == ErrorCode.roomAlreadyEnded) {
      _setStatus(AdmissionStatus.ended);
      return;
    }
    // Preserve legacy attempt-status error handling; these values are not
    // part of the generated error schema.
    if (roomError?.code == ErrorCode.banned ||
        code == ErrorSchemaCode.permanentlyDeclined ||
        code == ErrorSchemaCode.fromJson('revoked') ||
        (!_mediaActivated &&
            (code == ErrorSchemaCode.notEligible ||
                code == ErrorSchemaCode.fromJson('declined')))) {
      _setStatus(AdmissionStatus.denied);
      return;
    }
    if (code == ErrorSchemaCode.fromJson('superseded') ||
        (!_mediaActivated && code == ErrorSchemaCode.fromJson('cancelled'))) {
      _setStatus(AdmissionStatus.cancelled);
      return;
    }
    if (!_mediaActivated && code == ErrorSchemaCode.fromJson('expired')) {
      _setStatus(AdmissionStatus.expired);
      return;
    }

    _setStatus(AdmissionStatus.pending);
    _retry?.cancel();
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
      if (_mediaActivated &&
          (_recoverySid ?? _confirmedSid) != null &&
          connection.localSid != (_recoverySid ?? _confirmedSid)) {
        _recoverySid = connection.localSid;
        _recoveryOperationId ??= _newId();
        _snapshot = null;
        _receiptSent = false;
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
      if (_keeper == previous) return;
      _changes.add(_status);
    }
    _evaluate();
    if (_refreshing != null) _queuedRefresh = true;
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
      if (result.readiness.state != ReadinessState.activated ||
          _snapshot?.readiness.state != ReadinessState.activated) {
        throw StateError('Activation receipt was not acknowledged');
      }
      _receiptSent = true;

      _recoverySid = null;
      _error = null;
      _evaluate();
    } catch (e) {
      if (_valid(generation)) _handleError(e, confirm: false);
      rethrow;
    } finally {
      if (generation == _generation) _activation = null;
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
        if (e.error?.code != ErrorSchemaCode.staleVersion ||
            !_valid(generation)) {
          rethrow;
        }
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
    await _subscription?.cancel();
    await connection.dispose();
    await _changes.close();
  }
}

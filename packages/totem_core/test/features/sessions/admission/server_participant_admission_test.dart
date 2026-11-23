import 'dart:async';

import 'package:checks/checks.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/sessions/admission/server_participant_admission.dart';
import 'package:totem_core/features/sessions/repositories/participant_admission_repository.dart';

final time = DateTime.utc(2026);

AdmissionJoinState initial() => AdmissionJoinState.fromJson({
  'request_id': 'request',
  'attempt_id': 'attempt',
  'status': 'pending',
  'durable_state': 'pending',
  'approval_required': true,
  'expires_at': time.add(const Duration(minutes: 10)).toIso8601String(),
  'permissions': 'waiting',
  'permission_sync': 'pending',
  'revision': 1,
  'observed_at': time.toIso8601String(),
  'readiness': const {'state': 'waiting_for_approval'},
});

AdmissionMeSnapshot snapshot(
  String status, {
  String request = 'request',
  String attempt = 'attempt',
  int version = 1,
  bool eligible = true,
  String? admissionState,
  String permissionStatus = 'applied',
  int? appliedPermissionRevision = 1,
  String identity = 'guest',
  String roomStatus = 'active',
  DateTime? nextRetryAt,
  String? readinessState,
  String? readinessReason,
}) => AdmissionMeSnapshot.fromJson({
  'session_slug': 'session',
  'keeper': 'keeper',
  'room_version': 1,
  'room_state': {
    'session_slug': 'session',
    'version': 1,
    'status': roomStatus,
    'turn_state': 'idle',
    'status_detail': const {'type': 'unknown'},
    'talking_order': const <String>[],
    'keeper': 'keeper',
    'round_number': 0,
  },
  'room_status': roomStatus,
  'readiness': readinessState == null
      ? fixtureReadiness(
          status,
          eligible,
          admissionState,
          permissionStatus,
          appliedPermissionRevision,
          identity,
          roomStatus,
        )
      : {'state': readinessState, 'reason': ?readinessReason},
  'approval_required': true,
  'settings_revision': 1,
  'version': version,
  'observed_at': time.toIso8601String(),
  'admitted_count': 0,
  'activated_count': 0,
  'pending_count': 1,
  'me': {
    'identity': identity,
    'user': {
      'profile_avatar_type': 'boring',
      'date_created': time.toIso8601String(),
    },
    'admission_state':
        admissionState ??
        (status == 'approved' || status == 'activated' ? 'admitted' : 'none'),
    'admission_version': 1,
    'request_id': request,
    'attempt_id': attempt,
    'attempt_version': version,
    'status': status,
    'connection_state': 'connected',
    'eligible': eligible,
    'returning': false,
    'session_started': false,
    'late_arrival': false,
    'permission_status': permissionStatus,
    'permission_revision': 1,
    'applied_permission_revision': appliedPermissionRevision,
    if (nextRetryAt != null) 'next_retry_at': nextRetryAt.toIso8601String(),
  },
});

Map<String, String> fixtureReadiness(
  String status,
  bool eligible,
  String? durable,
  String permission,
  int? revision,
  String identity,
  String roomStatus,
) {
  if (roomStatus == 'ended') {
    return {'state': 'ended', 'reason': 'session_ended'};
  }
  if (!eligible) return {'state': 'blocked', 'reason': 'not_eligible'};
  if (identity != 'keeper' &&
      (durable == 'revoked' || durable == 'permanently_declined')) {
    return {
      'state': 'blocked',
      'reason': durable == 'revoked' ? 'requires_reapproval' : durable!,
    };
  }
  if ([
    'declined',
    'permanently_declined',
    'revoked',
    'cancelled',
    'superseded',
    'expired',
  ].contains(status)) {
    return {'state': 'requires_new_attempt', 'reason': 'request_$status'};
  }
  if (status == 'pending') {
    return {'state': 'waiting_for_approval', 'reason': 'approval_required'};
  }
  if (status != 'approved' && status != 'activated') {
    return {'state': 'future_state'};
  }
  if (identity != 'keeper' && durable != null && durable != 'admitted') {
    return {'state': 'blocked', 'reason': 'not_admitted'};
  }
  if (permission != 'applied' || revision != 1) {
    return {'state': 'applying_permissions', 'reason': 'permission_pending'};
  }
  return {'state': status == 'activated' ? 'activated' : 'ready_to_activate'};
}

class FakeRepository implements ParticipantAdmissionRepository {
  AdmissionMeSnapshot current = snapshot('pending');
  Completer<AdmissionMeSnapshot>? waiting;
  Object? requestError;
  Object? rejoinError;
  Completer<JoinResponse>? rejoinWaiting;
  final operations = <String>[];
  @override
  Future<JoinResponse> rejoin({
    required String sessionSlug,
    required String operationId,
  }) {
    operations.add(operationId);
    if (rejoinError != null) return Future.error(rejoinError!);
    final me = current.me.value!;
    return rejoinWaiting?.future ??
        Future.value(
          JoinResponse.fromJson({
            'token': 'unused',
            'is_already_present': true,
            'admission': initial()
                .copyWith(
                  requestId: me.requestId.value,
                  attemptId: me.attemptId.value,
                )
                .toJson(),
          }),
        );
  }

  int requests = 0;
  final connections = <bool>[];
  int reads = 0;
  int activations = 0;
  Completer<AdmissionMeSnapshot>? activationWaiting;
  Object? activationError;
  bool staleCancel = false;
  final cancelVersions = <int>[];
  String? lastRequest;
  String? lastAttempt;
  @override
  Future<AdmissionMeSnapshot> request({
    required String sessionSlug,
    required String requestId,
    required String attemptId,
    bool connected = false,
  }) {
    requests++;
    connections.add(connected);
    lastRequest = requestId;
    lastAttempt = attemptId;
    if (requestError != null) return Future.error(requestError!);
    return waiting?.future ?? Future.value(current);
  }

  @override
  Future<AdmissionMeSnapshot> me({required String sessionSlug}) {
    reads++;
    if (requestError != null) return Future.error(requestError!);
    return waiting?.future ?? Future.value(current);
  }

  @override
  Future<AdmissionMeSnapshot> activated({
    required String sessionSlug,
    required AttemptReceiptInput receipt,
  }) {
    activations++;
    if (activationError != null) return Future.error(activationError!);
    return activationWaiting?.future ??
        Future.value(
          current.readiness.state == ReadinessState.readyToActivate
              ? AdmissionMeSnapshot.fromJson({
                  ...current.toJson(),
                  'readiness': const {'state': 'activated'},
                })
              : current,
        );
  }

  @override
  Future<AdmissionMeSnapshot> cancel({
    required String sessionSlug,
    required AttemptReceiptInput receipt,
  }) {
    cancelVersions.add(receipt.expectedVersion);
    if (staleCancel) {
      staleCancel = false;
      return Future.error(
        const ApiError<AdmissionMeSnapshot, ErrorSchema>(
          statusCode: 409,
          error: ErrorSchema(
            code: ErrorSchemaCode.staleVersion,
            message: 'stale',
          ),
        ),
      );
    }
    return Future.value(
      snapshot('cancelled', version: receipt.expectedVersion + 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeConnection implements ServerAdmissionConnection {
  final events = StreamController<ServerAdmissionConnectionEvent>.broadcast(
    sync: true,
  );
  @override
  bool isConnected = true;
  @override
  bool hasMediaPermissions = false;
  @override
  String localSid = 'sid';
  bool keeperPresent = true;
  @override
  bool isPresent(String identity) => keeperPresent;
  @override
  Stream<ServerAdmissionConnectionEvent> get admissionEvents => events.stream;
  @override
  Future<void> dispose() => events.close();
}

void main() {
  test('server readiness overrides legacy permission and admission fields', () {
    fakeAsync((async) {
      final repo = FakeRepository()
        ..current = snapshot(
          'approved',
          readinessState: 'applying_permissions',
          readinessReason: 'connection_changed',
        );
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: FakeConnection()..hasMediaPermissions = true,
        now: () => time.add(async.elapsed),
      )..start();
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.pending);
      repo.current = snapshot(
        'pending',
        version: 2,
        permissionStatus: 'pending',
        readinessState: 'ready_to_activate',
      );
      admission.refresh();
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.approved);
      admission.dispose();
      async.flushMicrotasks();
    });
  });

  for (final reason in ['request_failed', 'invalid_request']) {
    test('$reason terminates an unusable admission attempt', () {
      fakeAsync((async) {
        final repo = FakeRepository()
          ..current = snapshot(
            'pending',
            readinessState: 'requires_new_attempt',
            readinessReason: reason,
          );
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: FakeConnection(),
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.failed);
        check(admission.error).isNotNull();
        async.elapse(const Duration(minutes: 2));
        check(repo.requests).equals(1);
        admission.dispose();
        async.flushMicrotasks();
      });
    });
  }

  for (final reason in ['connection_required', 'connection_changed']) {
    test(
      '$reason after activation retries canonical rejoin with a stable key',
      () {
        fakeAsync((async) {
          final repo = FakeRepository()..current = snapshot('approved');
          final connection = FakeConnection()..hasMediaPermissions = true;
          var id = 0;
          final admission = ServerParticipantAdmission(
            repository: repo,
            sessionSlug: 'session',
            initial: initial(),
            connection: connection,
            now: () => time.add(async.elapsed),
            newId: () => 'operation${++id}',
          )..start();
          async.flushMicrotasks();
          admission.activate();
          async.flushMicrotasks();
          repo
            ..rejoinError = TimeoutException('uncertain')
            ..current = snapshot(
              'approved',
              version: 2,
              readinessState: 'applying_permissions',
              readinessReason: reason,
            );
          admission.refresh();
          async.flushMicrotasks();
          check(admission.status).equals(AdmissionStatus.pending);
          check(repo.operations).deepEquals(['operation1']);
          repo
            ..rejoinError = null
            ..current = snapshot(
              'approved',
              request: 'new-request',
              attempt: 'new-attempt',
            );
          async.elapse(const Duration(seconds: 4));
          check(repo.operations).deepEquals(['operation1', 'operation1']);
          check(repo.lastRequest).equals('new-request');
          check(repo.lastAttempt).equals('new-attempt');
          check(admission.status).equals(AdmissionStatus.approved);
          check(repo.activations).equals(2);
          admission.dispose();
          async.flushMicrotasks();
        });
      },
    );
  }

  test(
    'persistent connection readiness after canonical rejoin fails safely',
    () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot('approved');
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: FakeConnection()..hasMediaPermissions = true,
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        admission.activate();
        async.flushMicrotasks();
        repo.current = snapshot(
          'activated',
          version: 2,
          readinessState: 'requires_new_attempt',
          readinessReason: 'connection_changed',
        );
        admission.refresh();
        async.flushMicrotasks();
        check(repo.operations.length).equals(1);
        check(admission.status).equals(AdmissionStatus.failed);
        check(admission.error).isNotNull();
        async.elapse(const Duration(minutes: 2));
        check(repo.operations.length).equals(1);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );

  test('unknown readiness and unexpected ready reasons fail closed', () {
    for (final current in [
      snapshot('approved', readinessState: 'future_state'),
      snapshot(
        'approved',
        readinessState: 'ready_to_activate',
        readinessReason: 'future_reason',
      ),
      snapshot(
        'approved',
        readinessState: 'ready_to_activate',
        readinessReason: 'permission_pending',
      ),
      snapshot(
        'approved',
        readinessState: 'blocked',
        readinessReason: 'admission_full',
      ),
      snapshot(
        'approved',
        readinessState: 'requires_new_attempt',
        readinessReason: 'connection_changed',
      ),
    ]) {
      fakeAsync((async) {
        final admission = ServerParticipantAdmission(
          repository: FakeRepository()..current = current,
          sessionSlug: 'session',
          initial: initial(),
          connection: FakeConnection()..hasMediaPermissions = true,
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        admission.dispose();
        async.flushMicrotasks();
      });
    }
  });

  test('unknown admission or permission states do not authorize admission', () {
    for (final current in [
      snapshot('approved', admissionState: 'future_state'),
      snapshot('approved', permissionStatus: 'future_permission'),
    ]) {
      fakeAsync((async) {
        final admission = ServerParticipantAdmission(
          repository: FakeRepository()..current = current,
          sessionSlug: 'session',
          initial: initial(),
          connection: FakeConnection()..hasMediaPermissions = true,
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        admission.dispose();
        async.flushMicrotasks();
      });
    }
  });

  test('unknown participant status does not authorize admission', () {
    fakeAsync((async) {
      final repo = FakeRepository()
        ..current = snapshot('future_status', admissionState: 'admitted');
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: FakeConnection()..hasMediaPermissions = true,
        now: () => time.add(async.elapsed),
      )..start();
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.pending);
      check(admission.sessionStartedAtAdmission).isNull();
      admission.dispose();
      async.flushMicrotasks();
    });
  });
  test(
    'unrelated presence avoids reads while keeper changes and revocation refresh',
    () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot('approved');
        final connection = FakeConnection()..hasMediaPermissions = true;
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        connection.events.add(ServerAdmissionConnectionEvent.presenceChanged);
        async.flushMicrotasks();
        check(repo.reads).equals(0);
        connection.keeperPresent = false;
        connection.events.add(ServerAdmissionConnectionEvent.presenceChanged);
        async.flushMicrotasks();
        check(repo.reads).equals(1);
        check(
          admission.keeperAvailability,
        ).equals(AdmissionKeeperAvailability.absent);
        repo.current = snapshot('revoked', version: 2);
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.denied);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'notification during a read refreshes again to recover a missed change',
    () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot('approved');
        final connection = FakeConnection()..hasMediaPermissions = true;
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        final waiting = Completer<AdmissionMeSnapshot>();
        repo.waiting = waiting;
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        repo
          ..waiting = null
          ..current = snapshot('revoked', version: 2);
        waiting.complete(snapshot('approved'));
        async.flushMicrotasks();
        check(repo.reads).equals(2);
        check(admission.status).equals(AdmissionStatus.denied);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );

  for (final durableState in ['revoked', 'permanently_declined']) {
    for (final identity in ['guest', 'keeper']) {
      test(
        '$durableState after activation is terminal for guests but not Keepers ($identity)',
        () {
          fakeAsync((async) {
            final repo = FakeRepository()
              ..current = snapshot('approved', identity: identity);
            final admission = ServerParticipantAdmission(
              repository: repo,
              sessionSlug: 'session',
              initial: initial(),
              connection: FakeConnection()..hasMediaPermissions = true,
              now: () => time.add(async.elapsed),
            )..start();
            async.flushMicrotasks();
            repo.activationWaiting = Completer<AdmissionMeSnapshot>();
            admission.activate().then<void>((_) {}, onError: (Object _) {});
            repo.current = snapshot(
              'activated',
              identity: identity,
              admissionState: durableState,
              version: 2,
            );
            admission.refresh();
            async.flushMicrotasks();
            final expected = identity == 'keeper'
                ? AdmissionStatus.approved
                : AdmissionStatus.denied;
            check(admission.status).equals(expected);
            repo.activationWaiting!.complete(
              snapshot('activated', identity: identity),
            );
            async
              ..flushMicrotasks()
              ..elapse(const Duration(minutes: 11));
            check(admission.status).equals(expected);
            check(repo.activations).equals(1);
            admission.dispose();
            async.flushMicrotasks();
          });
        },
      );
    }
  }

  for (final entry in {
    'revoked': AdmissionStatus.denied,
    'permanently_declined': AdmissionStatus.denied,
    'superseded': AdmissionStatus.cancelled,
  }.entries) {
    test('Keeper attempt ${entry.key} remains terminal', () {
      fakeAsync((async) {
        final repo = FakeRepository()
          ..current = snapshot('approved', identity: 'keeper');
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: FakeConnection()..hasMediaPermissions = true,
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        admission.activate();
        async.flushMicrotasks();
        repo.current = snapshot(entry.key, identity: 'keeper', version: 2);
        admission.refresh();
        async.flushMicrotasks();
        check(admission.status).equals(entry.value);
        admission.dispose();
        async.flushMicrotasks();
      });
    });
  }

  test(
    'old activation completion cannot clear a reconnect receipt in flight',
    () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot('approved');
        final connection = FakeConnection()..hasMediaPermissions = true;
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        final oldReceipt = Completer<AdmissionMeSnapshot>();
        repo.activationWaiting = oldReceipt;
        admission.activate().then<void>((_) {}, onError: (Object _) {});
        connection.isConnected = false;
        connection.events.add(ServerAdmissionConnectionEvent.disconnected);
        final newReceipt = Completer<AdmissionMeSnapshot>();
        repo.activationWaiting = newReceipt;
        connection.isConnected = true;
        connection.events.add(ServerAdmissionConnectionEvent.reconnected);
        async.flushMicrotasks();
        check(repo.activations).equals(2);
        oldReceipt.complete(snapshot('approved'));
        async.flushMicrotasks();
        admission.activate();
        async.flushMicrotasks();
        check(repo.activations).equals(2);
        newReceipt.complete(snapshot('activated', version: 2));
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.approved);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'failed activation receipt retries without a listener or overlapping calls',
    () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot('approved');
        final connection = FakeConnection()..hasMediaPermissions = true;
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        repo.activationError = const ApiError<AdmissionMeSnapshot, ErrorSchema>(
          statusCode: 404,
        );
        admission.activate().then<void>((_) {}, onError: (Object _) {});
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        check(repo.activations).equals(1);
        async.elapse(const Duration(seconds: 2));
        check(repo.activations).equals(2);
        check(admission.status).equals(AdmissionStatus.pending);
        repo
          ..activationError = null
          ..activationWaiting = Completer<AdmissionMeSnapshot>();
        async.elapse(const Duration(seconds: 2));
        check(repo.activations).equals(3);
        admission.refresh();
        async.flushMicrotasks();
        check(repo.activations).equals(3);
        repo.activationWaiting!.complete(snapshot('activated', version: 2));
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.approved);
        async.elapse(const Duration(minutes: 11));
        check(repo.activations).equals(3);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );

  for (final status in ['declined', 'cancelled', 'expired', 'not_eligible']) {
    test('$status is nonterminal after media activation', () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot('approved');
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: FakeConnection()..hasMediaPermissions = true,
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        repo.activationWaiting = Completer<AdmissionMeSnapshot>();
        admission.activate().then<void>((_) {}, onError: (Object _) {});
        repo.activationWaiting!.completeError(
          ApiError<AdmissionMeSnapshot, ErrorSchema>(
            statusCode: 409,
            error: ErrorSchema(
              code: ErrorSchemaCode.fromJson(status),
              message: 'temporary',
            ),
          ),
        );
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        repo
          ..activationWaiting = null
          ..current = snapshot(
            status == 'not_eligible' ? 'activated' : status,
            version: 2,
            eligible: status != 'not_eligible',
          );
        admission.refresh(confirm: true);
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        async.elapse(const Duration(minutes: 11));
        check(admission.status).equals(AdmissionStatus.pending);
        repo.current = snapshot('approved', version: 3);
        admission.refresh(confirm: true);
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.approved);
        check(repo.activations).equals(2);
        admission.dispose();
        async.flushMicrotasks();
      });
    });
  }

  for (final entry in {
    'revoked': AdmissionStatus.denied,
    'permanently_declined': AdmissionStatus.denied,
    'superseded': AdmissionStatus.cancelled,
    'ended': AdmissionStatus.ended,
  }.entries) {
    test(
      'authoritative ${entry.key} snapshot terminates after media activation',
      () {
        fakeAsync((async) {
          final repo = FakeRepository()..current = snapshot('approved');
          final admission = ServerParticipantAdmission(
            repository: repo,
            sessionSlug: 'session',
            initial: initial(),
            connection: FakeConnection()..hasMediaPermissions = true,
            now: () => time.add(async.elapsed),
          )..start();
          async.flushMicrotasks();
          repo.activationWaiting = Completer<AdmissionMeSnapshot>();
          admission.activate().then<void>((_) {}, onError: (Object _) {});
          repo.current = snapshot(
            entry.key == 'ended' ? 'approved' : entry.key,
            version: 2,
            roomStatus: entry.key == 'ended' ? 'ended' : 'active',
          );
          admission.refresh();
          async.flushMicrotasks();
          check(admission.status).equals(entry.value);
          repo.activationWaiting!.complete(snapshot('approved'));
          async.flushMicrotasks();
          check(admission.status).equals(entry.value);
          admission.dispose();
          async.flushMicrotasks();
        });
      },
    );
  }

  for (final entry in <ErrorSchemaCode, AdmissionStatus>{
    ErrorSchemaCode.ended: AdmissionStatus.ended,
    ErrorSchemaCode.permanentlyDeclined: AdmissionStatus.denied,
    ErrorSchemaCode.notEligible: AdmissionStatus.denied,
    ErrorSchemaCode.staleVersion: AdmissionStatus.pending,
    ErrorSchemaCode.permissionPending: AdmissionStatus.pending,
    ErrorSchemaCode.connectionRequired: AdmissionStatus.pending,
    ErrorSchemaCode.fromJson('revoked'): AdmissionStatus.denied,
    ErrorSchemaCode.fromJson('declined'): AdmissionStatus.denied,
    ErrorSchemaCode.fromJson('superseded'): AdmissionStatus.cancelled,
    ErrorSchemaCode.fromJson('cancelled'): AdmissionStatus.cancelled,
    ErrorSchemaCode.fromJson('expired'): AdmissionStatus.expired,
    ErrorSchemaCode.fromJson('future_error'): AdmissionStatus.pending,
  }.entries) {
    test('HTTP 409 ${entry.key} before activation maps conservatively', () {
      fakeAsync((async) {
        final repo = FakeRepository()
          ..requestError = ApiError<AdmissionMeSnapshot, ErrorSchema>(
            statusCode: 409,
            error: ErrorSchema(code: entry.key, message: 'error'),
          );
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: FakeConnection(),
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        check(admission.status).equals(entry.value);
        admission.dispose();
        async.flushMicrotasks();
      });
    });
  }

  for (final statusCode in [404, 429, 409]) {
    test('HTTP $statusCode while waiting retries with bounded backoff', () {
      fakeAsync((async) {
        final repo = FakeRepository()
          ..requestError = ApiError<AdmissionMeSnapshot, ErrorSchema>(
            statusCode: statusCode,
            error: statusCode == 409
                ? ErrorSchema(
                    code: ErrorSchemaCode.fromJson('future_error'),
                    message: 'unknown',
                  )
                : null,
          );
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: FakeConnection(),
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        check(admission.error).isNotNull();
        check(repo.requests).equals(1);
        async.elapse(const Duration(seconds: 1));
        check(repo.requests).equals(1);
        async.elapse(const Duration(seconds: 1));
        check(repo.requests).equals(2);
        async.elapse(const Duration(seconds: 3));
        check(repo.requests).equals(2);
        async.elapse(const Duration(seconds: 1));
        check(repo.requests).equals(3);
        async.elapse(const Duration(minutes: 3));
        check(repo.requests < 10).isTrue();
        check(admission.status).equals(AdmissionStatus.pending);
        repo.requestError = null;
        async.elapse(const Duration(minutes: 1));
        check(admission.error).isNull();
        check(admission.status).equals(AdmissionStatus.pending);
        admission.dispose();
        async.flushMicrotasks();
      });
    });
  }

  for (final statusCode in [404, 408, 409, 429, 503]) {
    test('HTTP $statusCode after activation degrades and retries', () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot('approved');
        final connection = FakeConnection()..hasMediaPermissions = true;
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        admission.activate();
        async.flushMicrotasks();
        repo.requestError = ApiError<AdmissionMeSnapshot, ErrorSchema>(
          statusCode: statusCode,
          error: ErrorSchema(
            code: ErrorSchemaCode.fromJson('unknown'),
            message: 'temporary',
          ),
        );
        admission.refresh();
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        check(admission.error).isNotNull();
        repo.requestError = null;
        async.elapse(const Duration(seconds: 2));
        check(admission.status).equals(AdmissionStatus.approved);
        check(admission.error).isNull();
        admission.dispose();
        async.flushMicrotasks();
      });
    });
  }

  test(
    'activated admission survives deadline while permissions and reconnect recover',
    () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot('approved');
        final connection = FakeConnection()..hasMediaPermissions = true;
        var id = 0;
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time.add(async.elapsed),
          newId: () => 'new${++id}',
        )..start();
        async.flushMicrotasks();
        admission.activate();
        async.flushMicrotasks();
        connection.hasMediaPermissions = false;
        repo.current = snapshot(
          'activated',
          version: 2,
          permissionStatus: 'pending',
        );
        connection.events.add(
          ServerAdmissionConnectionEvent.permissionsChanged,
        );
        async.elapse(const Duration(minutes: 11));
        check(admission.status).equals(AdmissionStatus.pending);
        connection.isConnected = false;
        connection.events.add(ServerAdmissionConnectionEvent.disconnected);
        repo.current = snapshot('approved', request: 'new1', attempt: 'new2');
        connection
          ..localSid = 'replacement'
          ..isConnected = true;
        connection.events.add(ServerAdmissionConnectionEvent.reconnected);
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        connection.hasMediaPermissions = true;
        connection.events.add(
          ServerAdmissionConnectionEvent.permissionsChanged,
        );
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.approved);
        check(repo.activations).equals(2);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );

  for (final entry in {
    'revoked': AdmissionStatus.denied,
    'permanently_declined': AdmissionStatus.denied,
    'superseded': AdmissionStatus.cancelled,
    'ended': AdmissionStatus.ended,
  }.entries) {
    test(
      'authoritative ${entry.key} error remains terminal after activation',
      () {
        fakeAsync((async) {
          final repo = FakeRepository()..current = snapshot('approved');
          final admission = ServerParticipantAdmission(
            repository: repo,
            sessionSlug: 'session',
            initial: initial(),
            connection: FakeConnection()..hasMediaPermissions = true,
            now: () => time.add(async.elapsed),
          )..start();
          async.flushMicrotasks();
          admission.activate();
          async.flushMicrotasks();
          repo.requestError = ApiError<AdmissionMeSnapshot, ErrorSchema>(
            statusCode: 409,
            error: ErrorSchema(
              code: ErrorSchemaCode.fromJson(entry.key),
              message: 'terminal',
            ),
          );
          admission.refresh();
          async.flushMicrotasks();
          check(admission.status).equals(entry.value);
          async.elapse(const Duration(minutes: 11));
          check(admission.status).equals(entry.value);
          admission.dispose();
          async.flushMicrotasks();
        });
      },
    );
  }

  test(
    'activation receipt from an old connection fails after reconnect',
    () async {
      final repo = FakeRepository()..current = snapshot('approved');
      final connection = FakeConnection()..hasMediaPermissions = true;
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: connection,
        now: () => time,
      );
      addTearDown(admission.dispose);
      await admission.start();
      check(admission.status).equals(AdmissionStatus.approved);
      repo.activationWaiting = Completer<AdmissionMeSnapshot>();
      final activation = admission.activate();
      final error = activation.then<Object?>(
        (_) => null,
        onError: (Object e) => e,
      );
      connection.isConnected = false;
      connection.events.add(ServerAdmissionConnectionEvent.disconnected);
      repo.activationWaiting!.complete(snapshot('approved'));
      check(await error is StateError).isTrue();
    },
  );

  test('recovers a lost decline notification and stops polling', () {
    fakeAsync((async) {
      final repo = FakeRepository();
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: FakeConnection(),
        now: () => time.add(async.elapsed),
      )..start();
      async.flushMicrotasks();
      repo.current = snapshot('declined', version: 2);
      async.elapse(const Duration(seconds: 59));
      check(repo.reads).equals(0);
      async.elapse(const Duration(seconds: 1));
      check(admission.status).equals(AdmissionStatus.denied);
      check(repo.reads).equals(1);
      async.elapse(const Duration(minutes: 2));
      check(repo.reads).equals(1);
      admission.dispose();
      async.flushMicrotasks();
    });
  });

  test('recovers lost approval and permission notifications', () {
    fakeAsync((async) {
      final repo = FakeRepository();
      final connection = FakeConnection();
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: connection,
        now: () => time.add(async.elapsed),
      )..start();
      async.flushMicrotasks();
      repo.current = snapshot('approved', version: 2);
      async.elapse(const Duration(minutes: 1));
      check(admission.status).equals(AdmissionStatus.pending);
      connection.hasMediaPermissions = true;
      async.elapse(const Duration(minutes: 1));
      check(admission.status).equals(AdmissionStatus.approved);
      check(repo.reads).equals(2);
      async.elapse(const Duration(minutes: 2));
      check(repo.reads).equals(2);
      admission.dispose();
      async.flushMicrotasks();
    });
  });

  test('reconnect fences an in-flight recovery response', () {
    fakeAsync((async) {
      final repo = FakeRepository();
      final connection = FakeConnection()..hasMediaPermissions = true;
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: connection,
        now: () => time.add(async.elapsed),
      )..start();
      async.flushMicrotasks();
      final oldResponse = Completer<AdmissionMeSnapshot>();
      repo.waiting = oldResponse;
      async.elapse(const Duration(minutes: 1));
      connection.isConnected = false;
      connection.events.add(ServerAdmissionConnectionEvent.disconnected);
      repo.waiting = null;
      connection
        ..localSid = 'new-sid'
        ..isConnected = true;
      connection.events.add(ServerAdmissionConnectionEvent.reconnected);
      async.flushMicrotasks();
      oldResponse.complete(snapshot('approved', version: 2));
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.pending);
      check(admission.snapshot!.version).equals(1);
      admission.dispose();
      async.flushMicrotasks();
    });
  });

  test('recovery honors nextRetryAt and disposal cancels it', () {
    fakeAsync((async) {
      final repo = FakeRepository()
        ..current = snapshot(
          'pending',
          nextRetryAt: time.add(const Duration(minutes: 2)),
        );
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: FakeConnection(),
        now: () => time.add(async.elapsed),
      )..start();
      async
        ..flushMicrotasks()
        ..elapse(const Duration(minutes: 1));
      check(repo.reads).equals(0);
      admission.dispose();
      async
        ..flushMicrotasks()
        ..elapse(const Duration(minutes: 2));
      check(repo.reads).equals(0);
    });
  });

  test(
    'HTTP approval and current permissions are both required in either order',
    () {
      fakeAsync((async) {
        final repo = FakeRepository();
        final connection = FakeConnection();
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time,
        )..start();
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        connection.hasMediaPermissions = true;
        connection.events.add(
          ServerAdmissionConnectionEvent.permissionsChanged,
        );
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        repo.current = snapshot('approved', version: 2);
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.approved);
        connection.hasMediaPermissions = false;
        connection.events.add(
          ServerAdmissionConnectionEvent.permissionsChanged,
        );
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        connection.hasMediaPermissions = true;
        connection.events.add(
          ServerAdmissionConnectionEvent.permissionsChanged,
        );
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.approved);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );

  test('an ineligible participant with an old activated attempt is denied', () {
    fakeAsync((async) {
      final repo = FakeRepository()
        ..current = snapshot('activated', eligible: false);
      final connection = FakeConnection()..hasMediaPermissions = true;
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: connection,
        now: () => time,
      )..start();
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.denied);
      check(repo.activations).equals(0);
      admission.dispose();
      async.flushMicrotasks();
    });
  });

  test('permission journal must be applied at the current revision', () {
    fakeAsync((async) {
      final repo = FakeRepository()
        ..current = snapshot('activated', permissionStatus: 'pending');
      final connection = FakeConnection()..hasMediaPermissions = true;
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: connection,
        now: () => time,
      )..start();
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.pending);
      repo.current = snapshot(
        'activated',
        version: 2,
        appliedPermissionRevision: 0,
      );
      admission.refresh();
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.pending);
      repo.current = snapshot('activated', version: 3);
      admission.refresh();
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.approved);
      admission.dispose();
      async.flushMicrotasks();
    });
  });

  test(
    'an activated non-member is not admitted, but the current Keeper is',
    () {
      fakeAsync((async) {
        final repo = FakeRepository()
          ..current = snapshot('activated', admissionState: 'none');
        final connection = FakeConnection()..hasMediaPermissions = true;
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time,
        )..start();
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
        repo.current = snapshot(
          'activated',
          version: 2,
          admissionState: 'none',
          identity: 'keeper',
        );
        admission.refresh();
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.approved);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );

  test('termination fences a late approval and ignores further events', () {
    fakeAsync((async) {
      final repo = FakeRepository()..waiting = Completer<AdmissionMeSnapshot>();
      final connection = FakeConnection()..hasMediaPermissions = true;
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: connection,
        now: () => time.add(async.elapsed),
      )..start();
      async.flushMicrotasks();
      connection.events.add(ServerAdmissionConnectionEvent.terminated);
      check(admission.status).equals(AdmissionStatus.failed);
      check(admission.error).isNotNull();
      repo.waiting!.complete(snapshot('approved'));
      async.flushMicrotasks();
      connection.events.add(ServerAdmissionConnectionEvent.reconnected);
      connection.events.add(ServerAdmissionConnectionEvent.notification);
      async.elapse(const Duration(minutes: 11));
      check(admission.status).equals(AdmissionStatus.failed);
      check(admission.snapshot).isNull();
      check(repo.requests).equals(1);
      check(repo.reads).equals(0);
      check(repo.activations).equals(0);
      admission.dispose();
      async.flushMicrotasks();
    });
  });

  test(
    'cancel before initial snapshot fetches a receipt and fences the old response',
    () {
      fakeAsync((async) {
        final pending = Completer<AdmissionMeSnapshot>();
        final repo = FakeRepository()..waiting = pending;
        final connection = FakeConnection()..hasMediaPermissions = true;
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time,
        )..start();
        async.flushMicrotasks();
        repo
          ..waiting = null
          ..current = snapshot('pending', version: 3);
        admission.cancel();
        async.flushMicrotasks();
        check(repo.reads).equals(1);
        check(repo.cancelVersions).deepEquals([3]);
        check(admission.status).equals(AdmissionStatus.cancelled);
        pending.complete(snapshot('approved', version: 4));
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.cancelled);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'duplicate hints coalesce and disposal fences an outstanding response',
    () {
      fakeAsync((async) {
        final repo = FakeRepository();
        final connection = FakeConnection();
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time,
        )..start();
        async.flushMicrotasks();
        repo.waiting = Completer<AdmissionMeSnapshot>();
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        connection.events.add(ServerAdmissionConnectionEvent.notification);
        check(repo.reads).equals(1);
        admission.dispose();
        async.flushMicrotasks();
        repo.waiting!.complete(snapshot('approved', version: 2));
        async.flushMicrotasks();
        check(admission.status).equals(AdmissionStatus.pending);
      });
    },
  );

  for (final entry in {
    'declined': AdmissionStatus.denied,
    'permanently_declined': AdmissionStatus.denied,
    'revoked': AdmissionStatus.denied,
    'cancelled': AdmissionStatus.cancelled,
    'superseded': AdmissionStatus.cancelled,
    'expired': AdmissionStatus.expired,
  }.entries) {
    test('terminal ${entry.key} is mapped correctly', () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot(entry.key);
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: FakeConnection(),
          now: () => time,
        )..start();
        async.flushMicrotasks();
        check(admission.status).equals(entry.value);
        admission.dispose();
        async.flushMicrotasks();
      });
    });
  }

  test(
    'cancel refreshes a stale receipt once and uses the new attempt version',
    () {
      fakeAsync((async) {
        final repo = FakeRepository();
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: FakeConnection(),
          now: () => time,
        )..start();
        async.flushMicrotasks();
        repo
          ..current = snapshot('pending', version: 2)
          ..staleCancel = true;
        admission.cancel();
        async.flushMicrotasks();
        check(repo.cancelVersions).deepEquals([1, 2]);
        check(admission.status).equals(AdmissionStatus.cancelled);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );

  test('local deadline does not fence a late server approval', () {
    fakeAsync((async) {
      final repo = FakeRepository()..waiting = Completer<AdmissionMeSnapshot>();
      final connection = FakeConnection()..hasMediaPermissions = true;
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: connection,
        now: () => time.add(async.elapsed),
      )..start();
      async
        ..flushMicrotasks()
        ..elapse(const Duration(minutes: 10));
      check(admission.status).equals(AdmissionStatus.pending);
      repo.waiting!.complete(snapshot('approved'));
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.approved);
      check(admission.snapshot).isNotNull();
      admission.dispose();
      async.flushMicrotasks();
    });
  });

  test('older HTTP snapshots cannot reverse approval', () {
    fakeAsync((async) {
      final repo = FakeRepository()..current = snapshot('approved', version: 2);
      final connection = FakeConnection()..hasMediaPermissions = true;
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: connection,
        now: () => time,
      )..start();
      async.flushMicrotasks();
      repo.current = snapshot('declined');
      admission.refresh();
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.approved);
      admission.dispose();
      async.flushMicrotasks();
    });
  });

  test('replacement SID retries a timed out join with the same operation', () {
    fakeAsync((async) {
      final repo = FakeRepository()..current = snapshot('approved');
      final connection = FakeConnection()..hasMediaPermissions = true;
      var id = 0;
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: connection,
        now: () => time.add(async.elapsed),
        newId: () => 'operation${++id}',
      )..start();
      async.flushMicrotasks();
      admission.activate();
      async.flushMicrotasks();
      repo.rejoinError = TimeoutException('uncertain');
      connection.localSid = 'new-sid';
      connection.events.add(ServerAdmissionConnectionEvent.reconnected);
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.pending);
      check(repo.operations).deepEquals(['operation1']);
      repo
        ..rejoinError = null
        ..current = snapshot(
          'approved',
          request: 'server-request',
          attempt: 'server-attempt',
        );
      async.elapse(const Duration(seconds: 4));
      check(repo.operations).deepEquals(['operation1', 'operation1']);
      check(repo.lastRequest).equals('server-request');
      check(repo.lastAttempt).equals('server-attempt');
      check(admission.status).equals(AdmissionStatus.approved);
      check(repo.activations).equals(2);
      admission.dispose();
      async.flushMicrotasks();
    });
  });

  test('a SID change during an uncertain join retries the same operation', () {
    fakeAsync((async) {
      final repo = FakeRepository()..current = snapshot('approved');
      final connection = FakeConnection()..hasMediaPermissions = true;
      var id = 0;
      final admission = ServerParticipantAdmission(
        repository: repo,
        sessionSlug: 'session',
        initial: initial(),
        connection: connection,
        now: () => time.add(async.elapsed),
        newId: () => 'operation${++id}',
      )..start();
      async.flushMicrotasks();
      admission.activate();
      async.flushMicrotasks();
      final old = Completer<JoinResponse>();
      repo.rejoinWaiting = old;
      connection.localSid = 'sid-2';
      connection.events.add(ServerAdmissionConnectionEvent.reconnected);
      async.flushMicrotasks();
      connection.localSid = 'sid-3';
      connection.events.add(ServerAdmissionConnectionEvent.reconnected);
      async.flushMicrotasks();
      check(repo.operations).deepEquals(['operation1']);
      repo
        ..rejoinWaiting = null
        ..current = snapshot(
          'approved',
          request: 'canonical-request',
          attempt: 'canonical-attempt',
        );
      old.completeError(TimeoutException('uncertain'));
      async.flushMicrotasks();
      check(admission.status).equals(AdmissionStatus.pending);
      async.elapse(const Duration(seconds: 8));
      check(repo.operations).deepEquals(['operation1', 'operation1']);
      check(repo.lastRequest).equals('canonical-request');
      check(repo.lastAttempt).equals('canonical-attempt');
      check(repo.activations).equals(2);
      check(admission.status).equals(AdmissionStatus.approved);
      admission.dispose();
      async.flushMicrotasks();
    });
  });

  for (final entry in {
    'ended': AdmissionStatus.ended,
    'permanently_declined': AdmissionStatus.denied,
  }.entries) {
    test('rejoin maps authoritative ${entry.key} room errors', () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot('approved');
        final connection = FakeConnection()..hasMediaPermissions = true;
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time.add(async.elapsed),
        )..start();
        async.flushMicrotasks();
        admission.activate();
        async.flushMicrotasks();
        repo.rejoinError = ApiError<JoinResponse, RoomErrorResponse>(
          statusCode: 409,
          error: RoomErrorResponse.fromJson({
            'code': entry.key == 'ended'
                ? 'room_already_ended'
                : 'not_joinable',
            'message': 'rejected',
            'detail': entry.key,
          }),
        );
        connection.localSid = 'new-sid';
        connection.events.add(ServerAdmissionConnectionEvent.reconnected);
        async.flushMicrotasks();
        check(admission.status).equals(entry.value);
        admission.dispose();
        async.flushMicrotasks();
      });
    });
  }

  test(
    'a newer SID waits for the in-flight canonical join before confirming',
    () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot('approved');
        final connection = FakeConnection()..hasMediaPermissions = true;
        var id = 0;
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time.add(async.elapsed),
          newId: () => 'operation${++id}',
        )..start();
        async.flushMicrotasks();
        admission.activate();
        async.flushMicrotasks();
        final old = Completer<JoinResponse>();
        repo.rejoinWaiting = old;
        connection.localSid = 'sid-2';
        connection.events.add(ServerAdmissionConnectionEvent.reconnected);
        async.flushMicrotasks();
        repo
          ..rejoinWaiting = null
          ..current = snapshot(
            'approved',
            request: 'current-request',
            attempt: 'current-attempt',
          );
        connection.localSid = 'sid-3';
        connection.events.add(ServerAdmissionConnectionEvent.reconnected);
        async.flushMicrotasks();
        check(repo.operations).deepEquals(['operation1']);
        check(repo.activations).equals(1);
        old.complete(
          JoinResponse.fromJson({
            'token': 'unused',
            'is_already_present': true,
            'admission': initial()
                .copyWith(
                  requestId: 'current-request',
                  attemptId: 'current-attempt',
                )
                .toJson(),
          }),
        );
        async.flushMicrotasks();
        check(repo.operations).deepEquals(['operation1']);
        check(repo.lastRequest).equals('current-request');
        check(repo.lastAttempt).equals('current-attempt');
        check(repo.activations).equals(2);
        check(admission.status).equals(AdmissionStatus.approved);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'activation is not duplicated on same SID; replacement SID uses new IDs',
    () {
      fakeAsync((async) {
        final repo = FakeRepository()..current = snapshot('approved');
        final connection = FakeConnection()..hasMediaPermissions = true;
        var id = 0;
        final admission = ServerParticipantAdmission(
          repository: repo,
          sessionSlug: 'session',
          initial: initial(),
          connection: connection,
          now: () => time,
          newId: () => 'new${++id}',
        )..start();
        async.flushMicrotasks();
        admission.activate();
        async.flushMicrotasks();
        admission.activate();
        async.flushMicrotasks();
        check(repo.activations).equals(1);
        connection.events.add(ServerAdmissionConnectionEvent.reconnected);
        async.flushMicrotasks();
        check(repo.activations).equals(1);
        repo.current = snapshot(
          'approved',
          request: 'new1',
          attempt: 'new2',
          version: 2,
        );
        connection.localSid = 'replacement';
        connection.events.add(ServerAdmissionConnectionEvent.reconnected);
        async.flushMicrotasks();
        check(repo.connections).deepEquals([true, true, true]);
        check(repo.operations).deepEquals(['new1']);
        check(repo.lastRequest).equals('new1');
        check(repo.lastAttempt).equals('new2');
        check(repo.activations).equals(2);
        admission.dispose();
        async.flushMicrotasks();
      });
    },
  );
}

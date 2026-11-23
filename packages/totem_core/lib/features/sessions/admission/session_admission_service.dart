import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';

import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

import 'package:totem_core/features/sessions/repositories/keeper_admission_repository.dart';
import 'package:totem_core/features/sessions/repositories/participant_admission_repository.dart';

import 'package:totem_core/features/sessions/services/session_packet_router.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';
import 'package:uuid/uuid.dart';

/// Session-owned coordinator for Django admission; it does not own the UI.
class SessionAdmissionService extends ChangeNotifier {
  SessionAdmissionService(this.ref, this.session, {this.now});

  final Ref ref;
  final SessionController session;
  final DateTime Function()? now;

  AdmissionSnapshot? _snapshot;
  AdmissionMeSnapshot? _meSnapshot;
  AdmissionSnapshot? get snapshot {
    final room = session.transport;
    return mounted &&
            !_disconnecting &&
            _authorityCurrent &&
            room != null &&
            room.localIdentity == session.admissionState.roomState.keeper
        ? _snapshot
        : null;
  }

  List<Participant> get requests =>
      List.unmodifiable(snapshot?.waiting ?? const []);
  List<Participant> get attempts =>
      List.unmodifiable(snapshot?.requests ?? const []);
  List<Participant> get declined => List.unmodifiable(
    snapshot?.participants.where(
          (p) =>
              p.admissionState == ParticipantAdmissionState.permanentlyDeclined,
        ) ??
        const <Participant>[],
  );
  bool get approvalRequired {
    if (!mounted || _disconnecting || !_authorityCurrent) return true;
    final state = session.admissionState.roomState;
    final keeperSnapshot = snapshot;
    if (keeperSnapshot != null &&
        keeperSnapshot.roomVersion == state.version &&
        keeperSnapshot.roomState.version == state.version &&
        keeperSnapshot.roomState.sessionSlug == _slug &&
        keeperSnapshot.roomState.keeper == state.keeper &&
        keeperSnapshot.roomStatus == keeperSnapshot.roomState.status &&
        keeperSnapshot.roomStatus != RoomStatus.ended) {
      return keeperSnapshot.approvalRequired;
    }
    final me = _meSnapshot;
    if (me != null &&
        me.keeper == state.keeper &&
        me.roomVersion == state.version &&
        me.roomState.keeper == state.keeper) {
      return me.approvalRequired;
    }
    return true;
  }

  bool _busy = false;
  bool get busy => _busy;

  /// Whether the current Keeper has a command whose outcome is unknown.
  bool get hasUnresolvedCommand {
    final keeper = session.admissionState.roomState.keeper;
    return mounted &&
        !_disconnecting &&
        (!_busy || !_authorityCurrent) &&
        keeper == _authorityKeeper &&
        session.transport?.localIdentity == keeper &&
        _pending.containsKey(keeper);
  }

  String? error;
  bool _closed = false;
  bool _disconnecting = false;
  bool get mounted => !_closed;
  Set<String> _admittedIdentities = const {};
  Set<String> get admittedIdentities =>
      mounted && !_disconnecting && _authorityCurrent
      ? _admittedIdentities
      : const {};

  bool _recipientsCurrent = false;
  Set<String>? get serverDataRecipients {
    return mounted && !_disconnecting && _authorityCurrent && _recipientsCurrent
        ? _admittedIdentities
        : null;
  }

  Future<void> _queue = Future.value();
  Future<void> get synchronized => _queue;
  int _generation = 0;
  bool _refreshQueued = false;
  Timer? _presenceRefresh;
  Future<void>? _closing;
  final Map<String, _PendingCommand> _pending = {};
  final Set<String> _queuedActions = {};
  bool _authorityObserved = false;
  SessionTransport? _authorityRoom;
  String? _authorityKeeper;
  String? _authorityLocal;

  bool get _authorityCurrent =>
      _authorityObserved &&
      identical(session.transport, _authorityRoom) &&
      session.admissionState.roomState.keeper == _authorityKeeper &&
      session.transport?.localIdentity == _authorityLocal;

  KeeperAdmissionRepository get _keeperRepository =>
      ref.read(keeperAdmissionRepositoryProvider);
  ParticipantAdmissionRepository get _participantRepository =>
      ref.read(participantAdmissionRepositoryProvider);
  String get _slug => session.options.sessionSlug;

  bool _current(int generation, SessionTransport room, String keeper) =>
      !_observeAuthority() &&
      mounted &&
      !_disconnecting &&
      generation == _generation &&
      identical(session.transport, room) &&
      session.admissionState.roomState.keeper == keeper &&
      session.admissionState.connectionState == RoomConnectionState.connected &&
      session.session?.ended != true;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _notify() {
    if (mounted) notifyListeners();
  }

  void _clearProjection() {
    _recipientsCurrent = false;
    _admittedIdentities = const {};
    session.updateAdmittedMediaRecipients(_admittedIdentities);
  }

  bool _observeAuthority() {
    if (!mounted || _disconnecting) return false;
    final room = session.transport;
    final keeper = session.admissionState.roomState.keeper;
    final local = room?.localIdentity;
    final changed =
        _authorityObserved &&
        (!identical(room, _authorityRoom) ||
            keeper != _authorityKeeper ||
            local != _authorityLocal);
    final previousKeeper = _authorityKeeper;
    _authorityObserved = true;
    _authorityRoom = room;
    _authorityKeeper = keeper;
    _authorityLocal = local;
    if (changed) {
      _generation++;
      _refreshQueued = false;
      _snapshot = null;
      _meSnapshot = null;
      if (keeper != previousKeeper || (local != null && local != keeper)) {
        _pending.clear();
      }
      _busy = false;
      _clearProjection();
    }
    return changed;
  }

  void sync() {
    final changed = _observeAuthority();
    if (changed) _notify();
    if (!mounted || _disconnecting || _refreshQueued) return;
    _refreshQueued = true;
    _recipientsCurrent = false;
    final generation = _generation;
    unawaited(
      _enqueue(() async {
        _refreshQueued = false;
        if (generation != _generation || !mounted || _disconnecting) return;
        try {
          await _refresh(generation);
        } catch (failure) {
          if (mounted && generation == _generation) {
            _snapshot = null;
            _meSnapshot = null;
            _clearProjection();
            error = 'Could not refresh admission: $failure';
            _notify();
          }
        }
      }),
    );
  }

  Future<void> _refresh(int generation) async {
    final room = session.transport;
    if (room == null ||
        !mounted ||
        _disconnecting ||
        generation != _generation ||
        session.admissionState.connectionState !=
            RoomConnectionState.connected ||
        session.session?.ended == true) {
      _snapshot = null;
      _meSnapshot = null;
      _clearProjection();
      _notify();
      return;
    }
    final keeper = session.admissionState.roomState.keeper;
    if (keeper.isEmpty || !_current(generation, room, keeper)) {
      _snapshot = null;
      _clearProjection();
      throw StateError('Room Keeper is not synchronized');
    }
    final local = room.localIdentity;
    if (local == null || local.isEmpty) {
      throw StateError('Local identity unavailable');
    }
    if (local == keeper) {
      AdmissionSnapshot data;
      try {
        data = await _keeperRepository.snapshot(sessionSlug: _slug);
      } on ApiError<AdmissionSnapshot, ErrorSchema> catch (failure) {
        if (failure.statusCode != 403 || !_current(generation, room, keeper)) {
          rethrow;
        }
        _snapshot = null;
        _meSnapshot = null;
        _clearProjection();
        _notify();
        final me = await _participantRepository.me(sessionSlug: _slug);
        if (!_current(generation, room, keeper)) return;
        if (me.keeper == keeper) {
          throw StateError('Keeper admission access denied');
        }
        _applySnapshotProjection(
          room,
          keeper,
          me.sessionSlug,
          me.keeper,
          me.roomVersion,
          me.roomState,
          me.roomStatus,
          me.presenceError.value,
          me.admittedRecipients.value,
        );
        if (!_current(generation, room, keeper)) return;
        throw StateError('Keeper admission access denied');
      }
      if (!_current(generation, room, keeper)) return;
      final old = _snapshot;
      if (old != null &&
          old.keeper == data.keeper &&
          (data.version < old.version ||
              (data.version == old.version &&
                  data.observedAt.isBefore(old.observedAt)))) {
        _clearProjection();
        throw StateError('Admission snapshot is stale');
      }
      _applySnapshotProjection(
        room,
        keeper,
        data.sessionSlug,
        data.keeper,
        data.roomVersion,
        data.roomState,
        data.roomStatus,
        data.presenceError.value,
        data.admittedRecipients.value,
      );
      if (!_current(generation, room, keeper)) return;
      _acceptSnapshot(data);
    } else {
      final data = await _participantRepository.me(sessionSlug: _slug);
      if (!_current(generation, room, keeper)) return;
      _applySnapshotProjection(
        room,
        keeper,
        data.sessionSlug,
        data.keeper,
        data.roomVersion,
        data.roomState,
        data.roomStatus,
        data.presenceError.value,
        data.admittedRecipients.value,
      );
      if (!_current(generation, room, keeper)) return;
      _snapshot = null;
      _meSnapshot = data;
    }
    error = !_pending.containsKey(keeper)
        ? null
        : 'A previous admission command has an unknown outcome; retry it before making another change.';
    _notify();
  }

  void _applySnapshotProjection(
    SessionTransport room,
    String keeper,
    String slug,
    String snapshotKeeper,
    int roomVersion,
    RoomState state,
    RoomStatus status,
    String? presenceError,
    List<String>? recipients,
  ) {
    if (slug != _slug ||
        state.sessionSlug != _slug ||
        snapshotKeeper.isEmpty ||
        state.keeper != snapshotKeeper ||
        (snapshotKeeper != keeper &&
            roomVersion <= session.admissionState.roomState.version) ||
        state.version != roomVersion ||
        roomVersion < session.admissionState.roomState.version ||
        status != state.status ||
        status == RoomStatus.ended) {
      _snapshot = null;
      _clearProjection();
      throw StateError('Admission and room state do not agree');
    }
    final generation = _generation;
    if (state.version > session.admissionState.roomState.version) {
      session.applyRoomState(state);
    }
    if (snapshotKeeper != keeper &&
        session.admissionState.roomState.keeper == snapshotKeeper) {
      sync();
      return;
    }
    if (!_current(generation, room, keeper)) return;
    if (presenceError != null || recipients == null) {
      _clearProjection();
      return;
    }
    final connected = {
      if (room.localIdentity != null) room.localIdentity!,
      ...room.participants.map((participant) => participant.identity),
    };
    _setRecipients(recipients.toSet().intersection(connected)..remove(''));
  }

  void _acceptSnapshot(AdmissionSnapshot data) {
    final old = _snapshot;
    if (old != null &&
        old.keeper == data.keeper &&
        (data.version < old.version ||
            (data.version == old.version &&
                data.observedAt.isBefore(old.observedAt)))) {
      return;
    }
    _snapshot = data;
    _meSnapshot = null;
  }

  void _setRecipients(Set<String> identities) {
    _admittedIdentities = Set.unmodifiable(identities);
    session.updateAdmittedMediaRecipients(_admittedIdentities);
    _recipientsCurrent = true;
  }

  void handleTransportEvent(SessionTransportEvent event) {
    if (event is TransportParticipantChanged) {
      if (!mounted || _disconnecting) return;
      if (!_authorityCurrent ||
          event.participant.identity ==
              session.admissionState.roomState.keeper) {
        sync();
      } else {
        _recipientsCurrent = false;
        _presenceRefresh ??= Timer(const Duration(seconds: 1), () {
          _presenceRefresh = null;
          sync();
        });
      }
      return;
    }
    if (event is TransportConnectionChanged ||
        event is TransportMetadataChanged ||
        (event is TransportPacketReceived &&
            event.packet.topic == SessionCommunicationTopics.admission.topic)) {
      sync();
    }
  }

  bool _uncertain(Object failure) =>
      failure is AppNetworkException ||
      (failure is ApiError && failure.statusCode >= 500);

  Future<bool> _runCommand(
    String key,
    Future<AdmissionCommandResponse> Function(AdmissionSnapshot) create, {
    bool retryOnly = false,
  }) {
    if (_observeAuthority()) _notify();
    if (!_queuedActions.add(key)) return Future.value(false);
    final generation = _generation;
    final room = session.transport;
    final keeper = session.admissionState.roomState.keeper;
    return _enqueue(() async {
      if (room == null ||
          !_current(generation, room, keeper) ||
          room.localIdentity != keeper) {
        if (mounted) {
          error = 'Only the current Keeper can change admission.';
          _notify();
        }
        return false;
      }
      _busy = true;
      _notify();
      try {
        final pending = _pending[keeper];
        if (pending != null) {
          if (pending.keeper != keeper || (!retryOnly && pending.key != key)) {
            error =
                'A previous admission command has an unknown outcome; retry that action first.';
            return false;
          }
          return await _execute(pending, generation, room, keeper);
        }
        if (retryOnly) {
          error = 'No unresolved admission command to retry.';
          return false;
        }
        try {
          await _refresh(generation);
        } catch (_) {
          if (_current(generation, room, keeper)) {
            _snapshot = null;
            _clearProjection();
          }
          rethrow;
        }
        if (!_current(generation, room, keeper) ||
            room.localIdentity != keeper) {
          return false;
        }
        final current = _snapshot;
        if (current == null || current.keeper != keeper) {
          throw StateError('Keeper admission snapshot unavailable');
        }
        // The closure captures the exact generated body and command ID.
        final command = _PendingCommand(key, keeper, () => create(current));
        return await _execute(command, generation, room, keeper);
      } catch (failure) {
        if (_current(generation, room, keeper)) {
          error = 'Could not update admission: $failure';
        }
        return false;
      } finally {
        if (mounted && generation == _generation) {
          _busy = false;
          _notify();
        }
      }
    }).whenComplete(() => _queuedActions.remove(key));
  }

  Future<bool> _execute(
    _PendingCommand command,
    int generation,
    SessionTransport room,
    String keeper,
  ) async {
    _pending[keeper] = command;
    try {
      final response = await command.send();
      if (!_current(generation, room, keeper) || room.localIdentity != keeper) {
        return false;
      }
      _pending.remove(keeper);
      if (response.snapshot.sessionSlug != _slug ||
          response.snapshot.keeper != keeper) {
        _snapshot = null;
        _clearProjection();
        throw StateError('Keeper changed during admission command');
      }
      _acceptSnapshot(response.snapshot);
      final details = <String>[];
      for (final result in response.results) {
        final participant = result.participant.value;
        final issue = result.error.value?.value ?? participant?.lastError.value;
        if (issue != null && issue.isNotEmpty) {
          details.add('${result.identity.value ?? 'participant'}: $issue');
        }
      }
      error = response.partialFailure
          ? 'Admission partially failed${details.isEmpty ? '; permission work is unresolved' : ': ${details.join('; ')}'}'
          : null;
      // Refresh the room projection after a command without hiding partial failures.
      final commandError = error;
      try {
        await _refresh(generation);
      } catch (failure) {
        if (_current(generation, room, keeper)) {
          _snapshot = null;
          _clearProjection();
          error =
              '${commandError == null ? '' : '$commandError; '}Could not refresh room state: $failure';
        }
        return false;
      }
      if (!_current(generation, room, keeper)) return false;
      error = commandError;
      return !response.partialFailure;
    } catch (failure) {
      if (_current(generation, room, keeper)) {
        if (!_uncertain(failure)) _pending.remove(keeper);
        error = _uncertain(failure)
            ? 'Admission outcome unknown; retry the same action: $failure'
            : 'Could not update admission: $failure';
      }
      return false;
    }
  }

  /// Retry an uncertain command with its original ID and payload.
  Future<bool> retryUnresolved() => _runCommand(
    'retry-unresolved',
    (_) => throw StateError('No unresolved admission command to retry'),
    retryOnly: true,
  );

  Future<void> decide(
    Participant participant,
    bool approve, {
    bool permanently = false,
  }) async {
    final key =
        'decision:${participant.identity}:${participant.requestId.value}:${participant.attemptId.value}:$approve:$permanently';
    final id = const Uuid().v4();
    await _runCommand(key, (snapshot) {
      final match = snapshot.waiting.where(
        (p) =>
            p.identity == participant.identity &&
            p.requestId.value == participant.requestId.value &&
            p.attemptId.value == participant.attemptId.value,
      );
      if (match.isEmpty) throw StateError('This request is no longer waiting');
      final current = match.first;
      final requestId = current.requestId.value;
      final attemptId = current.attemptId.value;
      final version = current.attemptVersion.value;
      if (requestId == null || attemptId == null || version == null) {
        throw StateError('Request versions unavailable');
      }
      if (approve) {
        return _keeperRepository.approve(
          sessionSlug: _slug,
          identity: current.identity,
          body: KeeperDecisionInput(
            commandId: id,
            requestId: requestId,
            attemptId: attemptId,
            expectedVersion: version,
            expectedRoomVersion: snapshot.roomVersion,
          ),
        );
      }
      return _keeperRepository.decline(
        sessionSlug: _slug,
        identity: current.identity,
        body: DeclineInput(
          commandId: id,
          requestId: requestId,
          attemptId: attemptId,
          expectedVersion: version,
          expectedRoomVersion: snapshot.roomVersion,
          permanent: permanently,
        ),
      );
    });
  }

  Future<bool> admitAll() {
    final id = const Uuid().v4();
    return _runCommand(
      'admit-all',
      (snapshot) => _keeperRepository.admitAll(
        sessionSlug: _slug,
        body: BatchCommandInput(
          commandId: id,
          expectedRoomVersion: snapshot.roomVersion,
        ),
      ),
    );
  }

  Future<void> setApprovalRequired(bool value) async {
    final id = const Uuid().v4();
    await _runCommand(
      'settings:$value',
      (snapshot) => _keeperRepository.settings(
        sessionSlug: _slug,
        body: SettingsCommandInput(
          commandId: id,
          approvalRequired: value,
          expectedRevision: snapshot.settingsRevision,
          expectedRoomVersion: snapshot.roomVersion,
        ),
      ),
    );
  }

  Future<void> allow(Participant participant) async {
    final id = const Uuid().v4();
    await _runCommand('allow:${participant.identity}', (snapshot) {
      final matches = snapshot.participants.where(
        (p) =>
            p.identity == participant.identity &&
            p.admissionState == ParticipantAdmissionState.permanentlyDeclined,
      );
      if (matches.isEmpty) {
        throw StateError('Participant is no longer permanently declined');
      }
      return _keeperRepository.allow(
        sessionSlug: _slug,
        identity: participant.identity,
        body: MembershipCommandInput(
          commandId: id,
          expectedVersion: matches.first.admissionVersion,
          expectedRoomVersion: snapshot.roomVersion,
        ),
      );
    });
  }

  Future<void> disconnect() async {
    if (!mounted || _disconnecting) return;
    _disconnecting = true;
    _presenceRefresh?.cancel();
    _presenceRefresh = null;
    _generation++;
    _refreshQueued = false;
    _snapshot = null;
    _meSnapshot = null;
    _busy = false;
    _clearProjection();
    _notify();
    await _queue;
    if (mounted) _disconnecting = false;
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    if (!mounted) return;
    _closed = true;
    _presenceRefresh?.cancel();
    _presenceRefresh = null;
    _generation++;
    _recipientsCurrent = false;
    await _queue;
    super.dispose();
  }
}

class _PendingCommand {
  _PendingCommand(this.key, this.keeper, this.send);
  final String key;
  final String keeper;
  final Future<AdmissionCommandResponse> Function() send;
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';

import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

import 'package:totem_core/features/sessions/repositories/keeper_admission_repository.dart';
import 'package:totem_core/features/sessions/repositories/participant_admission_repository.dart';
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
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
  AdmissionSnapshot? get snapshot {
    _observeAuthority();
    final room = session.transport;
    return mounted &&
            !_disconnecting &&
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
          (p) => p.admissionState == 'permanently_declined',
        ) ??
        const <Participant>[],
  );
  bool _approvalRequired = true;
  bool get approvalRequired => _approvalRequired;
  bool _busy = false;
  bool get busy => _busy;

  /// Whether the current Keeper has a command whose outcome is unknown.
  bool get hasUnresolvedCommand {
    _observeAuthority();
    final keeper = session.admissionState.roomState.keeper;
    return mounted &&
        !_disconnecting &&
        !_busy &&
        session.transport?.localIdentity == keeper &&
        _pending.containsKey(keeper);
  }

  String? error;
  bool _closed = false;
  bool _disconnecting = false;
  bool get mounted => !_closed;
  Set<String> _admittedIdentities = const {};
  Set<String> get admittedIdentities {
    _observeAuthority();
    return _admittedIdentities;
  }

  bool _recipientsCurrent = false;
  Set<String>? get serverDataRecipients {
    _observeAuthority();
    return mounted && !_disconnecting && _recipientsCurrent
        ? _admittedIdentities
        : null;
  }

  Future<void> _queue = Future.value();
  Future<void> get synchronized => _queue;
  int _generation = 0;
  bool _refreshQueued = false;
  Future<void>? _closing;
  final Map<String, _PendingCommand> _pending = {};
  final Set<String> _queuedActions = {};
  bool _authorityObserved = false;
  SessionTransport? _authorityRoom;
  String? _authorityKeeper;
  String? _authorityLocal;

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
      _clearProjection();
      _notify();
      return;
    }
    final initialState = await roomState(ref, _slug);
    if (!mounted ||
        _disconnecting ||
        generation != _generation ||
        !identical(session.transport, room)) {
      return;
    }
    if (initialState.sessionSlug != _slug ||
        initialState.keeper.isEmpty ||
        initialState.status == RoomStatus.ended) {
      _snapshot = null;
      _clearProjection();
      throw StateError('Room state unavailable or ended');
    }
    if (initialState.version > session.admissionState.roomState.version) {
      session.applyRoomState(initialState);
      if (_observeAuthority()) {
        sync();
        return;
      }
    }
    final keeper = session.admissionState.roomState.keeper;
    if (initialState.keeper != keeper || !_current(generation, room, keeper)) {
      _snapshot = null;
      _clearProjection();
      throw StateError('Room Keeper is not synchronized');
    }
    final local = room.localIdentity;
    if (local == null || local.isEmpty) {
      throw StateError('Local identity unavailable');
    }
    if (local == keeper) {
      final data = await _keeperRepository.snapshot(sessionSlug: _slug);
      if (!_current(generation, room, keeper)) return;
      if (data.sessionSlug != _slug || data.keeper != keeper) {
        _snapshot = null;
        _clearProjection();
        throw StateError('Keeper changed; refresh room state');
      }
      final state = await roomState(ref, _slug);
      if (!_current(generation, room, keeper)) return;
      if (state.sessionSlug != _slug ||
          state.keeper != keeper ||
          state.version < data.roomVersion ||
          state.status == RoomStatus.ended) {
        _snapshot = null;
        _clearProjection();
        throw StateError('Admission and room state do not agree');
      }
      _acceptSnapshot(data);
      if (state.version > session.admissionState.roomState.version) {
        session.applyRoomState(state);
      }
      if (!_current(generation, room, keeper)) return;
      _setRecipients({...state.talkingOrder, state.keeper}..remove(''));
    } else {
      final data = await _participantRepository.me(sessionSlug: _slug);
      if (!_current(generation, room, keeper)) return;
      final state = await roomState(ref, _slug);
      if (!_current(generation, room, keeper)) return;
      if (data.sessionSlug != _slug ||
          state.sessionSlug != _slug ||
          data.keeper != keeper ||
          state.keeper != keeper ||
          state.version < data.roomVersion ||
          state.status == RoomStatus.ended) {
        _snapshot = null;
        _clearProjection();
        throw StateError('Admission and room state do not agree');
      }
      _snapshot = null;
      _approvalRequired = data.approvalRequired;
      if (state.version > session.admissionState.roomState.version) {
        session.applyRoomState(state);
      }
      if (!_current(generation, room, keeper)) return;
      _setRecipients({...state.talkingOrder, state.keeper}..remove(''));
    }
    error = !_pending.containsKey(keeper)
        ? null
        : 'A previous admission command has an unknown outcome; retry it before making another change.';
    _notify();
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
    _approvalRequired = data.approvalRequired;
    // Broadcast recipients come from the authoritative room-state projection,
    // not durable admission, which can include disconnected or unactivated users.
  }

  void _setRecipients(Set<String> identities) {
    _admittedIdentities = Set.unmodifiable(identities);
    session.updateAdmittedMediaRecipients(_admittedIdentities);
    _recipientsCurrent = true;
  }

  void handleTransportEvent(SessionTransportEvent event) {
    if (event is TransportConnectionChanged ||
        event is TransportMetadataChanged ||
        event is TransportParticipantChanged ||
        event is TransportParticipantUpdated ||
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
        final issue = result.error.value ?? participant?.lastError.value;
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
            p.admissionState == 'permanently_declined',
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
    _generation++;
    _refreshQueued = false;
    _snapshot = null;
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

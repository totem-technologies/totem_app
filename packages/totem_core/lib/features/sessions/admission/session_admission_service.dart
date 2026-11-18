import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_roster.dart';
import 'package:totem_core/features/sessions/admission/session_admission_channel.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/services/session_moderation_service.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

final class _RevocationJournal extends MapBase<String, String> {
  _RevocationJournal([Map<String, String>? records]) : _records = records ?? {};
  final Map<String, String> _records;
  Map<String, Object?>? roster;
  @override
  String? operator [](Object? key) => _records[key];
  @override
  void operator []=(String key, String value) => _records[key] = value;
  @override
  Iterable<String> get keys => _records.keys;
  @override
  String? remove(Object? key) => _records.remove(key);
  @override
  void clear() => _records.clear();
}

class CorruptAdmissionRemovalJournal implements Exception {
  const CorruptAdmissionRemovalJournal(this.cause);

  final Object cause;

  @override
  String toString() => 'Corrupt admission removal journal: $cause';
}

/// A reservation held until the backend settles or its admission attachment ends.
///
/// Attachment shutdown leaves the backend outcome unknown, but retains the
/// durable revocation so a replacement owner can safely reconcile or remove.
final class AdmissionUnbanReservation {
  AdmissionUnbanReservation._(
    this._owner,
    this._release,
    this._validate,
    this._onRelease,
  );

  final Object _owner;
  final void Function() _release;
  final void Function() _validate;
  final void Function() _onRelease;
  bool _started = false;
  bool _released = false;

  void _finish() {
    if (_released) return;
    _released = true;
    _onRelease();
    _release();
  }

  /// Start the original backend future; apply timeouts to the returned future.
  Future<T> run<T>(Future<T> Function() operation) async {
    if (_started || _released) {
      throw StateError('Unban reservation is no longer available');
    }
    _started = true;
    try {
      _validate();
      return await operation();
    } finally {
      _finish();
    }
  }

  /// Release an unused reservation.
  void cancel() {
    if (_started) return;
    _finish();
  }

  /// Release this service's reservation when its admission attachment ends.
  void invalidate(Object owner) {
    if (identical(_owner, owner)) _finish();
  }
}

/// Trust in the current session's admission roster.
enum AdmissionRosterTrust {
  unverified,
  verified,
  recovering,
  expired,
  invalidated,
}

/// Admission coordinator retained by the active session, independently of UI.
class SessionAdmissionService extends ChangeNotifier {
  SessionAdmissionService(
    this.ref,
    this.session, {
    this.now,
    this.recoveryLease = const Duration(seconds: 90),
  }) : assert(!recoveryLease.isNegative, 'Recovery lease cannot be negative');

  SessionAdmissionChannel? _transport;
  KeeperAdmissionController? _keeperController;
  ClientAdmissionRosterController? _clientController;
  // Cancelled by _detachAdmission.
  // ignore: cancel_subscriptions
  StreamSubscription<void>? _keeperChanges;
  // Cancelled by _detachAdmission.
  // ignore: cancel_subscriptions
  StreamSubscription<AdmissionRoster?>? _clientChanges;
  // Cancelled by _detachAdmission.
  // ignore: cancel_subscriptions
  StreamSubscription<bool>? _clientSynchronizationChanges;

  SessionTransport? _room;
  String? _keeperIdentity;
  String? _attachmentSessionIdentity;
  KeeperAdmissionRosterStore? _attachedKeeperRoster;
  KeeperAdmissionPersistence? _persistence;
  Future<void> Function()? _saveKeeperRoster;
  Future<void> Function()? _clearKeeperRoster;
  Future<void> Function()? _clearDeclinedParticipants;
  bool _sessionEnded = false;
  bool _busy = false;
  final Ref ref;
  final SessionController session;
  final DateTime Function()? now;
  final Duration recoveryLease;
  AdmissionRosterTrust _rosterTrust = AdmissionRosterTrust.unverified;
  AdmissionRosterTrust get rosterTrust => _rosterTrust;

  void _setRosterTrust(AdmissionRosterTrust next) {
    if (_rosterTrust == next) return;
    final previous = _rosterTrust;
    _rosterTrust = next;
    if (next
        case AdmissionRosterTrust.verified ||
            AdmissionRosterTrust.recovering ||
            AdmissionRosterTrust.invalidated) {
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            category: 'admission.roster',
            message: next.name,
            level: SentryLevel.info,
            data: {'from': previous.name, 'to': next.name},
          ),
        ),
      );
    }
  }

  bool get isRecoveringRoster =>
      _rosterTrust == AdmissionRosterTrust.recovering;
  String? _rosterSessionIdentity;
  DateTime? _recoveryDeadline;
  DateTime? get recoveryDeadline => _recoveryDeadline;
  Timer? _recoveryTimer;
  Set<String> _admittedIdentities = const {};
  Set<String> get admittedIdentities => _admittedIdentities;
  bool approvalRequired = true;
  void setApprovalRequired(bool value) {
    approvalRequired = value;
    if (mounted && !_detaching && !_disconnecting) sync();
  }

  bool _disposed = false;
  bool get mounted => !_disposed && ref.mounted;
  String? error;
  String? recoveryError;
  bool _corruptRemovalJournal = false;
  bool get hasCorruptRemovalJournal => _corruptRemovalJournal;
  bool _recoveryUnavailable = false;
  String? _revocationKeeper;
  final Set<String> _pendingRevocations = {};
  final Set<String> _committedRevocations = {};
  final Set<String> _rejectedRevocations = {};
  final Set<String> _unresolvedRevocations = {};
  Set<String> get unresolvedRemovals =>
      Set.unmodifiable(_unresolvedRevocations);
  bool _disconnecting = false;
  bool _detaching = false;
  int _generation = 0;
  Future<void>? _disconnectingFuture;
  Object? _storageFailure;
  StackTrace? _storageStack;
  final _operations = <Future<dynamic>>{};
  final _journalOperations = <Future<dynamic>>{};
  final _rosterWrites = <Future<bool>>{};
  final _reservationOwner = Object();
  final _unbanReservations = <AdmissionUnbanReservation>{};

  void _invalidateUnbanReservations() {
    for (final reservation in List.of(_unbanReservations)) {
      reservation.invalidate(_reservationOwner);
    }
  }

  Future<T> _track<T>(Future<T> work) {
    late final Future<T> tracked;
    tracked = work.whenComplete(() => _operations.remove(tracked));
    _operations.add(tracked);
    return tracked;
  }

  Future<void> _enqueueLifecycle(Future<void> Function() action) {
    final operation = _synchronization.then((_) => action());
    // A failed operation must not prevent later cleanup from running.
    _synchronization = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> disconnect() {
    if (_closing != null) return _closing!;
    if (_disconnectingFuture != null) return _disconnectingFuture!;
    _disconnecting = true;
    _generation++;
    late final Future<void> operation;
    operation =
        _enqueueLifecycle(() async {
          await _detachAdmission();
          if (_storageFailure != null) {
            Error.throwWithStackTrace(_storageFailure!, _storageStack!);
          }
        }).whenComplete(() {
          _disconnecting = false;
          _disconnectingFuture = null;
        });
    return _disconnectingFuture = operation;
  }

  void handleTransportEvent(SessionTransportEvent event) {
    if (mounted && !_disconnecting && !_detaching) {
      _transport?.handle(event);
      _sessionEnded = _sessionEnded || (_transport?.hasEnded ?? false);
    }
  }

  Future<void> sendAdmissionJoined(AdmissionRequest request) =>
      _sendAdmissionOutcome(request, joined: true);
  Future<void> sendAdmissionJoinFailed(AdmissionRequest request) =>
      _sendAdmissionOutcome(request, joined: false);
  Future<void> _sendAdmissionOutcome(
    AdmissionRequest request, {
    required bool joined,
  }) {
    if (!mounted || _disconnecting) {
      return Future.error(StateError('Admission is closing'));
    }
    return _enqueueLifecycle(() => _sendOutcome(request, joined: joined));
  }

  Future<void> _sendOutcome(
    AdmissionRequest request, {
    required bool joined,
  }) async {
    final connection = session.transport;
    final generation = _generation;
    if (!mounted ||
        _disconnecting ||
        connection == null ||
        connection.connectionState !=
            SessionTransportConnectionState.connected ||
        connection.localIdentity != request.senderIdentity ||
        (joined &&
            session.admissionState.connectionState !=
                RoomConnectionState.connected)) {
      throw StateError('Admission sender is not connected to the session room');
    }
    if (_room != null && !identical(_room, connection)) {
      await _detachAdmission();
    }
    if (!mounted || _disconnecting || generation != _generation) {
      throw StateError('Admission connection superseded');
    }
    final channel = _transport ??= SessionAdmissionChannel(
      connection,
      now: now,
    );
    _room = connection;
    await channel.sendJoinOutcome(request, joined: joined);
  }

  KeeperAdmissionController? get keeperController => _keeperController;

  /// Whether the attached client is waiting for a trusted admission roster.
  bool get isSynchronizing =>
      _clientController != null &&
      (_clientController!.isSynchronizing ||
          _rosterTrust == AdmissionRosterTrust.recovering ||
          _rosterTrust == AdmissionRosterTrust.expired);
  bool get busy => _busy;
  void setState(void Function() action) {
    if (!mounted) return;
    action();
    notifyListeners();
  }

  String? _observedKeeper;
  final List<ProviderSubscription<dynamic>> _rosterSubscriptions = [];
  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _disposed = true;
    _invalidateUnbanReservations();
    _recoveryTimer?.cancel();
    _generation++;
    Object? failure;
    StackTrace? failureStack;
    void failed(Object error, StackTrace stack) {
      failure ??= error;
      failureStack ??= stack;
      ErrorHandler.logError(
        error,
        stackTrace: stack,
        message: 'Admission shutdown failed',
      );
    }

    for (final subscription in _rosterSubscriptions) {
      try {
        subscription.close();
      } catch (error, stack) {
        failed(error, stack);
      }
    }
    _rosterSubscriptions.clear();
    try {
      // Detach never awaits this queue: _sync may itself be detaching.
      await _synchronization;
      await _detachAdmission(clearAdmitted: false, endSession: _sessionEnded);
      if (_storageFailure != null) failed(_storageFailure!, _storageStack!);
    } catch (error, stack) {
      failed(error, stack);
    } finally {
      final scope = _ownedScope;
      if (scope != null && identical(_owners[scope], this)) {
        _owners.remove(scope);
      }
      super.dispose();
    }
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  }

  // The session remains the owner; this barrier only orders old/new admission
  // services sharing that session/Keeper during entry replacement.
  static final _owners = <String, SessionAdmissionService>{};
  String? _ownedScope;
  Object? _ownershipFailure;
  Future<bool> _claimOwnership(String keeper) async {
    if (_ownershipFailure != null) {
      throw StateError(
        'Previous admission teardown failed: $_ownershipFailure',
      );
    }
    final scope = jsonEncode([session.options.sessionSlug, keeper]);
    final oldScope = _ownedScope;
    if (oldScope != null && oldScope != scope) {
      await _detachAdmission();
      if (identical(_owners[oldScope], this)) _owners.remove(oldScope);
      _ownedScope = null;
      if (!mounted) return false;
    }
    if (_ownedScope == scope && identical(_owners[scope], this)) return true;
    final previous = _owners[scope];
    _ownedScope = scope;
    _owners[scope] = this;
    if (previous != null && !identical(previous, this)) {
      try {
        await previous.close();
      } catch (error) {
        _ownershipFailure = error;
        rethrow;
      }
    }
    if (!mounted) return false;
    if (session.transport?.localIdentity == keeper) {
      // Also discard a snapshot preloaded before the previous owner queued its
      // final save. Only the active Keeper owns these local recovery providers.
      final roster = keeperAdmissionRosterProvider(
        session.options.sessionSlug,
        keeper,
      );
      final declined = declinedSessionParticipantsProvider(
        session.options.sessionSlug,
        keeper,
      );
      _observeRecoveryProviders(keeper);
      ref
        ..invalidate(roster)
        ..invalidate(declined);
      await Future.wait([ref.read(roster.future), ref.read(declined.future)]);
    }
    return mounted;
  }

  void _observeRecoveryProviders(String keeperIdentity) {
    final rosterProvider = keeperAdmissionRosterProvider(
      session.options.sessionSlug,
      keeperIdentity,
    );
    if (_observedKeeper != keeperIdentity) {
      for (final subscription in _rosterSubscriptions) {
        subscription.close();
      }
      _rosterSubscriptions.clear();
      _observedKeeper = keeperIdentity;
      _rosterSubscriptions.add(ref.listen(rosterProvider, (_, _) => sync()));
      _rosterSubscriptions.add(
        ref.listen(
          declinedSessionParticipantsProvider(
            session.options.sessionSlug,
            keeperIdentity,
          ),
          (_, _) => sync(),
        ),
      );
    }
  }

  Future<void> get synchronized => _synchronization;
  Future<void> _synchronization = Future.value();
  void sync() {
    if (!mounted || _disconnecting) return;
    if (_keeperIdentity != null &&
        ((_rosterSessionIdentity != null &&
                _rosterSessionIdentity != session.options.sessionSlug) ||
            _keeperIdentity != session.admissionState.roomState.keeper ||
            !identical(_room, session.transport) ||
            session.admissionState.roomState.status == RoomStatus.ended ||
            session.session?.ended == true)) {
      _invalidateRoster();
    }
    _sessionEnded =
        _sessionEnded ||
        session.admissionState.roomState.status == RoomStatus.ended ||
        session.session?.ended == true;
    final generation = ++_generation;
    unawaited(
      _enqueueLifecycle(() async {
        if (mounted && !_disconnecting && generation == _generation) {
          await _sync();
        }
      }).catchError((Object failure, StackTrace stackTrace) {
        if (mounted && generation == _generation) {
          if (_clientController != null &&
              _attachmentSessionIdentity == session.options.sessionSlug &&
              _keeperIdentity == session.admissionState.roomState.keeper &&
              identical(_room, session.transport) &&
              session.admissionState.roomState.status != RoomStatus.ended &&
              session.session?.ended != true) {
            _beginRosterRecovery();
            _clientController?.requestSynchronization();
          } else {
            _invalidateRoster();
          }
          recoveryError = 'Admission unavailable. Retry recovery.';
          error = recoveryError;
          notifyListeners();
        }
        ErrorHandler.logError(
          failure,
          stackTrace: stackTrace,
          message: 'Could not synchronize admission',
        );
      }),
    );
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final state = session.admissionState;
    final event = session.session;
    final room = session.transport;
    final keeperIdentity = state.roomState.keeper;
    final generation = _generation;
    if (_revocationKeeper != keeperIdentity) {
      _revocationKeeper = keeperIdentity;
      _pendingRevocations.clear();
      _committedRevocations.clear();
      _rejectedRevocations.clear();
      _unresolvedRevocations.clear();
    }
    _sessionEnded =
        _sessionEnded ||
        state.roomState.status == RoomStatus.ended ||
        event?.ended == true;
    final connected = state.connection.state == RoomConnectionState.connected;
    final active =
        connected &&
        state.roomState.status != RoomStatus.ended &&
        event?.ended != true &&
        room != null &&
        keeperIdentity.isNotEmpty;
    if (!active) {
      final recoverableClient =
          !connected &&
          !_sessionEnded &&
          _clientController != null &&
          identical(_room, room) &&
          _keeperIdentity == keeperIdentity &&
          _attachmentSessionIdentity == session.options.sessionSlug;
      if (recoverableClient) {
        _beginRosterRecovery();
        notifyListeners();
      } else if (_hasAdmission) {
        await _detachAdmission(endSession: _sessionEnded);
      }
      return;
    }

    if (!await _claimOwnership(keeperIdentity)) return;
    if (!mounted ||
        generation != _generation ||
        !identical(session.transport, room) ||
        session.admissionState.roomState.keeper != keeperIdentity) {
      return;
    }
    final isKeeper = room.localIdentity == keeperIdentity;
    final declinedIdentities = isKeeper
        ? ref
              .read(
                declinedSessionParticipantsProvider(
                  session.options.sessionSlug,
                  keeperIdentity,
                ),
              )
              .value
        : null;
    final rosterProvider = keeperAdmissionRosterProvider(
      session.options.sessionSlug,
      keeperIdentity,
    );
    _observeRecoveryProviders(keeperIdentity);
    final restoredRoster = isKeeper ? ref.read(rosterProvider).value : null;
    // Do not advertise an empty authority before persisted admission is loaded.
    if (isKeeper && (declinedIdentities == null || restoredRoster == null)) {
      if (_hasAdmission &&
          (!identical(_room, room) || _keeperIdentity != keeperIdentity)) {
        await _detachAdmission();
      }
      return;
    }
    final controllerActive = isKeeper
        ? _keeperController != null
        : _clientController != null;
    if (identical(_room, room) &&
        _keeperIdentity == keeperIdentity &&
        _attachmentSessionIdentity == session.options.sessionSlug &&
        controllerActive &&
        (!isKeeper || identical(_attachedKeeperRoster, restoredRoster))) {
      if (declinedIdentities != null) {
        _keeperController?.setDeclinedIdentities(declinedIdentities);
      }
      _keeperController?.setApprovalRequired(
        approvalRequired ||
            _recoveryUnavailable ||
            _pendingRevocations.isNotEmpty,
      );
      return;
    }

    await _detachAdmission(
      clearAdmitted: !isKeeper,
      disposeChannel: !identical(_room, room),
    );
    if (!mounted || generation != _generation) return;
    final persistence = isKeeper
        ? ref.read(rosterProvider.notifier).capturePersistence(restoredRoster!)
        : null;
    if (isKeeper) {
      try {
        await _recoverRevocations(
          keeperIdentity,
          restoredRoster!,
          persistence!.persist,
        );
        if (!mounted ||
            generation != _generation ||
            !identical(session.transport, room) ||
            session.admissionState.roomState.keeper != keeperIdentity) {
          persistence.release();
          return;
        }
        await persistence.persist();
      } catch (_) {
        persistence!.release();
        rethrow;
      }
      if (!mounted ||
          generation != _generation ||
          !identical(session.transport, room) ||
          session.admissionState.roomState.keeper != keeperIdentity) {
        persistence.release();
        return;
      }
    }
    final transport = _transport ?? SessionAdmissionChannel(room, now: now);
    _transport = transport;
    _room = room;
    _keeperIdentity = keeperIdentity;
    _attachmentSessionIdentity = session.options.sessionSlug;

    if (isKeeper) {
      _attachedKeeperRoster = restoredRoster;
      _persistence = persistence;
      _saveKeeperRoster = persistence!.persist;
      _clearKeeperRoster = persistence.clear;
      _clearDeclinedParticipants = ref
          .read(
            declinedSessionParticipantsProvider(
              session.options.sessionSlug,
              keeperIdentity,
            ).notifier,
          )
          .captureClear();
      final controller = KeeperAdmissionController(
        channel: transport,
        keeperIdentity: _currentKeeperIdentity,
        isSessionStarted: () =>
            session.admissionState.roomState.status == RoomStatus.active,
        sessionIdentity: session.options.sessionSlug,
        rosterStore: restoredRoster,
        persistRoster: () {
          final snapshot = Future<void>.sync(persistence.persist);
          return _persistRoster(() => snapshot).then((saved) async {
            if (!saved) await snapshot;
          });
        },
        approvalRequired:
            approvalRequired ||
            _recoveryUnavailable ||
            _pendingRevocations.isNotEmpty,
        declinedIdentities: declinedIdentities!,
        quarantinedIdentities: _unresolvedRevocations,
        now: now,
      );
      _keeperController = controller;
      _committedRevocations.forEach(controller.revoke);
      if (!mounted || !identical(_keeperController, controller)) return;

      _rosterSessionIdentity = session.options.sessionSlug;
      _setRosterTrust(AdmissionRosterTrust.verified);
      _syncAdmittedIdentities(controller.roster);
      _keeperChanges = controller.changes.listen((_) {
        if (!mounted || !identical(_keeperController, controller)) return;

        _syncAdmittedIdentities(controller.roster);
        setState(() {});
      });
    } else {
      final controller = ClientAdmissionRosterController(
        channel: transport,
        keeperIdentity: _currentKeeperIdentity,
        sessionIdentity: session.options.sessionSlug,
        now: now,
      );
      _clientController = controller;
      _clientSynchronizationChanges = controller.synchronizationChanges.listen((
        synchronizing,
      ) {
        if (!mounted ||
            _detaching ||
            !identical(_clientController, controller)) {
          return;
        }
        if (synchronizing) _beginRosterRecovery();
        notifyListeners();
      });
      _clientChanges = controller.changes.listen((roster) {
        if (!mounted ||
            _detaching ||
            !identical(_clientController, controller)) {
          return;
        }
        if (_keeperIdentity != session.admissionState.roomState.keeper ||
            _attachmentSessionIdentity != session.options.sessionSlug ||
            !identical(_room, session.transport) ||
            session.admissionState.roomState.status == RoomStatus.ended ||
            session.session?.ended == true) {
          _invalidateRoster();
          return;
        }
        if (roster == null) {
          _invalidateRoster();
        } else {
          _recoveryTimer?.cancel();
          _rosterSessionIdentity = session.options.sessionSlug;
          _recoveryDeadline = (now?.call() ?? DateTime.now()).add(
            recoveryLease,
          );
          _setRosterTrust(AdmissionRosterTrust.verified);
          if (controller.isSynchronizing) _beginRosterRecovery();
          if (_rosterTrust != AdmissionRosterTrust.expired) {
            _syncAdmittedIdentities(roster.members);
          }
        }
      });
    }
    setState(() {});
  }

  String _currentKeeperIdentity() => mounted && !_detaching && !_disconnecting
      ? session.admissionState.roomState.keeper
      : '';

  bool get _hasAdmission =>
      _keeperController != null ||
      _clientController != null ||
      _transport != null;

  Future<bool> _persistRoster(Future<void> Function() persist) {
    late final Future<bool> operation;
    operation = _saveRoster(
      persist,
    ).whenComplete(() => _rosterWrites.remove(operation));
    _rosterWrites.add(operation);
    return operation;
  }

  Future<bool> _saveRoster(Future<void> Function() persist) async {
    final owner = _keeperController;
    try {
      await persist();
      if (mounted &&
          identical(owner, _keeperController) &&
          _pendingRevocations.isEmpty) {
        _recoveryUnavailable = false;
        _storageFailure = null;
        _storageStack = null;
        recoveryError = null;
        error = null;
        notifyListeners();
      }
      return true;
    } catch (failure, stackTrace) {
      _storageFailure = failure;
      _storageStack = stackTrace;
      ErrorHandler.logError(
        failure,
        stackTrace: stackTrace,
        message: 'Could not save Keeper admission recovery',
      );
      if (mounted && identical(owner, _keeperController)) {
        _recoveryUnavailable = true;
        recoveryError =
            'Admission recovery could not be saved. Retry recovery.';
        owner?.setApprovalRequired(true);
        error =
            'Admission recovery could not be saved. Keep this Session open and retry.';
        notifyListeners();
      }
      return false;
    }
  }

  Future<void> _clearAdmissionData(Future<void> Function() clear) async {
    try {
      await clear();
    } catch (failure, stackTrace) {
      ErrorHandler.logError(
        failure,
        stackTrace: stackTrace,
        message: 'Could not clear ended Session admission data',
      );
      _storageFailure = failure;
      _storageStack = stackTrace;
      rethrow;
    }
  }

  void _beginRosterRecovery() {
    final deadline = _recoveryDeadline;
    if (deadline == null || _rosterTrust == AdmissionRosterTrust.expired) {
      return;
    }
    _recoveryTimer?.cancel();
    final remaining = deadline.difference(now?.call() ?? DateTime.now());
    if (remaining <= Duration.zero) {
      _expireRoster();
      return;
    }
    _setRosterTrust(AdmissionRosterTrust.recovering);
    _recoveryTimer = Timer(remaining, _expireRoster);
  }

  void _expireRoster() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _rosterTrust = AdmissionRosterTrust.expired;
    _recoveryDeadline = null;
    _syncAdmittedIdentities(const []);
    _clientController?.requestSynchronization();
  }

  void _invalidateRoster() {
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _recoveryDeadline = null;
    _rosterSessionIdentity = null;
    if (_rosterTrust != AdmissionRosterTrust.unverified) {
      _setRosterTrust(AdmissionRosterTrust.invalidated);
    }
    _syncAdmittedIdentities(const []);
  }

  void _syncAdmittedIdentities(Iterable<String> identities) {
    if (!mounted) return;
    _keeperController?.setQuarantinedIdentities(_unresolvedRevocations);
    final roster = Set<String>.unmodifiable(
      identities.where(
        (id) =>
            !_committedRevocations.contains(id) &&
            !_unresolvedRevocations.contains(id),
      ),
    );
    session.updateAdmittedMediaRecipients(roster);
    _admittedIdentities = roster;
    notifyListeners();
  }

  Future<void> _detachAdmission({
    bool clearAdmitted = true,
    bool disposeChannel = true,
    bool endSession = false,
  }) async {
    _detaching = true;
    _invalidateUnbanReservations();
    final persistence = _persistence;
    final persist = _saveKeeperRoster;
    final clearRoster = _clearKeeperRoster;
    final clearDeclined = _clearDeclinedParticipants;
    final keeperController = _keeperController;
    final clientController = _clientController;
    final transport = _transport;
    final keeperChanges = _keeperChanges;
    final clientChanges = _clientChanges;
    final clientSynchronizationChanges = _clientSynchronizationChanges;
    final hasFinalRosterWrite = endSession
        ? clearRoster != null
        : persist != null;
    Object? failure;
    StackTrace? failureStack;
    var rosterWriteFailed = false;
    void failed(Object error, StackTrace stack) {
      failure ??= error;
      failureStack ??= stack;
      _storageFailure = error;
      _storageStack = stack;
      _recoveryUnavailable = true;
      recoveryError = 'Admission recovery could not be saved. Retry recovery.';
      ErrorHandler.logError(
        error,
        stackTrace: stack,
        message: 'Admission detach failed',
      );
    }

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stack) {
        failed(error, stack);
      }
    }

    try {
      // Quiesce service observers and event routing before capturing final state.
      if (keeperChanges != null) await attempt(keeperChanges.cancel);

      if (clientChanges != null) await attempt(clientChanges.cancel);
      if (clientSynchronizationChanges != null) {
        await attempt(clientSynchronizationChanges.cancel);
      }

      while (_operations.isNotEmpty) {
        await attempt(() async {
          await Future.wait(_operations.toList());
        });
      }
      while (_journalOperations.isNotEmpty) {
        await attempt(() async {
          await Future.wait(_journalOperations.toList());
        });
      }
      if (keeperController != null) await attempt(keeperController.dispose);
      while (_rosterWrites.isNotEmpty) {
        final results = await Future.wait(_rosterWrites.toList());
        if (results.contains(false) && _storageFailure != null) {
          rosterWriteFailed = true;
          if (!hasFinalRosterWrite) {
            failed(_storageFailure!, _storageStack!);
          }
        }
      }
      // Enqueue the terminal writes synchronously, then fence the captured
      // writer before waiting. A late backend completion may retain its journal
      // but must not enqueue a roster save behind a session-end clear.
      final terminalWrites = <Future<void>>[];
      if (endSession) {
        if (clearRoster != null) {
          terminalWrites.add(attempt(() => _clearAdmissionData(clearRoster)));
        }
        if (clearDeclined != null) {
          terminalWrites.add(attempt(() => _clearAdmissionData(clearDeclined)));
        }
      } else if (persist != null) {
        terminalWrites.add(attempt(persist));
      }
      persistence?.release();
      await Future.wait(terminalWrites);
      if (failure == null &&
          (persist != null || clearRoster != null || clearDeclined != null)) {
        _storageFailure = null;
        _storageStack = null;
        if (rosterWriteFailed) {
          _recoveryUnavailable = false;
          recoveryError = null;
          error = null;
        }
      }
    } finally {
      // No future completion captured by this attachment can save a stale roster.
      persistence?.release();
      _persistence = null;
      _attachedKeeperRoster = null;
      _saveKeeperRoster = null;
      _clearKeeperRoster = null;
      _clearDeclinedParticipants = null;
      _keeperController = null;
      _clientController = null;
      _keeperChanges = null;
      _clientChanges = null;
      _clientSynchronizationChanges = null;
      _keeperIdentity = null;
      _attachmentSessionIdentity = null;
      _busy = false;
      if (clearAdmitted) _invalidateRoster();
      if (clientController != null) await attempt(clientController.dispose);

      if (disposeChannel) {
        _transport = null;
        _room = null;
        if (transport != null) await attempt(transport.dispose);
      }
      _detaching = false;
    }
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  }

  Future<void> decide(
    AdmissionRequest request,
    bool approve, {
    bool permanently = false,
  }) {
    if (!mounted || _detaching || _disconnecting) {
      return Future<void>.value();
    }
    return _track(_decideCommand(request, approve, permanently: permanently));
  }

  Future<void> _decideCommand(
    AdmissionRequest request,
    bool approve, {
    bool permanently = false,
  }) async {
    final controller = _keeperController;
    if (controller == null ||
        _busy ||
        _recoveryUnavailable ||
        _pendingRevocations.isNotEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _sendDecision(
        controller,
        request,
        approve,
        permanently: permanently,
      );
    } finally {
      if (mounted && identical(_keeperController, controller)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> admitAll() {
    if (!mounted || _detaching || _disconnecting) {
      return Future<bool>.value(false);
    }
    return _track(_admitAllCommand());
  }

  Future<bool> _admitAllCommand() async {
    final controller = _keeperController;
    if (controller == null ||
        _recoveryUnavailable ||
        _pendingRevocations.isNotEmpty) {
      return false;
    }
    if (_busy) {
      error = 'Admission in progress';
      notifyListeners();
      return false;
    }
    setState(() => _busy = true);
    var reportedError = false;
    try {
      for (final request in controller.requests) {
        if (!identical(_keeperController, controller)) break;
        reportedError |= await _sendDecision(
          controller,
          request,
          true,
          reportError: !reportedError,
        );
      }
      if (!mounted ||
          !identical(_keeperController, controller) ||
          reportedError) {
        return false;
      }
      if (controller.requests.isEmpty) return true;
      error = 'New participants arrived';
      notifyListeners();
      return false;
    } finally {
      if (mounted && identical(_keeperController, controller)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _sendDecision(
    KeeperAdmissionController controller,
    AdmissionRequest request,
    bool approve, {
    bool permanently = false,
    bool reportError = true,
  }) async {
    if (!controller.isPendingRequest(request.id, request.senderIdentity)) {
      return false;
    }
    try {
      if (approve) {
        await controller.approve(request.id, request.senderIdentity);
      } else if (permanently) {
        final declined = ref.read(
          declinedSessionParticipantsProvider(
            session.options.sessionSlug,
            controller.channel.localIdentity,
          ).notifier,
        );
        await controller.denyPermanently(
          request.id,
          request.senderIdentity,
          () => declined.decline(request.senderIdentity),
        );
      } else {
        await controller.deny(request.id, request.senderIdentity);
      }
      return false;
    } catch (error, stackTrace) {
      if (!controller.isPendingRequest(request.id, request.senderIdentity)) {
        return false;
      }
      if (reportError) {
        ErrorHandler.logError(
          error,
          stackTrace: stackTrace,
          message: 'Could not send admission decision',
        );
        if (mounted && identical(_keeperController, controller)) {
          this.error = 'Could not update the queue';
          notifyListeners();
        }
      }
      return true;
    }
  }

  Future<void> retryRecovery() {
    if (!mounted || _detaching || _disconnecting) {
      return Future.error(StateError('Admission is closing'));
    }
    return _track(_retryRecovery());
  }

  Future<void> _retryRecovery() async {
    if (_keeperController == null || _saveKeeperRoster == null) {
      // The previous owner has already released its resources even if its final
      // write failed. An explicit retry reloads durable recovery before attaching.
      if (_ownershipFailure != null) {
        _ownershipFailure = null;
        final scope = _ownedScope;
        if (scope != null && identical(_owners[scope], this)) {
          _owners.remove(scope);
        }
        _ownedScope = null;
      }
      sync();
      return;
    }
    final keeper = _keeperIdentity!;
    final store = _attachedKeeperRoster!;
    final controller = _keeperController!;
    await controller.pendingRosterWrites;
    final preferences = await ref.read(
      sessionAdmissionPreferencesProvider.future,
    );
    await _serializeJournal(() async {
      final records = _readRevocations(
        preferences.getString(_revocationKey(keeper)),
      );
      for (final identity in _committedRevocations) {
        records[identity] = 'committed';
      }
      for (final identity in _rejectedRevocations) {
        records[identity] = 'rejected';
      }
      if (records.isNotEmpty &&
          !await preferences.setString(
            _revocationKey(keeper),
            _encodeRevocations(records),
          )) {
        throw StateError(
          'Could not save removal reconciliation. Retry recovery.',
        );
      }
      if (!identical(_keeperController, controller) ||
          !identical(_attachedKeeperRoster, store)) {
        throw StateError('Keeper changed during admission recovery');
      }
      // A live controller owns its revision. Recovery must not mutate its store
      // behind it or a subsequent controller save could roll back the revision.
      for (final entry in records.entries) {
        if (entry.value == 'committed' && !store.revoked.contains(entry.key)) {
          controller.revoke(entry.key, persist: false);
        }
      }
      await controller.retryRosterPersistence();
      records
        ..removeWhere((_, status) => status != 'intent')
        ..roster = null;
      final saved = records.isEmpty
          ? await preferences.remove(_revocationKey(keeper))
          : await preferences.setString(
              _revocationKey(keeper),
              _encodeRevocations(records),
            );
      if (!saved) {
        throw StateError('Could not clear admission recovery journal');
      }
      _pendingRevocations
        ..clear()
        ..addAll(records.keys);
      _unresolvedRevocations
        ..clear()
        ..addAll(records.keys);
      _committedRevocations.clear();
      _rejectedRevocations.clear();
      if (mounted && _keeperIdentity == keeper) {
        if (_pendingRevocations.isEmpty) {
          _recoveryUnavailable = false;
          recoveryError = null;
          error = null;
        }
        _syncAdmittedIdentities(_keeperController!.roster);
        _keeperController!.setApprovalRequired(
          approvalRequired || _pendingRevocations.isNotEmpty,
        );
      }
    });
  }

  /// Resolve an unknown backend outcome only after it has been verified.
  /// This never sends another backend removal command.
  Future<void> reconcileRemoval(
    String identity, {
    required bool backendRemoved,
  }) =>
      _track<void>(_reconcileRemoval(identity, backendRemoved: backendRemoved));

  Future<void> _reconcileRemoval(
    String identity, {
    required bool backendRemoved,
  }) async {
    if (!mounted || _detaching || _disconnecting) {
      throw StateError('Admission is closing');
    }
    if (!_unresolvedRevocations.contains(identity)) {
      throw StateError('No pending removal');
    }
    final keeper = _keeperIdentity ?? _revocationKeeper;
    if (keeper == null) {
      throw StateError('Keeper identity is unavailable for removal recovery');
    }
    if (_keeperIdentity != keeper || _attachedKeeperRoster == null) {
      await _reconcileDetachedRemoval(
        identity,
        keeper: keeper,
        backendRemoved: backendRemoved,
      );
      return;
    }
    final operation = await _preparedRemoval(identity, existing: true);
    if (backendRemoved) {
      await operation.commit();
    } else {
      await operation.reject();
    }
  }

  Future<void> _reconcileDetachedRemoval(
    String identity, {
    required String keeper,
    required bool backendRemoved,
  }) async {
    final preferences = await ref.read(
      sessionAdmissionPreferencesProvider.future,
    );
    final rosterProvider = keeperAdmissionRosterProvider(
      session.options.sessionSlug,
      keeper,
    );
    final store = await ref.read(rosterProvider.future);
    final roster = ref.read(rosterProvider.notifier);
    final key = _revocationKey(keeper);
    final message = backendRemoved
        ? 'Removal is confirmed, but admission recovery could not be saved. Retry reconciliation, not removal.'
        : 'Removal was rejected, but admission recovery could not be cleared. Retry reconciliation, not removal.';

    await _removalPersistence(
      _serializeJournal(() async {
        if (!mounted || _disconnecting) {
          throw StateError('Admission is closing');
        }
        final records = _readRevocations(preferences.getString(key));
        if (!records.containsKey(identity)) {
          throw StateError('No durable removal recovery record');
        }
        _restoreJournalRoster(records, store, keeper);
        if (backendRemoved) {
          records[identity] = 'committed';
          if (!await preferences.setString(key, _encodeRevocations(records))) {
            throw StateError(message);
          }
          store.revoked.add(identity);
          store.replace(
            store.members.where((member) => member != identity).toList(),
            store.revision + 1,
            awaitingReadiness: store.awaitingReadiness
                .where((member) => member != identity)
                .toList(),
          );
          await roster.persistStore(store);
        } else {
          records[identity] = 'rejected';
          if (!await preferences.setString(key, _encodeRevocations(records))) {
            throw StateError(message);
          }
        }
        records.remove(identity);
        final saved = records.isEmpty
            ? await preferences.remove(key)
            : await preferences.setString(key, _encodeRevocations(records));
        if (!saved) throw StateError(message);
      }),
      () => mounted && _revocationKeeper == keeper,
      message,
    );

    if (!mounted || _revocationKeeper != keeper) return;
    _unresolvedRevocations.remove(identity);
    _pendingRevocations.remove(identity);
    if (backendRemoved) {
      _committedRevocations.add(identity);
    } else {
      _committedRevocations.remove(identity);
      _rejectedRevocations.remove(identity);
    }
    if (_pendingRevocations.isEmpty) {
      _recoveryUnavailable = false;
      recoveryError = null;
      error = null;
    }
    notifyListeners();
  }

  // Serialize journals across old/new service instances during entry handoff.
  // Entries disappear after their final write, so this retains no session owners.
  static final _journalWrites = <String, Future<void>>{};
  late final String _journalScope = session.options.sessionSlug;
  Future<T> _serializeJournal<T>(Future<T> Function() action) {
    final scope = _journalScope;
    final previous = _journalWrites[scope] ?? Future<void>.value();
    final work = previous.then((_) => action());
    late final Future<T> result;
    result = work.whenComplete(() => _journalOperations.remove(result));
    _journalOperations.add(result);
    late final Future<void> settled;
    settled = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_journalWrites[scope], settled)) {
            _journalWrites.remove(scope);
          }
        });
    _journalWrites[scope] = settled;
    return result;
  }

  String _revocationKey(String keeper) =>
      'session_admission_revocations:${jsonEncode([session.options.sessionSlug, keeper])}';

  String _encodeRevocations(Map<String, String> records) {
    final roster = records is _RevocationJournal ? records.roster : null;
    return jsonEncode(
      roster == null
          ? Map<String, String>.of(records)
          : {
              'version': 1,
              'records': Map<String, String>.of(records),
              'roster': roster,
            },
    );
  }

  Map<String, Object?> _captureRoster(KeeperAdmissionRosterStore store) => {
    'generation': store.keeperGeneration,
    'revision': store.revision,
    'members': store.members.toList()..sort(),
    'awaitingReadiness': store.awaitingReadiness.toList()..sort(),
    'revoked': store.revoked.toList()..sort(),
  };

  Map<String, Object?> _readJournalRoster(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['generation'] is! String ||
        (value['generation'] as String).trim().isEmpty ||
        value['revision'] is! int ||
        (value['revision'] as int) < 0 ||
        (value['revision'] as int) > 9007199254740991) {
      throw const FormatException('Invalid journal roster');
    }
    final lists = <String, List<String>>{};
    for (final name in ['members', 'awaitingReadiness', 'revoked']) {
      final members = value[name];
      if (members is! List ||
          members.any(
            (id) => id is! String || id.trim().isEmpty || id.length > 256,
          ) ||
          members.toSet().length != members.length) {
        throw const FormatException('Invalid journal roster members');
      }
      lists[name] = members.cast<String>().toList();
    }
    if (!lists['members']!.toSet().containsAll(lists['awaitingReadiness']!)) {
      throw const FormatException('Invalid journal readiness');
    }
    return {
      'generation': value['generation'],
      'revision': value['revision'],
      ...lists,
    };
  }

  _RevocationJournal _readRevocations(String? saved) {
    if (saved == null) return _RevocationJournal();
    try {
      var decoded = jsonDecode(saved);
      // Compatibility with the previous post-commit journal format.
      if (decoded is List && decoded.every((value) => value is String)) {
        return _RevocationJournal({
          for (final id in decoded.cast<String>()) id: 'committed',
        });
      }
      Map<String, Object?>? roster;
      if (decoded is Map &&
          decoded['version'] == 1 &&
          decoded['records'] is Map) {
        roster = _readJournalRoster(decoded['roster']);
        decoded = decoded['records'];
      }
      if (decoded is! Map) throw const FormatException('Invalid journal shape');
      final records = _RevocationJournal()..roster = roster;
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! String) {
          throw const FormatException('Invalid journal entry');
        }
        final identity = entry.key as String;
        final status = entry.value as String;
        if (identity.trim().isEmpty ||
            (status != 'intent' &&
                status != 'committed' &&
                status != 'rejected')) {
          throw const FormatException('Invalid journal entry');
        }
        records[identity] = status;
      }
      return records;
    } catch (error) {
      _corruptRemovalJournal = true;
      throw CorruptAdmissionRemovalJournal(error);
    }
  }

  Future<void> resetCorruptRemovalJournal() async {
    if (!_corruptRemovalJournal || !mounted || _detaching || _disconnecting) {
      throw StateError('Removal recovery journal is not resettable');
    }
    final keeper = session.admissionState.roomState.keeper;
    final preferences = await ref.read(
      sessionAdmissionPreferencesProvider.future,
    );
    // The journal may contain revocations that cannot be recovered from its
    // corrupt bytes. Clear the saved roster first so removing the journal can
    // never restore stale admission permissions.
    await ref
        .read(
          keeperAdmissionRosterProvider(
            session.options.sessionSlug,
            keeper,
          ).notifier,
        )
        .clear();
    if (!mounted || session.admissionState.roomState.keeper != keeper) {
      throw StateError('Keeper changed while resetting removal recovery');
    }
    await _serializeJournal(() async {
      if (!await preferences.remove(_revocationKey(keeper))) {
        throw StateError('Could not reset removal recovery journal');
      }
    });
    _corruptRemovalJournal = false;
    _pendingRevocations.clear();
    _committedRevocations.clear();
    _rejectedRevocations.clear();
    _unresolvedRevocations.clear();
    _storageFailure = null;
    _storageStack = null;
    recoveryError = null;
    error = null;
    _recoveryUnavailable = false;
    sync();
    await synchronized;
  }

  Future<PreparedAdmissionRemoval> prepareRemoval(String identity) async {
    requireRemovalReady();
    if (identity.trim().isEmpty || identity == _keeperIdentity) {
      throw StateError('Cannot remove Keeper or empty identity');
    }
    if (_attachedKeeperRoster!.revoked.contains(identity)) {
      throw StateError(
        'Participant was already removed. Retry admission recovery, not backend removal.',
      );
    }
    return await _preparedRemoval(identity);
  }

  Future<PreparedAdmissionRemoval> _preparedRemoval(
    String identity, {
    bool existing = false,
  }) async {
    final keeper = _keeperIdentity!;
    final store = _attachedKeeperRoster!;
    final persist = _saveKeeperRoster!;
    final preferences = await ref.read(
      sessionAdmissionPreferencesProvider.future,
    );
    final key = _revocationKey(keeper);
    bool current() =>
        mounted &&
        _keeperIdentity == keeper &&
        identical(store, _attachedKeeperRoster);
    if (!existing) {
      await _serializeJournal(() async {
        requireRemovalReady();
        final records = _readRevocations(preferences.getString(key));
        if (records.containsKey(identity)) {
          throw StateError(
            'Removal is already pending; reconcile recovery instead',
          );
        }
        records[identity] = 'intent';
        if (!await preferences.setString(key, _encodeRevocations(records))) {
          throw StateError(
            'Could not prepare removal recovery. Participant has not been removed.',
          );
        }
      });
      if (current()) {
        _pendingRevocations.add(identity);
        _keeperController!.setApprovalRequired(true);
      }
    }
    Future<void> reject() {
      if (current()) {
        _unresolvedRevocations.remove(identity);
        _rejectedRevocations.add(identity);
        _syncAdmittedIdentities(_keeperController!.roster);
      }
      return _removalPersistence(
        _serializeJournal(() async {
          final journal = _readRevocations(preferences.getString(key));
          journal[identity] = 'rejected';
          if (!await preferences.setString(key, _encodeRevocations(journal))) {
            throw StateError(
              'Participant was not removed, but recovery cleanup failed. Verify status before reconciling.',
            );
          }
          final records = _readRevocations(preferences.getString(key))
            ..remove(identity);
          final saved = records.isEmpty
              ? await preferences.remove(key)
              : await preferences.setString(key, _encodeRevocations(records));
          if (!saved) {
            throw StateError(
              'Backend rejected removal, but clearing its recovery intent failed. Verify status before reconciling recovery.',
            );
          }
          if (current()) {
            _pendingRevocations.remove(identity);
            _committedRevocations.remove(identity);
            _rejectedRevocations.remove(identity);
            if (_pendingRevocations.isEmpty) {
              error = null;
              recoveryError = null;
              _recoveryUnavailable = false;
            }
            _syncAdmittedIdentities(_keeperController!.roster);
            _keeperController!.setApprovalRequired(
              approvalRequired || _pendingRevocations.isNotEmpty,
            );
          }
        }),
        current,
        'Backend removal was rejected. Admission recovery cleanup is pending; retry recovery.',
      );
    }

    Future<void> commit() {
      // No storage Future may precede live revocation after backend success.
      if (!current()) {
        store.revoked.add(identity);
        store.replace(
          store.members.where((id) => id != identity).toList(),
          store.revision + 1,
          awaitingReadiness: store.awaitingReadiness
              .where((id) => id != identity)
              .toList(),
        );
      }
      if (mounted && session.admissionState.roomState.keeper == keeper) {
        _unresolvedRevocations.remove(identity);
        _pendingRevocations.add(identity);
        _committedRevocations.add(identity);
        if (current()) {
          _keeperController!.revoke(identity, persist: false);
          _syncAdmittedIdentities(_keeperController!.roster);
        } else {
          _syncAdmittedIdentities(_admittedIdentities);
        }
      }
      final snapshot = _captureRoster(store);
      return _removalPersistence(
        _serializeJournal(() async {
          final records = _readRevocations(preferences.getString(key));
          records[identity] = 'committed';
          records.roster = snapshot;
          if (!await preferences.setString(key, _encodeRevocations(records))) {
            throw StateError(
              'Participant removed; recovery persistence incomplete. Retry admission recovery, not removal.',
            );
          }
          if (current()) {
            _keeperController!.acknowledgeJournaledRoster(
              keeperGeneration: snapshot['generation']! as String,
              revision: snapshot['revision']! as int,
              members: snapshot['members']! as List<String>,
              awaitingReadiness: snapshot['awaitingReadiness']! as List<String>,
              revoked: snapshot['revoked']! as List<String>,
            );
            _syncAdmittedIdentities(_keeperController!.roster);
          }
          // Always persist, even when an earlier failed write already changed the store.
          await persist();
          records.remove(identity);
          final saved = records.isEmpty
              ? await preferences.remove(key)
              : await preferences.setString(key, _encodeRevocations(records));
          if (!saved) {
            throw StateError(
              'Participant removed; recovery cleanup incomplete. Retry admission recovery, not removal.',
            );
          }
          if (current()) {
            _pendingRevocations.remove(identity);
            _committedRevocations.remove(identity);
            if (_pendingRevocations.isEmpty) {
              error = null;
              recoveryError = null;
              _recoveryUnavailable = false;
            }
            notifyListeners();
            _keeperController!.setApprovalRequired(
              approvalRequired || _pendingRevocations.isNotEmpty,
            );
          }
        }),
        current,
        'Participant removed. Admission recovery persistence is incomplete; retry recovery, not removal.',
      );
    }

    return PreparedAdmissionRemoval(
      commit: commit,
      reject: reject,
      unknown: () async {
        if (current()) {
          _unresolvedRevocations.add(identity);
          _pendingRevocations.add(identity);
          _syncAdmittedIdentities(_keeperController!.roster);
          setState(() {
            _recoveryUnavailable = true;
            recoveryError =
                'Removal outcome unknown. Verify participant status, then reconcile admission recovery. Do not remove again.';
            error = recoveryError;
          });
        }
      },
    );
  }

  Future<void> _removalPersistence(
    Future<void> work,
    bool Function() current,
    String message,
  ) async {
    try {
      await work;
    } catch (_) {
      if (current()) {
        setState(() {
          _recoveryUnavailable = true;
          recoveryError = message;
          error = message;
        });
      }
      rethrow;
    }
  }

  void _restoreJournalRoster(
    _RevocationJournal records,
    KeeperAdmissionRosterStore store,
    String keeper,
  ) {
    final journalRoster = records.roster;
    if (journalRoster != null) {
      final generation = journalRoster['generation']! as String;
      if (store.keeperGeneration != generation) {
        if (_keeperController != null) {
          throw StateError('Journal authority does not match active Keeper');
        }
        store.restoreJournalGeneration(generation);
      }
      final revision = journalRoster['revision']! as int;
      if (revision >= store.revision) {
        final members = journalRoster['members']! as List<String>;
        final revoked = journalRoster['revoked']! as List<String>;
        if (revision == store.revision &&
            (!setEquals(members.toSet(), store.members.toSet()) ||
                !setEquals(revoked.toSet(), store.revoked) ||
                !setEquals(
                  (journalRoster['awaitingReadiness']! as List<String>).toSet(),
                  store.awaitingReadiness.toSet(),
                ))) {
          throw StateError('Conflicting committed roster snapshots');
        }
        if (members.contains(keeper) ||
            revoked.contains(keeper) ||
            members.any(revoked.contains)) {
          throw const FormatException('Unsafe journal roster');
        }
        store.revoked
          ..clear()
          ..addAll(revoked);
        store.replace(
          members,
          revision,
          awaitingReadiness:
              journalRoster['awaitingReadiness']! as List<String>,
        );
      }
    }
  }

  Future<void> _recoverRevocations(
    String keeper,
    KeeperAdmissionRosterStore store,
    Future<void> Function() persist, {
    bool serialized = false,
  }) async {
    if (!serialized) {
      return await _serializeJournal(
        () => _recoverRevocations(keeper, store, persist, serialized: true),
      );
    }
    if (!mounted) throw StateError('Admission owner closed during recovery');
    final preferences = await ref.read(
      sessionAdmissionPreferencesProvider.future,
    );
    final key = _revocationKey(keeper);
    final records = _readRevocations(preferences.getString(key));
    _restoreJournalRoster(records, store, keeper);
    if (!mounted || session.admissionState.roomState.keeper != keeper) {
      throw StateError('Keeper changed during removal recovery');
    }
    if (_revocationKeeper == keeper) {
      for (final identity in _committedRevocations) {
        records[identity] = 'committed';
      }
      for (final identity in _rejectedRevocations) {
        records[identity] = 'rejected';
      }
      if (records.isNotEmpty &&
          !await preferences.setString(key, _encodeRevocations(records))) {
        throw StateError(
          'Could not save known removal outcomes. Retry recovery.',
        );
      }
    }
    _pendingRevocations
      ..clear()
      ..addAll(
        records.entries.where((e) => e.value != 'rejected').map((e) => e.key),
      );
    _committedRevocations
      ..clear()
      ..addAll(
        records.entries.where((e) => e.value == 'committed').map((e) => e.key),
      );
    _unresolvedRevocations
      ..clear()
      ..addAll(
        records.entries.where((e) => e.value == 'intent').map((e) => e.key),
      );
    if (records.isEmpty) {
      if (_recoveryUnavailable) await persist();
      _recoveryUnavailable = false;
      recoveryError = null;
      error = null;
      return;
    }
    final committed = _committedRevocations.toSet();
    final needsRestriction =
        store.members.any(committed.contains) ||
        !store.revoked.containsAll(committed);
    if (needsRestriction) {
      store.revoked.addAll(committed);
      store.replace(
        store.members.where((id) => !committed.contains(id)).toList(),
        store.revision + 1,
        awaitingReadiness: store.awaitingReadiness
            .where((id) => !committed.contains(id))
            .toList(),
      );
    }
    // Never infer successful persistence from equality with a mutated in-memory store.
    await persist();
    final remaining = Map<String, String>.of(records)
      ..removeWhere(
        (id, status) => committed.contains(id) || status == 'rejected',
      );
    final saved = remaining.isEmpty
        ? await preferences.remove(key)
        : await preferences.setString(key, _encodeRevocations(remaining));
    if (!saved) {
      throw StateError(
        'Could not reconcile removed participants. Retry recovery.',
      );
    }
    _pendingRevocations.removeAll(committed);
    _rejectedRevocations.clear();
    _committedRevocations.removeAll(committed);
    _recoveryUnavailable = false;
    recoveryError = null;
    _storageFailure = null;
    _storageStack = null;
    if (remaining.isNotEmpty) {
      error =
          'Removal outcome unknown. Verify participant status before reconciling recovery.';
    } else {
      error = null;
    }
  }

  void requireRemovalReady() {
    if (!mounted ||
        _detaching ||
        _disconnecting ||
        _keeperController == null ||
        _recoveryUnavailable ||
        _pendingRevocations.isNotEmpty) {
      throw StateError(
        'Admission recovery is unavailable. Retry recovery before removing participants.',
      );
    }
  }

  Future<RoomState> withRevokedAdmission(
    String identity,
    Future<RoomState> Function() operation,
  ) async {
    final reservation = await reserveUnban(identity);
    try {
      return await reservation.run(operation);
    } finally {
      reservation.cancel();
    }
  }

  /// Durably revokes admission and reserves it against approval during unban.
  /// The caller must run the unmodified backend future or cancel the reservation.
  Future<AdmissionUnbanReservation> reserveUnban(String identity) async {
    requireRemovalReady();
    if (identity.trim().isEmpty || identity == _keeperIdentity) {
      throw StateError('Cannot remove Keeper or empty identity');
    }
    final controller = _keeperController!;
    final keeper = _keeperIdentity!;
    final scope = session.options.sessionSlug;
    final guardToken = AdmissionApprovalGuard.reserve(scope, identity);
    void validate() {
      requireRemovalReady();
      if (!identical(_keeperController, controller) ||
          _keeperIdentity != keeper ||
          _currentKeeperIdentity() != keeper ||
          !identical(_owners[_ownedScope], this)) {
        throw StateError('Admission ownership changed before unban');
      }
    }

    try {
      await revokeRemovedParticipant(identity);
      validate();
      late final AdmissionUnbanReservation reservation;
      reservation = AdmissionUnbanReservation._(
        _reservationOwner,
        () => AdmissionApprovalGuard.release(scope, identity, guardToken),
        validate,
        () => _unbanReservations.remove(reservation),
      );
      _unbanReservations.add(reservation);
      return reservation;
    } catch (_) {
      AdmissionApprovalGuard.release(scope, identity, guardToken);
      rethrow;
    }
  }

  /// Ensures a removed participant's admission is durably revoked.
  Future<void> revokeRemovedParticipant(String identity) async {
    requireRemovalReady();
    if (identity.trim().isEmpty || identity == _keeperIdentity) {
      throw StateError('Cannot remove Keeper or empty identity');
    }
    if (_attachedKeeperRoster!.revoked.contains(identity)) {
      if (!await _persistRoster(_saveKeeperRoster!)) {
        throw StateError(
          'Could not persist admission revocation. Retry recovery.',
        );
      }
      requireRemovalReady();
      return;
    }
    final removal = await prepareRemoval(identity);
    await removal.commit();
  }
}

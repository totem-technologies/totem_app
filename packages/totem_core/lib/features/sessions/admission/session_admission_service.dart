import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart'
    hide Session, SessionOptions;
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/admission/admission_controllers.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:totem_core/features/sessions/admission/declined_session_participants.dart';
import 'package:totem_core/features/sessions/admission/keeper_admission_roster.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';

/// Admission coordinator retained by the active session, independently of UI.
class SessionAdmissionService extends ChangeNotifier {
  SessionAdmissionService(this.ref, this.session, {this.now});

  LiveKitAdmissionTransport? _transport;
  KeeperAdmissionController? _keeperController;
  ClientAdmissionRosterController? _clientController;
  // Cancelled by _detachAdmission.
  // ignore: cancel_subscriptions
  StreamSubscription<void>? _keeperChanges;
  // Cancelled by _detachAdmission.
  // ignore: cancel_subscriptions
  StreamSubscription<AdmissionRoster?>? _clientChanges;

  Room? _room;
  String? _keeperIdentity;
  KeeperAdmissionRosterStore? _attachedKeeperRoster;
  Future<void> Function()? _saveKeeperRoster;
  Future<void> Function()? _clearKeeperRoster;
  Future<void> Function()? _clearDeclinedParticipants;
  bool _sessionEnded = false;
  bool _busy = false;
  final Ref ref;
  final SessionController session;
  final DateTime Function()? now;
  Set<String> _admittedIdentities = const {};
  Set<String> get admittedIdentities => _admittedIdentities;
  bool approvalRequired = true;
  void setApprovalRequired(bool value) {
    approvalRequired = value;
    sync();
  }

  bool _disposed = false;
  bool get mounted => !_disposed && ref.mounted;
  String? error;
  bool _recoveryUnavailable = false;
  final Set<String> _pendingRevocations = {};
  Future<void> disconnect() async {
    await _synchronization;
    await _detachAdmission();
  }

  KeeperAdmissionController? get keeperController => _keeperController;
  bool get busy => _busy;
  void setState(void Function() action) {
    if (!mounted) return;
    action();
    notifyListeners();
  }

  String? _observedKeeper;
  final List<ProviderSubscription<dynamic>> _rosterSubscriptions = [];
  final List<ProviderSubscription<dynamic>> _recoverySubscriptions = [];
  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in [
      ..._recoverySubscriptions,
      ..._rosterSubscriptions,
    ]) {
      subscription.close();
    }
    final detached = _detachAdmission(
      clearAdmitted: false,
      endSession: _sessionEnded,
    );
    super.dispose();
    await detached;
    await _synchronization;
  }

  Future<void> get synchronized => _synchronization;
  Future<void> _synchronization = Future.value();
  void sync() {
    if (!mounted) return;
    _synchronization = _synchronization
        .then((_) async {
          if (mounted) await _sync();
        })
        .catchError((Object failure, StackTrace stackTrace) {
          if (mounted) {
            _syncAdmittedIdentities(const []);
            error = 'Admission unavailable. Retry recovery.';
            notifyListeners();
          }
          ErrorHandler.logError(
            failure,
            stackTrace: stackTrace,
            message: 'Could not synchronize admission',
          );
        });
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final state = session.admissionState;
    final event = session.session;
    final room = session.room;
    final keeperIdentity = state.roomState.keeper;
    _sessionEnded =
        state.roomState.status == RoomStatus.ended || event?.ended == true;
    final connected = state.connection.state == RoomConnectionState.connected;
    final active =
        connected &&
        state.roomState.status != RoomStatus.ended &&
        event?.ended != true &&
        room != null &&
        keeperIdentity.isNotEmpty;
    if (!active) {
      if (_hasAdmission) {
        await _detachAdmission(endSession: _sessionEnded);
      }
      return;
    }

    final isKeeper = room.localParticipant?.identity == keeperIdentity;
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

    await _detachAdmission(clearAdmitted: !isKeeper);
    if (!mounted) return;
    if (isKeeper) {
      await _recoverRevocations(
        keeperIdentity,
        restoredRoster!,
        ref.read(rosterProvider.notifier).persist,
      );
      if (!mounted || !identical(session.room, room)) return;
    }
    final transport = LiveKitAdmissionTransport(room, now: now);
    _transport = transport;
    _room = room;
    _keeperIdentity = keeperIdentity;

    if (isKeeper) {
      _attachedKeeperRoster = restoredRoster;
      final rosterNotifier = ref.read(rosterProvider.notifier);
      _saveKeeperRoster = rosterNotifier.persist;
      _clearKeeperRoster = rosterNotifier.clear;
      _clearDeclinedParticipants = ref
          .read(
            declinedSessionParticipantsProvider(
              session.options.sessionSlug,
              keeperIdentity,
            ).notifier,
          )
          .clear;
      final controller = KeeperAdmissionController(
        channel: transport,
        keeperIdentity: _currentKeeperIdentity,
        isSessionStarted: () =>
            session.admissionState.roomState.status == RoomStatus.active,
        sessionIdentity: session.options.sessionSlug,
        rosterStore: restoredRoster,
        approvalRequired:
            approvalRequired ||
            _recoveryUnavailable ||
            _pendingRevocations.isNotEmpty,
        declinedIdentities: declinedIdentities!,
        now: now,
      );
      _keeperController = controller;
      _pendingRevocations.forEach(controller.revoke);
      if (_pendingRevocations.isNotEmpty &&
          await _persistRoster(rosterNotifier.persist)) {
        _pendingRevocations.clear();
      }
      if (!mounted || !identical(_keeperController, controller)) return;
      var persistedRosterRevision = controller.rosterRevision;
      final savingRosterRevisions = <int>{};
      _syncAdmittedIdentities(controller.roster);
      _keeperChanges = controller.changes.listen((_) {
        if (!mounted || !identical(_keeperController, controller)) return;
        final revision = controller.rosterRevision;
        final persist = _saveKeeperRoster;
        if (persist != null &&
            revision != persistedRosterRevision &&
            savingRosterRevisions.add(revision)) {
          unawaited(
            _persistRoster(persist).then((saved) {
              savingRosterRevisions.remove(revision);
              if (saved && revision > persistedRosterRevision) {
                persistedRosterRevision = revision;
              }
            }),
          );
        }
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
      _syncAdmittedIdentities(controller.roster?.members ?? const []);
      _clientChanges = controller.changes.listen((roster) {
        if (!mounted || !identical(_clientController, controller)) return;
        _syncAdmittedIdentities(roster?.members ?? const []);
      });
    }
    setState(() {});
  }

  String _currentKeeperIdentity() =>
      mounted ? session.admissionState.roomState.keeper : '';

  bool get _hasAdmission =>
      _keeperController != null ||
      _clientController != null ||
      _transport != null;

  Future<bool> _persistRoster(Future<void> Function() persist) async {
    final owner = _keeperController;
    try {
      await persist();
      if (mounted && identical(owner, _keeperController)) {
        _recoveryUnavailable = false;
        error = null;
        notifyListeners();
      }
      return true;
    } catch (failure, stackTrace) {
      ErrorHandler.logError(
        failure,
        stackTrace: stackTrace,
        message: 'Could not save Keeper admission recovery',
      );
      if (mounted && identical(owner, _keeperController)) {
        _recoveryUnavailable = true;
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
    }
  }

  void _syncAdmittedIdentities(Iterable<String> identities) {
    if (!mounted) return;
    final roster = Set<String>.unmodifiable(identities);
    session.updateAdmittedMediaRecipients(roster);
    _admittedIdentities = roster;
    notifyListeners();
  }

  Future<void> _detachAdmission({
    bool clearAdmitted = true,
    bool endSession = false,
  }) {
    if (endSession && ref.mounted) {
      final clearRoster = _clearKeeperRoster;
      final clearDeclined = _clearDeclinedParticipants;
      if (clearRoster != null) unawaited(_clearAdmissionData(clearRoster));
      if (clearDeclined != null) unawaited(_clearAdmissionData(clearDeclined));
    } else if (ref.mounted) {
      final persist = _saveKeeperRoster;
      if (persist != null) unawaited(_persistRoster(persist));
    }
    _attachedKeeperRoster = null;
    _saveKeeperRoster = null;
    _clearKeeperRoster = null;
    _clearDeclinedParticipants = null;
    final keeperController = _keeperController;
    final clientController = _clientController;
    final transport = _transport;
    final keeperChanges = _keeperChanges;
    final clientChanges = _clientChanges;
    _keeperController = null;
    _clientController = null;
    _transport = null;
    _keeperChanges = null;
    _clientChanges = null;
    _room = null;
    _keeperIdentity = null;
    _busy = false;
    if (clearAdmitted) _syncAdmittedIdentities(const []);

    final keeperDispose = keeperController?.dispose();
    final clientDispose = clientController?.dispose();
    return Future.wait<void>([
      if (keeperChanges != null) keeperChanges.cancel(),
      if (clientChanges != null) clientChanges.cancel(),
      ?keeperDispose,
      ?clientDispose,
    ]).then((_) => transport?.dispose());
  }

  Future<void> decide(
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

  Future<bool> admitAll() async {
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

  Future<void> retryRecovery() async {
    final controller = _keeperController;
    final persist = _saveKeeperRoster;
    if (controller == null || persist == null) {
      sync();
      return;
    }
    _pendingRevocations.forEach(controller.revoke);
    if (await _persistRoster(persist)) {
      await _serializeJournal(() async {
        final preferences = await ref.read(
          sessionAdmissionPreferencesProvider.future,
        );
        final key = _revocationKey(_keeperIdentity!);
        final saved = preferences.getString(key);
        if (saved != null) {
          final remaining = (jsonDecode(saved) as List).cast<String>().toSet()
            ..removeAll(_pendingRevocations);
          final cleared = remaining.isEmpty
              ? await preferences.remove(key)
              : await preferences.setString(
                  key,
                  jsonEncode(remaining.toList()),
                );
          if (!cleared) {
            throw StateError(
              'Could not save removal reconciliation. Retry recovery.',
            );
          }
        }
        _pendingRevocations.clear();
        controller.setApprovalRequired(approvalRequired);
      });
    }
  }

  Future<void> _journalTail = Future.value();
  Future<T> _serializeJournal<T>(Future<T> Function() action) {
    final result = _journalTail.then((_) => action());
    _journalTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  String _revocationKey(String keeper) =>
      'session_admission_revocations:${jsonEncode([session.options.sessionSlug, keeper])}';

  /// Capture storage before the backend operation, so its successful completion
  /// can leave a durable recovery intent even after the session has disposed.
  Future<Future<void> Function(String)> prepareRemoval() async {
    requireRemovalReady();
    final keeper = _keeperIdentity!;
    final preferences = await ref.read(
      sessionAdmissionPreferencesProvider.future,
    );
    requireRemovalReady();
    final key = _revocationKey(keeper);
    Future<void> complete(String identity) => _serializeJournal(() async {
      final saved = preferences.getString(key);
      final pending = <String>{
        if (saved != null) ...(jsonDecode(saved) as List).cast<String>(),
        identity,
      };
      if (!await preferences.setString(key, jsonEncode(pending.toList()))) {
        _pendingRevocations.add(identity);
        throw StateError(
          'Backend removal succeeded, but recovery could not be saved. Keep this Session open and retry recovery.',
        );
      }
      await revokeRemovedParticipant(identity);
      final remaining = preferences.getString(key);
      final pendingAfter = <String>{
        if (remaining != null)
          ...(jsonDecode(remaining) as List).cast<String>(),
      }..remove(identity);
      final cleared = pendingAfter.isEmpty
          ? await preferences.remove(key)
          : await preferences.setString(key, jsonEncode(pendingAfter.toList()));
      if (!cleared) {
        _pendingRevocations.add(identity);
        throw StateError(
          'Participant removed; recovery reconciliation is still pending. Retry recovery.',
        );
      }
    });
    return complete;
  }

  Future<void> _recoverRevocations(
    String keeper,
    KeeperAdmissionRosterStore store,
    Future<void> Function() persist,
  ) async {
    final preferences = await ref.read(
      sessionAdmissionPreferencesProvider.future,
    );
    final key = _revocationKey(keeper);
    await _journalTail;
    final saved = preferences.getString(key);
    if (saved == null) return;
    final pending = (jsonDecode(saved) as List).cast<String>().toSet();
    final members = store.members
        .where((member) => !pending.contains(member))
        .toList();
    final awaiting = store.awaitingReadiness
        .where((member) => !pending.contains(member))
        .toList();
    if (members.length != store.members.length ||
        awaiting.length != store.awaitingReadiness.length) {
      store.replace(members, store.revision + 1, awaitingReadiness: awaiting);
      await persist();
    }
    if (!await preferences.remove(key)) {
      throw StateError(
        'Could not reconcile removed participants. Retry recovery.',
      );
    }
  }

  void requireRemovalReady() {
    if (!mounted ||
        _keeperController == null ||
        _recoveryUnavailable ||
        _pendingRevocations.isNotEmpty) {
      throw StateError(
        'Admission recovery is unavailable. Retry recovery before removing participants.',
      );
    }
  }

  Future<void> revokeRemovedParticipant(String identity) async {
    _pendingRevocations.add(identity);
    final controller = _keeperController;
    if (!mounted || controller == null || _saveKeeperRoster == null) {
      throw StateError(
        'Backend removal succeeded. Admission revocation is pending; reconnect and retry recovery.',
      );
    }
    controller.revoke(identity);
    if (!await _persistRoster(_saveKeeperRoster!) ||
        !mounted ||
        !identical(controller, _keeperController)) {
      throw StateError(
        'Participant removed by the server; admission recovery needs reconciliation. Keep this Session open and retry.',
      );
    }
    _pendingRevocations.remove(identity);
    controller.setApprovalRequired(approvalRequired);
  }
}

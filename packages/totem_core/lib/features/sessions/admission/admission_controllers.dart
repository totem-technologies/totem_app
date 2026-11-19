import 'dart:async';
import 'dart:math';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/features/sessions/admission/admission_protocol.dart';
import 'package:totem_core/features/sessions/admission/admission_transport.dart';
import 'package:uuid/uuid.dart';

void _admissionBreadcrumb(String name, {Map<String, Object?> data = const {}}) {
  unawaited(
    Sentry.addBreadcrumb(
      Breadcrumb(
        category: 'admission.roster',
        message: name,
        level: SentryLevel.info,
        data: data,
      ),
    ),
  );
}

enum AdmissionStatus {
  idle,
  pending,
  approved,
  denied,
  expired,
  cancelled,
  ended,
  failed,
}

enum AdmissionKeeperAvailability { checking, absent, unresponsive, responsive }

/// The caller owns [channel] and must dispose this controller before the room.
/// Changes are emitted for UI consumers; read [status] after subscribing.
class PendingAdmissionController {
  PendingAdmissionController({
    required this.channel,
    required this.keeperIdentity,
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? const Uuid().v4,
       _status = channel.hasEnded
           ? AdmissionStatus.ended
           : AdmissionStatus.idle {
    _subscription = channel.events.listen(_onEvent);
  }

  final AdmissionChannel channel;
  final String Function() keeperIdentity;
  final DateTime Function() _now;
  final String Function() _newId;
  final _changes = StreamController<AdmissionStatus>.broadcast();
  late final StreamSubscription<AdmissionEvent> _subscription;
  Timer? _expiration;
  late DateTime _waitingDeadline;
  Timer? _keeperAvailabilityTimer;
  AdmissionRequest? _request;
  AdmissionCancel? _cancellation;
  bool _isReturningParticipant = false;
  bool? _sessionStartedAtAdmission;
  AdmissionStatus _status;
  AdmissionKeeperAvailability _keeperAvailability =
      AdmissionKeeperAvailability.checking;
  bool _disposed = false;

  Stream<AdmissionStatus> get changes => _changes.stream;
  AdmissionStatus get status => _status;
  AdmissionRequest? get request => _request;
  bool get isReturningParticipant => _isReturningParticipant;
  bool? get sessionStartedAtAdmission => _sessionStartedAtAdmission;
  AdmissionKeeperAvailability get keeperAvailability => _keeperAvailability;

  Future<AdmissionRequest> requestAdmission({
    required String displayName,
    DateTime? deadline,
  }) async {
    if (_disposed ||
        channel.hasEnded ||
        _status == AdmissionStatus.pending ||
        _status == AdmissionStatus.ended ||
        _status == AdmissionStatus.failed) {
      throw StateError('Admission unavailable');
    }
    final keeper = keeperIdentity();
    final local = channel.localIdentity;
    final name = displayName.trim();
    if (keeper.isEmpty ||
        local.isEmpty ||
        keeper == local ||
        name.isEmpty ||
        name.length > 120) {
      throw ArgumentError('Invalid admission identities or display name');
    }
    final now = _now();
    // Protocol validity must outlive waiting so approved users can activate
    // their room and send a joined receipt after the waiting deadline.
    final candidate = now
        .add(AdmissionProtocol.requestLifetime)
        .millisecondsSinceEpoch;
    final previous = _request?.expiresAt.millisecondsSinceEpoch;
    final expirationMillis = previous != null && candidate <= previous
        ? previous + 1
        : candidate;
    if (expirationMillis - _now().millisecondsSinceEpoch >
        AdmissionProtocol.maxRequestLifetime.inMilliseconds) {
      throw StateError('Too many admission requests in a short time');
    }
    _expiration?.cancel();
    _cancellation = null;
    _isReturningParticipant = false;
    _sessionStartedAtAdmission = null;
    final packet = AdmissionRequest(
      id: _newId(),
      senderIdentity: local,
      recipientIdentity: keeper,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expirationMillis),
      displayName: name,
    );
    _request = packet;
    final waitingDeadline =
        deadline != null && deadline.isBefore(packet.expiresAt)
        ? deadline
        : packet.expiresAt;
    _waitingDeadline = waitingDeadline;
    if (!now.isBefore(waitingDeadline)) {
      _setStatus(AdmissionStatus.expired);
      return packet;
    }
    _setStatus(AdmissionStatus.pending);
    _expiration = Timer(waitingDeadline.difference(_now()), _expire);
    _startKeeperAvailabilityCheck();
    if (channel.isPresent(keeper)) await _sendBestEffort(packet);
    return packet;
  }

  /// Cancels locally even when the keeper is offline; sends a targeted cancel
  /// now and again on presence/reconnect until the request expires.
  Future<void> cancel() async {
    if (_disposed ||
        (_status != AdmissionStatus.pending &&
            _status != AdmissionStatus.cancelled)) {
      return;
    }
    final request = _request!;
    _cancellation ??= AdmissionCancel(
      id: request.id,
      senderIdentity: request.senderIdentity,
      recipientIdentity: request.recipientIdentity,
      expiresAt: request.expiresAt,
    );
    _expiration?.cancel();
    _keeperAvailabilityTimer?.cancel();
    if (_status != AdmissionStatus.cancelled) {
      _setStatus(AdmissionStatus.cancelled);
    }
    if (_now().isBefore(request.expiresAt) &&
        channel.isPresent(request.recipientIdentity)) {
      unawaited(_sendBestEffort(_cancellation!));
    }
  }

  Future<void> _sendBestEffort(AdmissionPacket packet) async {
    try {
      await channel.send(packet);
    } catch (_) {
      // The pending request/cancel is retried on presence or reconnect.
    }
  }

  void _onEvent(AdmissionEvent event) {
    if (_disposed) return;
    if (event is AdmissionRoomEnded) {
      _expiration?.cancel();
      _keeperAvailabilityTimer?.cancel();
      if (_status != AdmissionStatus.ended) _setStatus(AdmissionStatus.ended);
      return;
    }
    if (_status != AdmissionStatus.pending &&
        _status != AdmissionStatus.cancelled) {
      return;
    }
    if (event is AdmissionRoomDisconnected) {
      if (_status == AdmissionStatus.pending) {
        _expiration?.cancel();
        _keeperAvailabilityTimer?.cancel();
        _setStatus(AdmissionStatus.failed);
      }
      return;
    }
    final request = _request!;
    final now = _now();
    if (!now.isBefore(request.expiresAt) ||
        (_status == AdmissionStatus.pending &&
            !now.isBefore(_waitingDeadline))) {
      if (_status == AdmissionStatus.pending) _expire();
      return;
    }
    switch (event) {
      case AdmissionPacketReceived(packet: final AdmissionDecision decision):
        if (_status != AdmissionStatus.pending ||
            decision.id != request.id ||
            decision.senderIdentity != request.recipientIdentity ||
            decision.senderIdentity != keeperIdentity() ||
            decision.recipientIdentity != channel.localIdentity ||
            decision.expiresAt != request.expiresAt) {
          return;
        }
        _expiration?.cancel();
        _isReturningParticipant =
            decision.approved && decision.isReturningParticipant;
        _sessionStartedAtAdmission = decision.approved
            ? decision.sessionStartedAtAdmission
            : null;
        _setStatus(
          decision.approved ? AdmissionStatus.approved : AdmissionStatus.denied,
        );
      case AdmissionPacketReceived(packet: final AdmissionHello hello):
        if (hello.senderIdentity == request.recipientIdentity &&
            hello.senderIdentity == keeperIdentity() &&
            hello.recipientIdentity == channel.localIdentity) {
          // An authenticated hello proves the Keeper can receive packets even
          // before LiveKit updates remoteParticipants after a reconnect.
          _setKeeperAvailability(AdmissionKeeperAvailability.responsive);
          unawaited(_sendBestEffort(_cancellation ?? request));
        }
      case AdmissionConnectionRestored():
        if (_keeperAvailability != AdmissionKeeperAvailability.responsive) {
          _startKeeperAvailabilityCheck();
        }
        _resendIfPresent();
      case AdmissionPresenceChanged(:final identity, present: true):
        if (identity == request.recipientIdentity) {
          if (_keeperAvailability != AdmissionKeeperAvailability.responsive) {
            _startKeeperAvailabilityCheck(isPresent: true);
          }
          // LiveKit emits this event before adding the participant to its map.
          unawaited(_sendBestEffort(_cancellation ?? request));
        }
      case AdmissionPresenceChanged(:final identity, present: false):
        if (identity == request.recipientIdentity &&
            _status == AdmissionStatus.pending) {
          _keeperAvailabilityTimer?.cancel();
          _setKeeperAvailability(AdmissionKeeperAvailability.absent);
        }
      default:
        break;
    }
  }

  void _resendIfPresent() {
    final request = _request!;
    if (keeperIdentity() == request.recipientIdentity &&
        channel.isPresent(request.recipientIdentity)) {
      // A lost packet is retried only on presence/reconnect, never by polling.
      unawaited(_sendBestEffort(_cancellation ?? request));
    }
  }

  void _startKeeperAvailabilityCheck({bool? isPresent}) {
    if (_disposed || _status != AdmissionStatus.pending) {
      _keeperAvailabilityTimer?.cancel();
      return;
    }
    final request = _request!;
    _keeperAvailabilityTimer?.cancel();
    if (!(isPresent ?? channel.isPresent(request.recipientIdentity))) {
      _setKeeperAvailability(AdmissionKeeperAvailability.absent);
      return;
    }
    _setKeeperAvailability(AdmissionKeeperAvailability.checking);
    _keeperAvailabilityTimer = Timer(const Duration(seconds: 10), () {
      if (!_disposed && _status == AdmissionStatus.pending) {
        _setKeeperAvailability(AdmissionKeeperAvailability.unresponsive);
      }
    });
  }

  void _setKeeperAvailability(AdmissionKeeperAvailability next) {
    if (_keeperAvailability == next) return;
    if (next != AdmissionKeeperAvailability.checking) {
      _keeperAvailabilityTimer?.cancel();
    }
    _keeperAvailability = next;
    if (_status == AdmissionStatus.pending) _changes.add(_status);
  }

  void _expire() {
    if (_status == AdmissionStatus.pending) _setStatus(AdmissionStatus.expired);
  }

  void _setStatus(AdmissionStatus next) {
    if (next != AdmissionStatus.pending) _keeperAvailabilityTimer?.cancel();
    _status = next;
    _changes.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _expiration?.cancel();
    _keeperAvailabilityTimer?.cancel();
    await Future.wait<void>([
      Future<void>.sync(() => _subscription.cancel()),
      Future<void>.sync(() async {
        await _changes.close();
      }),
    ]);
  }
}

enum KeeperAdmissionStatus {
  requested,
  joining,
  joined,
  joinFailed,
  timedOut,
  denied,
  cancelled,
  expired,
}

/// A snapshot of one participant's latest admission attempt.
final class KeeperAdmissionAttempt {
  const KeeperAdmissionAttempt(this.request, this.status, {this.joinDeadline});

  final AdmissionRequest request;
  final KeeperAdmissionStatus status;
  final DateTime? joinDeadline;
}

/// Explicit process-local ownership for a keeper roster across controller
/// recreation. It is never populated from room metadata or remote packets.
final class KeeperAdmissionRosterStore {
  KeeperAdmissionRosterStore({String? keeperGeneration})
    : _keeperGeneration = keeperGeneration ?? const Uuid().v4();

  String _keeperGeneration;
  final _members = <String>{};
  final _awaitingReadiness = <String>{};
  final revoked = <String>{};
  var _revision = 0;

  String get keeperGeneration => _keeperGeneration;
  int get revision => _revision;
  Iterable<String> get members => _members;
  Iterable<String> get awaitingReadiness => _awaitingReadiness;

  /// Restore an authority recorded in the write-ahead journal before attachment.
  void restoreJournalGeneration(String generation) {
    if (_revision != 0 || _members.isNotEmpty || revoked.isNotEmpty) {
      throw StateError('Cannot replace an initialized roster generation');
    }
    _keeperGeneration = generation;
  }

  void replace(
    Iterable<String> members,
    int revision, {
    Iterable<String> awaitingReadiness = const [],
  }) {
    _members
      ..clear()
      ..addAll(members);
    _awaitingReadiness
      ..clear()
      ..addAll(awaitingReadiness);
    _revision = revision;
  }

  void clear() {
    revoked.clear();
    replace(const [], 0);
  }
}

/// Coordinates approvals and unban reservations across Keeper controller generations.
final class AdmissionApprovalGuard {
  static final _approvals = <(String, String)>{};
  static final _reservations = <(String, String), Object>{};

  static Object reserve(String session, String identity) {
    final key = (session, identity);
    if (_approvals.contains(key) || _reservations.containsKey(key)) {
      throw StateError('Admission decision or unban is already in progress');
    }
    final token = Object();
    _reservations[key] = token;
    return token;
  }

  static void release(String session, String identity, [Object? token]) {
    final key = (session, identity);
    if (token == null || identical(_reservations[key], token)) {
      _reservations.remove(key);
    }
  }

  static bool beginApproval(String session, String identity) {
    final key = (session, identity);
    return !_reservations.containsKey(key) && _approvals.add(key);
  }

  static void endApproval(String session, String identity) {
    _approvals.remove((session, identity));
  }
}

/// Keeper-side queue with one decision per sender + request ID. Decisions are
/// retained while the request is valid so reconnect resends get the same reply.
class KeeperAdmissionController {
  KeeperAdmissionController({
    required this.channel,
    required this.keeperIdentity,
    this.isSessionStarted,
    String? sessionIdentity,
    String? keeperGeneration,
    KeeperAdmissionRosterStore? rosterStore,
    this.persistRoster,
    this._approvalRequired = true,
    Set<String> declinedIdentities = const {},
    Set<String> quarantinedIdentities = const {},
    DateTime Function()? now,
    String Function()? newId,
  }) : _sessionIdentity = sessionIdentity ?? '',

       _declinedIdentities = Set.of(declinedIdentities),
       _quarantinedIdentities = Set.of(quarantinedIdentities),
       _rosterStore = rosterStore,
       _keeperGeneration =
           keeperGeneration ??
           rosterStore?.keeperGeneration ??
           const Uuid().v4(),
       _now = now ?? DateTime.now,
       _newId = newId ?? const Uuid().v4,
       _ended = channel.hasEnded {
    if (rosterStore != null &&
        keeperGeneration != null &&
        keeperGeneration != rosterStore.keeperGeneration) {
      throw ArgumentError.value(
        keeperGeneration,
        'keeperGeneration',
        'Must match rosterStore.keeperGeneration',
      );
    }
    _roster
      ..addAll(rosterStore?.members ?? const [])
      ..remove(channel.localIdentity);
    _awaitingReadiness.addAll(rosterStore?.awaitingReadiness ?? const []);
    _revoked.addAll(rosterStore?.revoked ?? const []);
    _requiresDecision.addAll(rosterStore?.revoked ?? const []);
    _rosterRevision = rosterStore?.revision ?? 0;
    _committedRoster.addAll(
      _roster.difference(_awaitingReadiness).difference(_revoked),
    );
    _committedRevision = _rosterRevision;
    _subscription = channel.events.listen(_onEvent);
    _advertise();
  }

  final AdmissionChannel channel;
  final String Function() keeperIdentity;
  final bool Function()? isSessionStarted;
  final String _sessionIdentity;
  final KeeperAdmissionRosterStore? _rosterStore;
  final Future<void> Function()? persistRoster;
  final String _keeperGeneration;
  final DateTime Function() _now;
  final String Function() _newId;
  final _changes = StreamController<void>.broadcast();
  // At most one active request per participant identity. Keep the latest
  // packet across disconnects so an older request cannot resurrect the queue.
  final _latest = <String, AdmissionPacket>{};
  final _revoked = <String>{};
  final _requiresDecision = <String>{};
  final _pending = <String, AdmissionRequest>{};
  final _decisions = <String, AdmissionDecision>{};
  final _decisionRetries = <String, Timer>{};
  final _attempts = <String, KeeperAdmissionAttempt>{};
  final _pendingJoined = <String, (AdmissionRequest, int)>{};
  final _earlyOutcomes = <String, AdmissionPacket>{};
  final _expirations = <String, Timer>{};
  final _inFlight = <String>{};
  final _approving = <String>{};
  final _roster = <String>{};
  final _awaitingReadiness = <String>{};
  var _rosterRevision = 0;
  final _committedRoster = <String>{};
  final _acknowledgedRevisions = <String, int>{};
  final _restrictedAt = <String, int>{};
  var _committedRevision = 0;
  Object? _persistenceError;
  Future<void> _pendingRosterWrites = Future.value();
  late final StreamSubscription<AdmissionEvent> _subscription;
  bool _disposed = false;
  bool _ended;
  bool _approvalRequired;
  Set<String> _declinedIdentities;
  Set<String> _quarantinedIdentities;

  void setQuarantinedIdentities(Set<String> identities) {
    if (_disposed ||
        _ended ||
        (_quarantinedIdentities.length == identities.length &&
            _quarantinedIdentities.containsAll(identities))) {
      return;
    }
    _quarantinedIdentities = Set.of(identities);
    _completePersistedJoins(_committedRoster, _committedRevision);
    _publishRosterUpdate();
    _pending.keys.toList().forEach(_applyAutomaticDecision);
    _changes.add(null);
  }

  bool isPermanentlyDeclined(String identity) =>
      _declinedIdentities.contains(identity);

  void setDeclinedIdentities(Set<String> identities) {
    if (_disposed ||
        _ended ||
        (_declinedIdentities.length == identities.length &&
            _declinedIdentities.containsAll(identities))) {
      return;
    }
    _declinedIdentities = Set.of(identities);
    _pending.keys.toList().forEach(_applyAutomaticDecision);
    _changes.add(null);
  }

  bool get approvalRequired => _approvalRequired;
  Stream<void> get changes => _changes.stream;
  List<AdmissionRequest> get requests => List.unmodifiable(
    _pending.values.where(
      (request) =>
          (_approvalRequired ||
              _requiresDecision.contains(request.senderIdentity)) &&
          !isPermanentlyDeclined(request.senderIdentity) &&
          !(_roster.contains(request.senderIdentity) &&
              _inFlight.contains(_key(request.senderIdentity, request.id))),
    ),
  );

  bool isPendingRequest(String requestId, String participantIdentity) =>
      _pending[participantIdentity]?.id == requestId;

  void setApprovalRequired(bool required) {
    if (_disposed || _ended || _approvalRequired == required) return;
    _approvalRequired = required;
    if (!required) _pending.keys.toList().forEach(_applyAutomaticDecision);
    _changes.add(null);
  }

  List<KeeperAdmissionAttempt> get attempts =>
      List.unmodifiable(_attempts.values);

  /// Session-scoped participants ready on their current connection.
  List<String> get roster => List.unmodifiable(
    (_committedRoster.intersection(
      _roster
          .difference(_awaitingReadiness)
          .difference(_restrictedAt.keys.toSet())
          .difference(_quarantinedIdentities),
    )).toList()..sort(),
  );
  int get rosterRevision => _committedRevision;
  Map<String, int> get acknowledgedRevisions =>
      Map.unmodifiable(_acknowledgedRevisions);
  Object? get persistenceError => _persistenceError;
  Future<void> get pendingRosterWrites => _pendingRosterWrites;

  Future<void> retryRosterPersistence() {
    if (_disposed || _ended) throw StateError('Admission controller is closed');
    return _saveRoster();
  }

  void _updateRosterStore() {
    _rosterStore?.replace(
      _roster,
      _rosterRevision,
      awaitingReadiness: _awaitingReadiness,
    );
  }

  Future<void> _saveRoster() {
    _updateRosterStore();
    final members = _roster.difference(_awaitingReadiness);
    final revision = _rosterRevision;
    final persist = persistRoster;
    if (persist == null) {
      _committedRoster
        ..clear()
        ..addAll(members);
      _committedRevision = revision;
      _releasePersistedRestrictions(members, revision);
      return Future.value();
    }
    Future<void> write;
    try {
      write = persist();
    } catch (error, stack) {
      write = Future.error(error, stack);
    }
    // Attach an error handler immediately, even when earlier writes are pending.
    final result = write.then<Object?>(
      (_) => null,
      onError: (Object error, StackTrace _) => error,
    );
    final completion = _pendingRosterWrites.then((_) async {
      final error = await result;
      if (error != null) {
        if (_persistenceError == null) {
          _admissionBreadcrumb('persistence_failed');
        }
        _persistenceError = error;
      } else {
        _persistenceError = null;
        if (!_disposed &&
            !_ended &&
            keeperIdentity() == channel.localIdentity &&
            revision > _committedRevision) {
          _committedRoster
            ..clear()
            ..addAll(members);
          _committedRevision = revision;
          _releasePersistedRestrictions(members, revision);
          _completePersistedJoins(members, revision);
          _publishRosterUpdate();
        }
      }
      if (!_disposed && !_ended) _changes.add(null);
    });
    _pendingRosterWrites = completion;
    return completion.then((_) {
      final error = _persistenceError;
      if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
    });
  }

  void _releasePersistedRestrictions(Set<String> members, int revision) {
    _restrictedAt.removeWhere(
      (identity, restrictedRevision) =>
          revision >= restrictedRevision && members.contains(identity),
    );
  }

  void _completePersistedJoins(Set<String> members, int revision) {
    if (_disposed || _ended || keeperIdentity() != channel.localIdentity) {
      return;
    }
    for (final entry in _pendingJoined.entries.toList()) {
      final identity = entry.key;
      final (request, requiredRevision) = entry.value;
      final attempt = _attempts[identity];
      if (!identical(attempt?.request, request) ||
          !identical(_latest[identity], request) ||
          attempt?.status != KeeperAdmissionStatus.joining) {
        _pendingJoined.remove(identity);
      } else if (revision >= requiredRevision &&
          members.contains(identity) &&
          roster.contains(identity)) {
        _attempts[identity] = KeeperAdmissionAttempt(
          request,
          KeeperAdmissionStatus.joined,
          joinDeadline: attempt!.joinDeadline,
        );
        _pendingJoined.remove(identity);
      }
    }
  }

  void _queueRosterSave() {
    unawaited(_saveRoster().catchError((Object _) {}));
  }

  String get keeperGeneration => _keeperGeneration;

  /// Acknowledges an exact snapshot only after it has been atomically journaled.
  /// Stale generations, revisions, and superseded owners are ignored.
  void acknowledgeJournaledRoster({
    required String keeperGeneration,
    required int revision,
    required Iterable<String> members,
    required Iterable<String> awaitingReadiness,
    required Iterable<String> revoked,
  }) {
    if (_disposed ||
        _ended ||
        keeperIdentity() != channel.localIdentity ||
        keeperGeneration != _keeperGeneration ||
        revision < _committedRevision ||
        revision > _rosterRevision) {
      return;
    }
    final ready = members.toSet()
      ..removeAll(awaitingReadiness)
      ..removeAll(revoked)
      ..remove(channel.localIdentity);
    if (revision == _committedRevision) {
      if (ready.length != _committedRoster.length ||
          !ready.containsAll(_committedRoster)) {
        return;
      }
    } else {
      _committedRoster
        ..clear()
        ..addAll(ready);
      _committedRevision = revision;
      _releasePersistedRestrictions(ready, revision);
    }
    _completePersistedJoins(ready, revision);
    _publishRosterUpdate();
    _changes.add(null);
  }

  /// Revokes admission after the Keeper has successfully removed a participant.
  /// With [persist] false, the caller must journal the updated store and then
  /// acknowledge that exact snapshot before it can be announced.
  void revoke(String identity, {bool persist = true}) {
    if (_disposed || _ended) return;
    _revoked.add(identity);
    _acknowledgedRevisions.remove(identity);
    _requiresDecision.add(identity);
    _rosterStore?.revoked.add(identity);
    _pending.remove(identity);
    _decisions.remove(identity);
    _decisionRetries.remove(identity)?.cancel();
    _attempts.remove(identity);
    _pendingJoined.remove(identity);
    _earlyOutcomes.remove(identity);
    _expirations.remove(identity)?.cancel();
    _roster.remove(identity);
    _awaitingReadiness.remove(identity);
    _rosterRevision++;
    _restrictedAt[identity] = _rosterRevision;
    if (persist) {
      _queueRosterSave();
      if (persistRoster == null) _publishRosterUpdate();
    } else {
      _updateRosterStore();
    }
    _changes.add(null);
  }

  bool get _committedRosterIsSafe => roster.length == _committedRoster.length;

  String _key(String sender, String id) => '$sender\u0000$id';

  void _advertise() => channel.remoteIdentities.forEach(_advertiseTo);

  void _advertiseTo(String identity) {
    final keeper = channel.localIdentity;
    if (_disposed ||
        _ended ||
        keeper.isEmpty ||
        keeperIdentity() != keeper ||
        identity.isEmpty ||
        identity == keeper) {
      return;
    }
    unawaited(
      channel
          .send(
            AdmissionHello(
              id: _newId(),
              senderIdentity: keeper,
              recipientIdentity: identity,
              expiresAt: _now().add(AdmissionProtocol.lifetime),
            ),
          )
          .catchError((Object _) {}),
    );
    _sendRosterSnapshot(identity);
  }

  void _sendRosterSnapshot(String identity, {String? requestId}) {
    if (_sessionIdentity.isEmpty ||
        _disposed ||
        _ended ||
        !_committedRosterIsSafe ||
        (requestId == null && !roster.contains(identity)) ||
        keeperIdentity() != channel.localIdentity) {
      return;
    }
    unawaited(
      channel
          .send(
            AdmissionRosterSnapshot(
              id: _newId(),
              senderIdentity: channel.localIdentity,
              recipientIdentity: identity,
              expiresAt: _now().add(AdmissionProtocol.lifetime),
              sessionIdentity: _sessionIdentity,
              keeperGeneration: _keeperGeneration,
              revision: _committedRevision,
              members: roster.contains(identity)
                  ? (_committedRoster.toList()..sort())
                  : const [],
              requestId: requestId,
            ),
          )
          .catchError((Object _) {}),
    );
  }

  void _publishRosterUpdate() {
    if (_sessionIdentity.isEmpty ||
        _disposed ||
        _ended ||
        keeperIdentity() != channel.localIdentity ||
        !_committedRosterIsSafe) {
      return;
    }
    final members = _committedRoster.toList()..sort();
    for (final identity in channel.remoteIdentities) {
      if (!members.contains(identity)) continue;
      unawaited(
        channel
            .send(
              AdmissionRosterUpdated(
                id: _newId(),
                senderIdentity: channel.localIdentity,
                recipientIdentity: identity,
                expiresAt: _now().add(AdmissionProtocol.lifetime),
                sessionIdentity: _sessionIdentity,
                keeperGeneration: _keeperGeneration,
                revision: _committedRevision,
                members: members,
              ),
            )
            .catchError((Object _) {}),
      );
    }
  }

  void _onEvent(AdmissionEvent event) {
    if (_disposed || _ended) return;
    if (event is AdmissionRoomEnded) {
      _ended = true;
      for (final timer in _expirations.values) {
        timer.cancel();
      }
      _expirations.clear();
      _latest.clear();
      _revoked.clear();
      _requiresDecision.clear();
      _pending.clear();
      _decisions.clear();
      for (final timer in _decisionRetries.values) {
        timer.cancel();
      }
      _decisionRetries.clear();
      _attempts.clear();
      _pendingJoined.clear();
      _earlyOutcomes.clear();
      _roster.clear();
      _acknowledgedRevisions.clear();
      _awaitingReadiness.clear();
      _rosterRevision = 0;
      _pendingRosterWrites = _pendingRosterWrites.then(
        (_) => _rosterStore?.clear(),
      );
      _changes.add(null);
      return;
    }
    switch (event) {
      case AdmissionConnectionRestored():
        _advertise();
        _pending.keys.toList().forEach(_applyAutomaticDecision);
      case AdmissionPresenceChanged(:final identity, present: true):
        _advertiseTo(identity);
        _resendDecision(identity);
        _applyAutomaticDecision(identity);
      case AdmissionPresenceChanged(:final identity, present: false):
        // A reconnecting participant can re-advertise this same request.
        if (_pending.remove(identity) case final request?) {
          if (!_inFlight.contains(_key(identity, request.id))) {
            _attempts.remove(identity);
          }
          _changes.add(null);
        }
      case AdmissionPacketReceived(
        packet: final AdmissionRosterRequest request,
      ):
        _receiveRosterRequest(request);
      case AdmissionPacketReceived(packet: final AdmissionRosterAck ack):
        _receiveRosterAck(ack);
      case AdmissionPacketReceived(:final packet)
          when packet is AdmissionJoined || packet is AdmissionJoinFailed:
        _receiveOutcome(packet);
      case AdmissionPacketReceived(:final packet)
          when packet is AdmissionRequest || packet is AdmissionCancel:
        if (keeperIdentity() != channel.localIdentity ||
            packet.senderIdentity == channel.localIdentity ||
            packet.recipientIdentity != channel.localIdentity ||
            !_now().isBefore(packet.expiresAt)) {
          return;
        }
        final sender = packet.senderIdentity;
        final latest = _latest[sender];
        if (latest == null) {
          _record(packet);
          return;
        }
        if (latest.id != packet.id) {
          if (packet.expiresAt.isAfter(latest.expiresAt)) _record(packet);
          return;
        }
        if (packet.expiresAt != latest.expiresAt || _revoked.contains(sender)) {
          return;
        }
        if (packet is AdmissionCancel) {
          if (latest is! AdmissionCancel &&
              _attempts[sender]?.status != KeeperAdmissionStatus.joined) {
            _record(packet);
          }
        } else if (packet is AdmissionRequest &&
            latest is AdmissionRequest &&
            latest.displayName == packet.displayName) {
          final decision = _decisions[sender];
          if (decision != null) {
            if (!decision.approved ||
                !_quarantinedIdentities.contains(sender)) {
              unawaited(channel.send(decision).catchError((Object _) {}));
            }
          } else if (_pending[sender] == null &&
              (_attempts[sender] == null ||
                  _attempts[sender]?.status ==
                      KeeperAdmissionStatus.requested)) {
            _pending[sender] = latest;
            _attempts[sender] = KeeperAdmissionAttempt(
              latest,
              KeeperAdmissionStatus.requested,
            );
            _changes.add(null);
            _applyAutomaticDecision(sender);
          }
        }
      default:
        break;
    }
  }

  void _applyAutomaticDecision(String identity) {
    final request = _pending[identity];
    if (_disposed ||
        _ended ||
        keeperIdentity() != channel.localIdentity ||
        _quarantinedIdentities.contains(identity) ||
        request == null ||
        _inFlight.contains(_key(identity, request.id))) {
      return;
    }
    final declined = isPermanentlyDeclined(identity);
    if (!declined && _requiresDecision.contains(identity)) {
      return;
    }
    if (!declined && _approvalRequired && !_roster.contains(identity)) return;
    // A durable decline takes precedence over a previous admission. Returning
    // members still need a fresh joined receipt before appearing in the roster.
    unawaited(
      _decide(request.id, identity, !declined).catchError((Object _) {
        if (!_disposed && !_ended) _changes.add(null);
      }),
    );
  }

  void _receiveRosterRequest(AdmissionRosterRequest request) {
    if (_sessionIdentity.isEmpty ||
        keeperIdentity() != channel.localIdentity ||
        request.senderIdentity == channel.localIdentity ||
        request.recipientIdentity != channel.localIdentity ||
        request.sessionIdentity != _sessionIdentity ||
        !_now().isBefore(request.expiresAt)) {
      return;
    }
    _sendRosterSnapshot(request.senderIdentity, requestId: request.id);
  }

  void _receiveRosterAck(AdmissionRosterAck ack) {
    if (_sessionIdentity.isEmpty ||
        keeperIdentity() != channel.localIdentity ||
        ack.senderIdentity == channel.localIdentity ||
        ack.recipientIdentity != channel.localIdentity ||
        ack.sessionIdentity != _sessionIdentity ||
        ack.keeperGeneration != _keeperGeneration ||
        ack.revision < 0 ||
        ack.revision > _committedRevision ||
        !_now().isBefore(ack.expiresAt) ||
        !roster.contains(ack.senderIdentity)) {
      return;
    }
    final previous = _acknowledgedRevisions[ack.senderIdentity];
    if (previous == null || ack.revision > previous) {
      _acknowledgedRevisions[ack.senderIdentity] = ack.revision;
      _admissionBreadcrumb(
        'revision_acknowledged',
        data: {'revision': ack.revision},
      );
    }
  }

  void _record(AdmissionPacket packet) {
    final sender = packet.senderIdentity;
    _pendingJoined.remove(sender);
    _expirations.remove(sender)?.cancel();
    _latest[sender] = packet;
    _revoked.remove(sender);
    _decisions.remove(sender);
    _decisionRetries.remove(sender)?.cancel();
    _earlyOutcomes.remove(sender);
    if (packet is AdmissionRequest) {
      _pending[sender] = packet;
      _attempts[sender] = KeeperAdmissionAttempt(
        packet,
        KeeperAdmissionStatus.requested,
      );
    } else {
      _pending.remove(sender);
      final attempt = _attempts[sender];
      if (attempt != null && attempt.request.id == packet.id) {
        _attempts[sender] = KeeperAdmissionAttempt(
          attempt.request,
          KeeperAdmissionStatus.cancelled,
        );
      } else {
        _attempts.remove(sender);
      }
    }
    _expirations[sender] = Timer(packet.expiresAt.difference(_now()), () {
      if (!identical(_latest[sender], packet)) return;
      _pending.remove(sender);
      _decisions.remove(sender);
      _decisionRetries.remove(sender)?.cancel();
      _expirations.remove(sender);
      final attempt = _attempts[sender];
      if (attempt != null) {
        final status = switch (attempt.status) {
          KeeperAdmissionStatus.requested => KeeperAdmissionStatus.expired,
          KeeperAdmissionStatus.joining => KeeperAdmissionStatus.timedOut,
          _ => attempt.status,
        };
        _attempts[sender] = KeeperAdmissionAttempt(
          attempt.request,
          status,
          joinDeadline: attempt.joinDeadline,
        );
      }
      if (!_disposed) _changes.add(null);
    });
    if (packet is AdmissionRequest) {
      if (_roster.contains(sender) && _awaitingReadiness.add(sender)) {
        _rosterRevision++;
        _restrictedAt[sender] = _rosterRevision;
        _queueRosterSave();
        if (persistRoster == null) _publishRosterUpdate();
      }
    }
    _changes.add(null);
    if (packet is AdmissionRequest) {
      _acknowledgeRequest(packet);
      _applyAutomaticDecision(sender);
    }
  }

  void _acknowledgeRequest(AdmissionRequest request) {
    unawaited(
      channel
          .send(
            AdmissionHello(
              id: _newId(),
              senderIdentity: channel.localIdentity,
              recipientIdentity: request.senderIdentity,
              expiresAt: _now().add(AdmissionProtocol.lifetime),
            ),
          )
          .catchError((Object _) {}),
    );
  }

  void _receiveOutcome(AdmissionPacket packet) {
    if (keeperIdentity() != channel.localIdentity ||
        packet.senderIdentity == channel.localIdentity ||
        packet.recipientIdentity != channel.localIdentity ||
        !_now().isBefore(packet.expiresAt)) {
      return;
    }
    final sender = packet.senderIdentity;
    final request = _attempts[sender]?.request;
    if (packet is AdmissionJoined &&
        request == null &&
        roster.contains(sender)) {
      _sendRosterSnapshot(sender);
      return;
    }
    if (request == null ||
        request.id != packet.id ||
        request.expiresAt != packet.expiresAt ||
        _latest[sender] is! AdmissionRequest) {
      return;
    }
    final attempt = _attempts[sender]!;
    if (_pendingJoined.containsKey(sender)) return;
    if (attempt.status == KeeperAdmissionStatus.joined &&
        packet is AdmissionJoined) {
      // The client retries until it observes an authenticated roster containing
      // itself. A duplicate receipt is therefore a request to resend the
      // already-committed snapshot, not another roster mutation.
      _sendRosterSnapshot(sender);
      return;
    }
    if (attempt.status == KeeperAdmissionStatus.joining &&
        _now().isBefore(attempt.joinDeadline!)) {
      _decisionRetries.remove(sender)?.cancel();
      _expirations.remove(sender)?.cancel();
      _attempts[sender] = KeeperAdmissionAttempt(
        request,
        packet is AdmissionJoined
            ? (persistRoster == null
                  ? KeeperAdmissionStatus.joined
                  : KeeperAdmissionStatus.joining)
            : KeeperAdmissionStatus.joinFailed,
        joinDeadline: attempt.joinDeadline,
      );
      if (packet is AdmissionJoined) {
        final newlyAdmitted = _roster.add(sender);
        final readyAgain = _awaitingReadiness.remove(sender);
        if (newlyAdmitted || readyAgain || persistRoster != null) {
          _rosterRevision++;
          if (persistRoster != null) {
            _pendingJoined[sender] = (request, _rosterRevision);
          }
          _queueRosterSave();
          if (persistRoster == null) _publishRosterUpdate();
        }
      }
      _changes.add(null);
    } else if (_approving.contains(_key(sender, packet.id))) {
      _earlyOutcomes[sender] = packet;
    }
  }

  void _resendDecision(String identity) {
    final decision = _decisions[identity];
    if (_disposed ||
        _ended ||
        keeperIdentity() != channel.localIdentity ||
        decision == null ||
        (decision.approved && _quarantinedIdentities.contains(identity)) ||
        _attempts[identity]?.status != KeeperAdmissionStatus.joining ||
        !_now().isBefore(decision.expiresAt)) {
      return;
    }
    unawaited(channel.send(decision).catchError((Object _) {}));
  }

  Future<void> approve(String requestId, String participantIdentity) =>
      _decide(requestId, participantIdentity, true);

  Future<void> deny(String requestId, String participantIdentity) =>
      _decide(requestId, participantIdentity, false);

  Future<void> denyPermanently(
    String requestId,
    String identity,
    Future<void> Function() saveDecline,
  ) => _decide(requestId, identity, false, beforeDecision: saveDecline);

  Future<void> _decide(
    String id,
    String sender,
    bool approved, {
    Future<void> Function()? beforeDecision,
  }) async {
    if (_disposed || _ended || keeperIdentity() != channel.localIdentity) {
      throw StateError('Not the current keeper');
    }
    if (approved && _quarantinedIdentities.contains(sender)) {
      throw StateError('Participant admission is quarantined');
    }
    if (approved && isPermanentlyDeclined(sender)) {
      throw StateError('Participant has been permanently declined');
    }
    final request = _pending[sender];
    if (request == null ||
        request.id != id ||
        !_now().isBefore(request.expiresAt)) {
      throw StateError('Request is no longer pending');
    }
    final key = _key(sender, id);
    if (!_inFlight.add(key)) throw StateError('Decision already in progress');
    if (approved &&
        !AdmissionApprovalGuard.beginApproval(_sessionIdentity, sender)) {
      _inFlight.remove(key);
      throw StateError('Admission approval is reserved or already in progress');
    }
    if (approved) _approving.add(key);
    try {
      if (beforeDecision != null) {
        await beforeDecision();
        if (_disposed ||
            _ended ||
            keeperIdentity() != channel.localIdentity ||
            !identical(_pending[sender], request) ||
            !_now().isBefore(request.expiresAt)) {
          throw StateError('Request changed while saving the decline');
        }
      }
      final decision = AdmissionDecision(
        id: id,
        senderIdentity: channel.localIdentity,
        recipientIdentity: sender,
        expiresAt: request.expiresAt,
        approved: approved,
        isReturningParticipant: approved && _roster.contains(sender),
        sessionStartedAtAdmission: approved ? isSessionStarted?.call() : null,
      );
      await channel.send(decision);
      if (_disposed ||
          _ended ||
          keeperIdentity() != channel.localIdentity ||
          (approved && _quarantinedIdentities.contains(sender)) ||
          !identical(_latest[sender], request) ||
          !(identical(_pending[sender], request) ||
              (_pending[sender] == null &&
                  identical(_attempts[sender]?.request, request))) ||
          !_now().isBefore(request.expiresAt)) {
        throw StateError('Request changed while deciding');
      }
      if (approved && _requiresDecision.remove(sender)) {
        _rosterStore?.revoked.remove(sender);
        _rosterRevision++;
        _queueRosterSave();
      }
      _pending.remove(sender);
      _decisions[sender] = decision;
      final confirmationDeadline = _now().add(AdmissionProtocol.lifetime);
      final joinDeadline = approved
          ? (request.expiresAt.isBefore(confirmationDeadline)
                ? request.expiresAt
                : confirmationDeadline)
          : null;
      _attempts[sender] = KeeperAdmissionAttempt(
        request,
        approved ? KeeperAdmissionStatus.joining : KeeperAdmissionStatus.denied,
        joinDeadline: joinDeadline,
      );
      if (joinDeadline != null) {
        _expirations.remove(sender)?.cancel();
        _expirations[sender] = Timer(joinDeadline.difference(_now()), () {
          if (_disposed ||
              _ended ||
              _attempts[sender]?.request != request ||
              _attempts[sender]?.status != KeeperAdmissionStatus.joining) {
            return;
          }
          _decisionRetries.remove(sender)?.cancel();
          _expirations.remove(sender);
          _attempts[sender] = KeeperAdmissionAttempt(
            request,
            KeeperAdmissionStatus.timedOut,
            joinDeadline: joinDeadline,
          );
          _changes.add(null);
        });
      }
      _changes.add(null);
      if (approved) {
        // A reliable packet is not durable; retry once if no receipt arrives.
        // Duplicate decisions are ignored by the applicant's request state.
        _decisionRetries.remove(sender)?.cancel();
        _decisionRetries[sender] = Timer(const Duration(seconds: 2), () {
          _decisionRetries.remove(sender);
          _resendDecision(sender);
        });
      }
      final early = _earlyOutcomes.remove(sender);
      if (early != null && approved) _receiveOutcome(early);
    } finally {
      if (_pending[sender] == null &&
          identical(_attempts[sender]?.request, request) &&
          _attempts[sender]?.status == KeeperAdmissionStatus.requested) {
        _attempts.remove(sender);
        if (!_disposed && !_ended) _changes.add(null);
      }
      if (_earlyOutcomes[sender]?.id == id &&
          _earlyOutcomes[sender]?.expiresAt == request.expiresAt) {
        _earlyOutcomes.remove(sender);
      }
      if (approved) {
        AdmissionApprovalGuard.endApproval(_sessionIdentity, sender);
      }
      _approving.remove(key);
      _inFlight.remove(key);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final timer in _expirations.values) {
      timer.cancel();
    }
    _expirations.clear();
    _latest.clear();
    _revoked.clear();
    _requiresDecision.clear();
    _pending.clear();
    _decisions.clear();
    for (final timer in _decisionRetries.values) {
      timer.cancel();
    }
    _decisionRetries.clear();
    _attempts.clear();
    _pendingJoined.clear();
    _earlyOutcomes.clear();
    _approving.clear();
    _roster.clear();
    _acknowledgedRevisions.clear();
    _awaitingReadiness.clear();
    _inFlight.clear();
    await _pendingRosterWrites;
    await Future.wait<void>([
      Future<void>.sync(() => _subscription.cancel()),
      Future<void>.sync(() async {
        await _changes.close();
      }),
    ]);
  }
}

/// Session-scoped roster accepted only from the currently configured keeper.
final class AdmissionRoster {
  const AdmissionRoster({
    required this.keeperGeneration,
    required this.revision,
    required this.members,
  });

  final String keeperGeneration;
  final int revision;
  final List<String> members;

  bool contains(String identity) => members.contains(identity);
}

/// Client-side, fail-closed roster consumer. Until an authoritative snapshot
/// from the current keeper arrives, [roster] is null and membership is unknown.
class ClientAdmissionRosterController {
  ClientAdmissionRosterController({
    required this.channel,
    required this.keeperIdentity,
    required this.sessionIdentity,
    this.antiEntropyInterval = const Duration(seconds: 25),
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? const Uuid().v4 {
    if (sessionIdentity.isEmpty) {
      throw ArgumentError.value(sessionIdentity, 'sessionIdentity');
    }
    if (antiEntropyInterval <= Duration.zero) {
      throw ArgumentError.value(antiEntropyInterval, 'antiEntropyInterval');
    }
    _subscription = channel.events.listen(_onEvent);
    _requestIfCurrentKeeperPresent();
  }

  final AdmissionChannel channel;
  final String Function() keeperIdentity;
  final String sessionIdentity;
  final Duration antiEntropyInterval;
  final DateTime Function() _now;
  final String Function() _newId;
  final _changes = StreamController<AdmissionRoster?>.broadcast();
  late final StreamSubscription<AdmissionEvent> _subscription;
  AdmissionRoster? _roster;
  String? _rosterKeeperIdentity;
  String? _outstandingRequestId;
  Object? _requestToken;
  Object? _requestSend;
  int _requestFlights = 0;
  bool _requestDeferred = false;
  String? _presentKeeper;
  DateTime? _outstandingRequestExpiry;
  DateTime? _lastRequestAt;
  Timer? _snapshotRetry;
  Timer? _antiEntropy;
  bool _disconnected = false;
  Object? _ackSend;
  int _ackFlights = 0;
  int? _inFlightAckRevision;
  int? _pendingAckRevision;
  final _synchronizationChanges = StreamController<bool>.broadcast();
  final _random = Random();
  final Set<Timer> _operationTimeouts = {};
  String? _requestKeeper;
  int _retryCount = 0;
  bool _synchronizing = false;
  bool _ended = false;
  final _unsynchronizedRevisions = <String, int>{};
  String? _lastUnsynchronizedGeneration;
  String? _verifiedGeneration;
  final _retiredGenerations = <String>{};
  bool _disposed = false;

  /// Emits accepted fresh snapshots or updates, and null on invalidation.
  /// Retries and synchronization state changes do not emit roster evidence.
  Stream<AdmissionRoster?> get changes => _changes.stream;
  Stream<bool> get synchronizationChanges => _synchronizationChanges.stream;
  bool get isSynchronizing => _synchronizing;

  void _setSynchronizing(bool value) {
    if (_synchronizing == value) return;
    _synchronizing = value;
    if (!_synchronizationChanges.isClosed) _synchronizationChanges.add(value);
  }

  AdmissionRoster? get roster =>
      !_ended && !channel.hasEnded && _rosterKeeperIdentity == keeperIdentity()
      ? _roster
      : null;
  bool get hasAuthoritativeRoster => roster != null;
  bool contains(String identity) => roster?.contains(identity) ?? false;

  /// Requests fresh roster evidence, coalescing with any in-flight request.
  void requestSynchronization() {
    _setSynchronizing(true);
    _requestIfCurrentKeeperPresent();
  }

  void _onEvent(AdmissionEvent event) {
    if (_disposed || _ended) return;
    if (event is AdmissionConnectionInterrupted ||
        event is AdmissionRoomDisconnected) {
      _disconnected = true;
      _requestToken = null;
      _requestSend = null;
      _requestDeferred = false;
      _presentKeeper = null;
      _antiEntropy?.cancel();
      _antiEntropy = null;
      _invalidateAck();
      _snapshotRetry?.cancel();
      _snapshotRetry = null;
      _outstandingRequestId = null;
      _outstandingRequestExpiry = null;
      _setSynchronizing(event is AdmissionConnectionInterrupted);
      return;
    }
    if (_rosterKeeperIdentity != null &&
        _rosterKeeperIdentity != keeperIdentity()) {
      _clear();
      _requestIfCurrentKeeperPresent();
    } else if (_requestKeeper != keeperIdentity()) {
      _requestIfCurrentKeeperPresent();
    }
    if (event is! AdmissionRoomEnded && channel.hasEnded) {
      _clear();
      return;
    }
    switch (event) {
      case AdmissionPacketReceived(:final AdmissionRosterSnapshot packet):
        _receiveSnapshot(packet);
      case AdmissionPacketReceived(:final AdmissionRosterUpdated packet):
        _receiveUpdate(packet);
      case AdmissionPacketReceived(packet: final AdmissionHello hello):
        if (_isCurrentKeeper(hello.senderIdentity) &&
            hello.recipientIdentity == channel.localIdentity) {
          _requestIfCurrentKeeperPresent();
        }
      case AdmissionConnectionRestored():
        _disconnected = false;
        _scheduleAntiEntropy();
        final lastRequest = _lastRequestAt;
        _requestIfCurrentKeeperPresent(
          force:
              lastRequest != null &&
              _now().difference(lastRequest) >= const Duration(seconds: 1),
        );
      case AdmissionPresenceChanged(:final identity, :final present):
        if (_isCurrentKeeper(identity)) {
          if (present) {
            _presentKeeper = identity;
            _requestIfCurrentKeeperPresent();
            _scheduleAntiEntropy();
          } else {
            _presentKeeper = null;
            _requestSend = null;
            _requestDeferred = false;
            _antiEntropy?.cancel();
            _antiEntropy = null;
            _invalidateAck();
            _requestToken = null;
            _snapshotRetry?.cancel();
            _snapshotRetry = null;
            _outstandingRequestId = null;
            _outstandingRequestExpiry = null;
            _setSynchronizing(true);
          }
        }

      case AdmissionRoomEnded():
        _ended = true;
        _antiEntropy?.cancel();
        _antiEntropy = null;
        _invalidateAck();
        _snapshotRetry?.cancel();
        _outstandingRequestId = null;
        _outstandingRequestExpiry = null;
        _setSynchronizing(false);
        _clear();
      default:
        break;
    }
  }

  bool _isCurrentKeeper(String identity) {
    final keeper = keeperIdentity();
    return keeper.isNotEmpty && identity == keeper;
  }

  bool _keeperPresent(String keeper) =>
      _presentKeeper == keeper || channel.isPresent(keeper);

  bool _isValid(AdmissionRosterPacket packet) =>
      !_disconnected &&
      _isCurrentKeeper(packet.senderIdentity) &&
      packet.senderIdentity != channel.localIdentity &&
      packet.recipientIdentity == channel.localIdentity &&
      packet.sessionIdentity == sessionIdentity &&
      packet.keeperGeneration.isNotEmpty &&
      packet.revision >= 0 &&
      packet.members.length <= 256 &&
      packet.members.every(
        (member) => member.isNotEmpty && member.length <= 256,
      ) &&
      packet.members.toSet().length == packet.members.length &&
      _now().isBefore(packet.expiresAt);

  void _receiveSnapshot(AdmissionRosterSnapshot packet) {
    if (!_isValid(packet) ||
        _outstandingRequestId == null ||
        _requestKeeper != packet.senderIdentity ||
        !(_outstandingRequestExpiry?.isAfter(_now()) ?? false) ||
        packet.requestId != _outstandingRequestId) {
      return;
    }
    final current = roster;
    final observedRevision = _unsynchronizedRevisions[packet.keeperGeneration];
    if (_retiredGenerations.contains(packet.keeperGeneration) ||
        (_unsynchronizedRevisions.isNotEmpty &&
            (observedRevision == null || packet.revision < observedRevision)) ||
        (current != null &&
            current.keeperGeneration == packet.keeperGeneration &&
            packet.revision < current.revision)) {
      _requestIfCurrentKeeperPresent(force: true);
      return;
    }
    if (current != null &&
        current.keeperGeneration != packet.keeperGeneration) {
      _retiredGenerations.add(current.keeperGeneration);
    }
    _outstandingRequestId = null;
    _outstandingRequestExpiry = null;
    _requestDeferred = false;
    _snapshotRetry?.cancel();
    _snapshotRetry = null;
    _retryCount = 0;
    _setSynchronizing(false);
    _unsynchronizedRevisions.clear();
    _lastUnsynchronizedGeneration = null;
    _verifiedGeneration = packet.keeperGeneration;
    _setRoster(packet);
  }

  void _receiveUpdate(AdmissionRosterUpdated packet) {
    if (!_isValid(packet) ||
        _retiredGenerations.contains(packet.keeperGeneration)) {
      return;
    }
    final current = roster;
    if (current == null || !current.contains(channel.localIdentity)) {
      if (current != null &&
          current.keeperGeneration == packet.keeperGeneration &&
          packet.revision <= current.revision) {
        return;
      }
      if (current != null &&
          current.keeperGeneration != packet.keeperGeneration) {
        _retiredGenerations.add(current.keeperGeneration);
        _clear();
      }
      final observedRevision =
          _unsynchronizedRevisions[packet.keeperGeneration];
      if (_lastUnsynchronizedGeneration == packet.keeperGeneration &&
          observedRevision != null &&
          packet.revision <= observedRevision) {
        return;
      }
      if (_verifiedGeneration != null &&
          _verifiedGeneration != packet.keeperGeneration) {
        _retiredGenerations.add(_verifiedGeneration!);
      }
      final conflict =
          _lastUnsynchronizedGeneration != null &&
          _lastUnsynchronizedGeneration != packet.keeperGeneration;
      _lastUnsynchronizedGeneration = packet.keeperGeneration;
      if (observedRevision == null || packet.revision > observedRevision) {
        _unsynchronizedRevisions[packet.keeperGeneration] = packet.revision;
      }
      _requestIfCurrentKeeperPresent(force: conflict);
      return;
    }
    if (current.keeperGeneration != packet.keeperGeneration) {
      _retiredGenerations.add(current.keeperGeneration);
      _clear();
      _unsynchronizedRevisions[packet.keeperGeneration] = packet.revision;
      _lastUnsynchronizedGeneration = packet.keeperGeneration;
      _requestIfCurrentKeeperPresent(force: true);
      return;
    }
    if (packet.revision <= current.revision) return;
    _setRoster(packet);
  }

  void _setRoster(AdmissionRosterPacket packet) {
    if ((_roster?.contains(channel.localIdentity) ?? false) &&
        !packet.members.contains(channel.localIdentity)) {
      _unsynchronizedRevisions[packet.keeperGeneration] = packet.revision;
      _lastUnsynchronizedGeneration = packet.keeperGeneration;
      _clear();
      return;
    }
    final previous = _roster;
    _rosterKeeperIdentity = packet.senderIdentity;
    _roster = AdmissionRoster(
      keeperGeneration: packet.keeperGeneration,
      revision: packet.revision,
      members: List.unmodifiable(
        packet.members.contains(channel.localIdentity)
            ? packet.members
            : const <String>[],
      ),
    );
    _changes.add(_roster);
    if (previous == null ||
        previous.keeperGeneration != packet.keeperGeneration ||
        previous.revision != packet.revision) {
      _admissionBreadcrumb(
        'revision_applied',
        data: {'revision': packet.revision},
      );
    }
    if (_roster!.contains(channel.localIdentity)) {
      _queueAck();
      _scheduleAntiEntropy();
    } else {
      _antiEntropy?.cancel();
      _antiEntropy = null;
      _invalidateAck();
    }
  }

  void _invalidateAck() {
    _ackSend = null;
    _inFlightAckRevision = null;
    _pendingAckRevision = null;
  }

  void _queueAck() {
    final current = roster;
    if (_disposed ||
        _ended ||
        _disconnected ||
        channel.hasEnded ||
        current == null ||
        !current.contains(channel.localIdentity) ||
        !_keeperPresent(keeperIdentity())) {
      return;
    }
    if (_ackSend != null && _inFlightAckRevision == current.revision) {
      return;
    }
    _pendingAckRevision = current.revision;
    if (_ackSend != null || _ackFlights >= 2) return;
    _sendAck();
  }

  void _sendAck() {
    final current = roster;
    final revision = _pendingAckRevision;
    if (_disposed ||
        _ended ||
        _disconnected ||
        channel.hasEnded ||
        current == null ||
        revision == null ||
        current.revision != revision ||
        !current.contains(channel.localIdentity) ||
        !_keeperPresent(keeperIdentity())) {
      return;
    }
    _pendingAckRevision = null;
    final token = Object();
    _ackSend = token;
    _ackFlights++;
    _inFlightAckRevision = revision;
    Future<void>.sync(
      () => channel.send(
        AdmissionRosterAck(
          id: _newId(),
          senderIdentity: channel.localIdentity,
          recipientIdentity: keeperIdentity(),
          expiresAt: _now().add(AdmissionProtocol.lifetime),
          sessionIdentity: sessionIdentity,
          keeperGeneration: current.keeperGeneration,
          revision: revision,
        ),
      ),
    ).catchError((Object _) {}).whenComplete(() {
      _ackFlights--;
      if (identical(_ackSend, token)) {
        _ackSend = null;
        _inFlightAckRevision = null;
      }
      if (_ackSend == null && _ackFlights < 2 && _pendingAckRevision != null) {
        _sendAck();
      }
    });
  }

  void _scheduleAntiEntropy() {
    if (_antiEntropy != null ||
        _disposed ||
        _ended ||
        _disconnected ||
        channel.hasEnded ||
        !(roster?.contains(channel.localIdentity) ?? false) ||
        !_keeperPresent(keeperIdentity())) {
      return;
    }
    final keeper = keeperIdentity();
    final delay = Duration(
      microseconds:
          (antiEntropyInterval.inMicroseconds *
                  (0.9 + _random.nextDouble() * 0.2))
              .round(),
    );
    _antiEntropy = Timer(delay, () {
      _antiEntropy = null;
      if (_disposed || _ended || _disconnected || channel.hasEnded) return;
      if (keeper != keeperIdentity()) {
        _clear();
        _requestIfCurrentKeeperPresent();
        return;
      }
      if (!(roster?.contains(channel.localIdentity) ?? false) ||
          !_keeperPresent(keeper)) {
        return;
      }
      _requestIfCurrentKeeperPresent();
      _scheduleAntiEntropy();
    });
  }

  void _clear() {
    _antiEntropy?.cancel();
    _antiEntropy = null;
    _invalidateAck();
    if (_roster == null) return;
    _roster = null;
    _admissionBreadcrumb('admission.roster_unknown');
    _rosterKeeperIdentity = null;
    _changes.add(null);
  }

  Future<void> _withOperationTimeout(Future<void> operation) {
    final result = Completer<void>();
    late final Timer timeout;
    timeout = Timer(const Duration(seconds: 30), () {
      _operationTimeouts.remove(timeout);
      if (!result.isCompleted) {
        result.completeError(TimeoutException('Admission send timed out'));
      }
    });
    _operationTimeouts.add(timeout);
    operation.then(
      (_) {
        timeout.cancel();
        _operationTimeouts.remove(timeout);
        if (!result.isCompleted) result.complete();
      },
      onError: (Object error, StackTrace stack) {
        timeout.cancel();
        _operationTimeouts.remove(timeout);
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    return result.future;
  }

  void _requestIfCurrentKeeperPresent({bool force = false}) {
    final keeper = keeperIdentity();
    if (_disposed || _ended || _disconnected || channel.hasEnded) return;
    if (_requestKeeper != keeper) {
      _requestToken = null;
      _requestSend = null;
      _requestDeferred = false;
      _presentKeeper = null;
      _antiEntropy?.cancel();
      _antiEntropy = null;
      _invalidateAck();
      _snapshotRetry?.cancel();
      _snapshotRetry = null;
      _outstandingRequestId = null;
      _outstandingRequestExpiry = null;
      _requestKeeper = keeper;
      _retryCount = 0;
      _unsynchronizedRevisions.clear();
      _lastUnsynchronizedGeneration = null;
      _verifiedGeneration = null;
      _retiredGenerations.clear();
    }
    final hasVerifiedLocalRoster =
        roster?.contains(channel.localIdentity) ?? false;
    if (!hasVerifiedLocalRoster ||
        force ||
        _unsynchronizedRevisions.isNotEmpty) {
      _setSynchronizing(true);
    }
    if (keeper.isEmpty ||
        keeper == channel.localIdentity ||
        !_keeperPresent(keeper)) {
      return;
    }
    if (_requestSend != null) {
      if (force ||
          _outstandingRequestId == null ||
          !(_outstandingRequestExpiry?.isAfter(_now()) ?? false)) {
        _requestDeferred = true;
      }
      return;
    }
    if (!force &&
        _outstandingRequestId != null &&
        (_outstandingRequestExpiry?.isAfter(_now()) ?? false)) {
      return;
    }
    if (_requestFlights >= 2) {
      _requestDeferred = true;
      return;
    }
    _lastRequestAt = _now();
    final expiry = _lastRequestAt!.add(AdmissionProtocol.lifetime);
    final id = _newId();
    final token = Object();
    _requestToken = token;
    _requestSend = token;
    _requestFlights++;
    _requestDeferred = false;
    _outstandingRequestId = id;
    _outstandingRequestExpiry = expiry;
    _snapshotRetry?.cancel();
    final seconds = min(30, 2 * (1 << min(_retryCount, 4)));
    _retryCount++;
    final delay = Duration(
      milliseconds: (seconds * 1000 * (0.9 + _random.nextDouble() * 0.1))
          .round(),
    );
    _snapshotRetry = Timer(delay, () {
      if (_disposed ||
          _ended ||
          !identical(_requestToken, token) ||
          _outstandingRequestId != id) {
        return;
      }
      _outstandingRequestId = null;
      _outstandingRequestExpiry = null;
      _setSynchronizing(true);
      if (_retryCount <= 5) {
        _admissionBreadcrumb('snapshot_retry', data: {'attempt': _retryCount});
      }
      _requestIfCurrentKeeperPresent();
    });
    unawaited(
      _withOperationTimeout(
            Future<void>.sync(
              () => channel.send(
                AdmissionRosterRequest(
                  id: id,
                  senderIdentity: channel.localIdentity,
                  recipientIdentity: keeper,
                  expiresAt: expiry,
                  sessionIdentity: sessionIdentity,
                ),
              ),
            ),
          )
          .catchError((Object _) {
            if (!_disposed &&
                !_ended &&
                !_disconnected &&
                !channel.hasEnded &&
                identical(_requestToken, token) &&
                _outstandingRequestId == id) {
              _outstandingRequestId = null;
              _outstandingRequestExpiry = null;
              _snapshotRetry?.cancel();
              _snapshotRetry = Timer(delay, _requestIfCurrentKeeperPresent);
            }
          })
          .whenComplete(() {
            _requestFlights--;
            if (identical(_requestSend, token)) _requestSend = null;
            if (_requestSend == null &&
                _requestFlights < 2 &&
                _requestDeferred) {
              _requestDeferred = false;
              _requestIfCurrentKeeperPresent(force: true);
            }
          }),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _requestToken = null;
    _requestSend = null;
    _requestDeferred = false;
    _invalidateAck();
    _antiEntropy?.cancel();
    _outstandingRequestId = null;
    _outstandingRequestExpiry = null;
    _snapshotRetry?.cancel();
    for (final timeout in _operationTimeouts) {
      timeout.cancel();
    }
    _operationTimeouts.clear();
    await Future.wait<void>([
      Future<void>.sync(() => _subscription.cancel()),
      Future<void>.sync(_synchronizationChanges.close),
      Future<void>.sync(() async {
        await _changes.close();
      }),
    ]);
  }
}

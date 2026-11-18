import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:totem_core/features/sessions/admission/session_admission_service.dart';
import 'package:totem_core/features/sessions/controllers/core/join_media_owner.dart';
import 'package:totem_core/features/sessions/controllers/core/session_poll_scheduler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/transport/session_transport.dart';

enum SessionJoinResult { success, retryableFailure, fatalFailure }

enum SessionRuntimePhase {
  idle,
  preparing,
  connecting,
  activating,
  connected,
  reconnecting,
  recoverableFailure,
  terminalFailure,
  leaving,
  disposed,
}

class SessionAttempt {
  SessionAttempt._(this._runtime, this.generation);
  final SessionRuntime _runtime;
  final int generation;
  bool get isCurrent => _runtime.isCurrent(this);
  void requireCurrent() {
    if (!isCurrent) throw StateError('Session attempt superseded');
  }
}

/// Owns connection operations and resources; feature state stays in services.
class SessionRuntime {
  SessionRuntime({
    required this.factory,
    required this.onEvent,
    required this.onCleanup,
    required this.onJoined,
    required this.retainEntry,
    required this.onError,
    required this.onCancel,
    required this.activateInfrastructure,
    required this.deactivateInfrastructure,
    this.previousEntryCleanup,
    this.sessionSlug,
  });
  final SessionTransportFactory factory;
  final Future<void>? previousEntryCleanup;
  final String? sessionSlug;
  final void Function() onCancel;
  SessionAttempt? get activeAttempt => _attempt;
  final void Function(Object error, StackTrace stack) onError;
  final Future<void> Function(Object owner) activateInfrastructure;
  final Future<void> Function(Object owner) deactivateInfrastructure;
  Future<void> activate() {
    if (!acceptsEvents) throw StateError('No active session attempt');
    return activateInfrastructure(entryIdentity);
  }

  final void Function(SessionTransportEvent event) onEvent;
  final Future<void> Function() onCleanup;
  final void Function() onJoined;
  final void Function() Function() retainEntry;
  Object _entryIdentity = Object();
  Object get entryIdentity => _entryIdentity;
  late final String _sessionCorrelationId = identityHashCode(
    _entryIdentity,
  ).toRadixString(16);
  bool _entryEnded = false;
  Object? lastFailure;
  final media = JoinMediaOwner();
  final polling = SessionPollScheduler();
  SessionAdmissionService? admission;
  SessionTransport? _transport;
  SessionTransport? get transport => _transport;
  // Cancelled and cleared by _cleanup before the transport is disposed.
  // ignore: cancel_subscriptions
  StreamSubscription<SessionTransportEvent>? _events;
  final _states = StreamController<SessionRuntimePhase>.broadcast(sync: true);
  Stream<SessionRuntimePhase> get states => _states.stream;
  SessionRuntimePhase _currentPhase = SessionRuntimePhase.idle;
  final Stopwatch _phaseDuration = Stopwatch()..start();
  SessionRuntimePhase get phase => _currentPhase;
  int _generation = 0;
  int get generation => _generation;
  SessionAttempt? _attempt;
  Future<SessionJoinResult>? _joining;
  Future<void>? _leaving;
  Future<void>? _cleaning;
  Future<void>? _disposing;
  ConnectedSessionLease? _offer;
  Timer? _deviceSetup;
  void Function()? _releaseEntry;
  bool _disposed = false;
  bool get isLeaving => _leaving != null;
  bool get isJoining => _joining != null;
  Future<void>? get leaving => _leaving;
  Future<void>? get cleaning => _cleaning;
  bool isCurrent(SessionAttempt attempt) =>
      !_disposed &&
      !isLeaving &&
      identical(_attempt, attempt) &&
      attempt.generation == generation;
  bool get acceptsEvents =>
      !_disposed && !isLeaving && _attempt != null && _attempt!.isCurrent;
  void _phase(SessionRuntimePhase next) {
    if (phase == next || _states.isClosed) return;
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'session.lifecycle',
          message: 'Session phase changed',
          level: SentryLevel.info,
          data: {
            'from': phase.name,
            'to': next.name,
            'generation': generation,
            'duration_ms': _phaseDuration.elapsedMilliseconds,
          },
        ),
      ),
    );
    _phaseDuration.reset();
    _currentPhase = next;
    _states.add(next);
  }

  void _invalidate() {
    _generation++;
    _attempt = null;
    polling.stop();
    _deviceSetup?.cancel();
    _deviceSetup = null;
    try {
      onCancel();
    } catch (error, stack) {
      onError(error, stack);
    }
  }

  void scheduleDeviceSetup(Duration delay, void Function() action) {
    _deviceSetup?.cancel();
    if (!acceptsEvents) return;
    final attempt = _attempt;
    _deviceSetup = Timer(delay, () {
      if (attempt?.isCurrent ?? false) action();
    });
  }

  void _listen(SessionTransport connection) {
    _events ??= connection.events.listen(
      (event) {
        if (!identical(_transport, connection)) return;
        if ((acceptsEvents || isLeaving) &&
            event is TransportConnectionChanged) {
          unawaited(
            Sentry.addBreadcrumb(
              Breadcrumb(
                category: 'session.connection',
                message: 'Transport connection changed',
                level: SentryLevel.info,
                data: {
                  'state': event.state.name,
                  'reason': event.reason?.name,
                  'reconnected': event.reconnected,
                  'generation': generation,
                  'session_slug': sessionSlug,
                  'session_correlation': _sessionCorrelationId,
                  'local_identity': connection.localIdentity,
                  'remote_participant_count': connection.participants
                      .where((participant) => !participant.isLocal)
                      .length,
                },
              ),
            ),
          );
        }
        if (event is TransportConnectionChanged && event.reconnected) {
          unawaited(
            Sentry.addBreadcrumb(
              Breadcrumb(
                category: 'session.connection',
                message: 'session.reconnected',
                level: SentryLevel.info,
                data: {
                  'generation': generation,
                  'session_slug': sessionSlug,
                  'session_correlation': _sessionCorrelationId,
                  'local_identity': connection.localIdentity,
                },
              ),
            ),
          );
        }
        if (!acceptsEvents) {
          // Preserve the current connection's final diagnostics during leave.
          if (isLeaving &&
              event is TransportConnectionChanged &&
              event.state == SessionTransportConnectionState.disconnected) {
            onEvent(event);
          }
          return;
        }
        if (event case TransportConnectionChanged(
          :final state,
          :final reconnected,
        )) {
          if (state == SessionTransportConnectionState.reconnecting &&
              phase == SessionRuntimePhase.connected) {
            _phase(SessionRuntimePhase.reconnecting);
          }
          if (reconnected && phase == SessionRuntimePhase.reconnecting) {
            _phase(SessionRuntimePhase.connected);
          }
        }
        onEvent(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (acceptsEvents && identical(_transport, connection)) {
          onError(error, stackTrace);
        }
      },
    );
  }

  Future<SessionTransport> prepare(
    SessionAttempt attempt,
    String url,
    String token,
  ) async {
    attempt.requireCurrent();
    final connection = _transport ??= factory.create();
    _listen(connection);
    await connection.prepare(url, token);
    attempt.requireCurrent();
    return connection;
  }

  /// Installs a transport for the legacy room compatibility bridge and tests.
  /// Remove with the C2 compatibility path.
  void installCompatibilityTransport(SessionTransport connection) {
    if (_disposed || isLeaving) {
      throw StateError('Session runtime cannot accept a connection');
    }
    if (_transport != null && !identical(_transport, connection)) {
      throw StateError(
        'Release the current connection before installing another',
      );
    }
    _transport = connection;
  }

  /// Starts observing a transport installed through the compatibility path.
  void observeCompatibilityTransport() {
    _attempt ??= SessionAttempt._(this, generation);
    if (_transport case final connection?) _listen(connection);
  }

  Future<SessionJoinResult> join({
    required Future<SessionJoinResult> Function(SessionAttempt attempt)
    operation,
    SessionJoinMedia? media,
    ConnectedSessionLease? offer,
  }) {
    if (_disposed) {
      return this.media.retain(media).dispose().then((_) async {
        await offer?.dispose();
        return SessionJoinResult.retryableFailure;
      });
    }
    final current = _joining;
    if (current != null &&
        offer != null &&
        !identical(offer.identity, _offer?.identity) &&
        !identical(offer.identity, _transport)) {
      return this.media.retain(media).dispose().then((_) async {
        await offer.dispose();
        return SessionJoinResult.retryableFailure;
      });
    }
    if (current != null) {
      return this.media.retain(media).dispose().then((_) => current);
    }
    if ((phase == SessionRuntimePhase.connected ||
            phase == SessionRuntimePhase.reconnecting) &&
        !isLeaving) {
      return this.media.retain(media).dispose().then((_) async {
        if (offer != null && identical(offer.identity, _transport)) {
          offer.claim();
          return SessionJoinResult.success;
        }
        await offer?.dispose();
        return offer == null
            ? SessionJoinResult.success
            : SessionJoinResult.retryableFailure;
      });
    }
    if (phase == SessionRuntimePhase.terminalFailure) {
      return this.media.retain(media).dispose().then((_) async {
        await offer?.dispose();
        return SessionJoinResult.fatalFailure;
      });
    }
    if (phase == SessionRuntimePhase.recoverableFailure && _cleaning == null) {
      unawaited(cleanup().catchError(onError));
    }
    _offer = offer;
    final completion = Completer<SessionJoinResult>();
    _joining = completion.future;
    unawaited(
      _run(
        operation,
        media,
        offer,
        completion.future,
      ).then(completion.complete, onError: completion.completeError),
    );
    return completion.future;
  }

  Future<SessionJoinResult> _run(
    Future<SessionJoinResult> Function(SessionAttempt) operation,
    SessionJoinMedia? media,
    ConnectedSessionLease? offer,
    Future<SessionJoinResult> flight,
  ) async {
    final priorLeave = _leaving;
    final priorCleanup = _cleaning;
    SessionAttempt? attempt;
    JoinMediaReceipt? receipt;
    try {
      if (previousEntryCleanup case final previous?) {
        try {
          await previous;
        } catch (error, stackTrace) {
          onError(error, stackTrace);
        }
      }
      if (priorLeave != null) await priorLeave;
      if (priorCleanup != null) await priorCleanup;
      if (_disposed || !identical(_joining, flight)) {
        return SessionJoinResult.retryableFailure;
      }
      receipt = this.media.retain(media);
      // A new entry after leaving cannot inherit callbacks from the old one.
      if (_entryEnded) {
        _entryIdentity = Object();
        admission = null;
        _entryEnded = false;
      }
      _releaseEntry ??= retainEntry();
      attempt = SessionAttempt._(this, ++_generation);
      _attempt = attempt;
      _phase(SessionRuntimePhase.preparing);
      if (offer != null) {
        attempt.requireCurrent();
        _transport = offer.claim();
        _offer = null;
        _listen(_transport!);
        _phase(SessionRuntimePhase.activating);
      } else {
        _phase(SessionRuntimePhase.connecting);
      }
      attempt.requireCurrent();
      final result = await operation(attempt);
      if (!attempt.isCurrent) return SessionJoinResult.retryableFailure;
      if (result != SessionJoinResult.success) {
        _invalidate();
        _phase(
          result == SessionJoinResult.fatalFailure
              ? SessionRuntimePhase.terminalFailure
              : SessionRuntimePhase.recoverableFailure,
        );
        return result;
      }
      _phase(SessionRuntimePhase.connected);
      attempt.requireCurrent();
      onJoined();
      return attempt.isCurrent ? result : SessionJoinResult.retryableFailure;
    } catch (error, stack) {
      onError(error, stack);
      if ((attempt?.isCurrent ?? identical(_joining, flight)) && !_disposed) {
        lastFailure = error;
        _invalidate();
        _phase(SessionRuntimePhase.recoverableFailure);
      }
      return SessionJoinResult.retryableFailure;
    } finally {
      await (receipt ?? this.media.retain(media)).dispose();
      // Do not clear a newer operation after a cancelled attempt finishes.
      if (identical(_joining, flight)) {
        _joining = null;
        _releaseEntry?.call();
        _releaseEntry = null;
      }
      if (identical(_offer, offer)) {
        _offer = null;
        await offer?.dispose();
      }
    }
  }

  Future<void> cleanup() {
    final current = _cleaning;
    if (current != null) return current;
    final completion = Completer<void>();
    _cleaning = completion.future;
    // Leave already cancelled its attempt; preserve any join queued behind it.
    if (!isLeaving) _joining = null;
    _invalidate();
    if (!isLeaving &&
        !_disposed &&
        phase != SessionRuntimePhase.terminalFailure) {
      _phase(SessionRuntimePhase.recoverableFailure);
    }
    unawaited(
      _cleanup().then(
        (_) {
          _cleaning = null;
          completion.complete();
        },
        onError: (Object error, StackTrace stack) {
          _cleaning = null;
          completion.completeError(error, stack);
        },
      ),
    );
    return completion.future;
  }

  // Always attempt every resource release, preserving the first diagnostic.
  Future<void> _releaseResources(List<Future<void> Function()> releases) async {
    Object? failure;
    StackTrace? failureStack;
    for (final release in releases) {
      try {
        await release();
      } catch (error, stack) {
        failure ??= error;
        failureStack ??= stack;
      }
    }
    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
  }

  Future<void> _cleanup() async {
    final connection = _transport;
    final listener = _events;
    final owner = entryIdentity;
    final releaseEntry = _releaseEntry;
    _releaseEntry = null;
    _events = null;
    try {
      await _releaseResources([
        () async {
          await listener?.cancel();
        },
        media.waitForPublications,
        onCleanup,
        () => deactivateInfrastructure(owner),
        () async {
          await admission?.disconnect();
        },
        () async {
          try {
            await connection?.dispose();
          } finally {
            if (identical(_transport, connection)) _transport = null;
          }
        },
        media.disposeAll,
      ]);
    } finally {
      releaseEntry?.call();
    }
  }

  Future<void> leave({required Future<void> Function() disconnect}) {
    if (_leaving case final leaving?) return leaving;
    _invalidate();
    final pending = _offer;
    _offer = null;
    _joining = null;
    final completion = Completer<void>();
    _leaving = completion.future;
    _phase(SessionRuntimePhase.leaving);
    unawaited(
      _leave(
        pending,
        disconnect,
      ).then(completion.complete, onError: completion.completeError),
    );
    return completion.future;
  }

  Future<void> _leave(
    ConnectedSessionLease? pending,
    Future<void> Function() disconnect,
  ) async {
    try {
      await _releaseResources([
        () async {
          await pending?.dispose();
        },
        () async {
          await admission?.close();
        },
        media.waitForPublications,
        disconnect,
        cleanup,
      ]);
    } finally {
      _releaseEntry?.call();
      _releaseEntry = null;
      _entryEnded = true;
      _leaving = null;
      if (!_disposed) _phase(SessionRuntimePhase.idle);
    }
  }

  Future<void> reset() async {
    final resetting = cleanup();
    final cancelledGeneration = generation;
    await resetting;
    if (!_disposed &&
        !isLeaving &&
        !isJoining &&
        generation == cancelledGeneration) {
      _phase(SessionRuntimePhase.idle);
    }
  }

  void leaveOnPageExit() {
    unawaited(_transport?.disconnect().catchError(onError));
  }

  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    try {
      await leave(
        disconnect: () async {
          await _transport?.disconnect();
        },
      );
    } finally {
      _phase(SessionRuntimePhase.disposed);
      await _states.close();
    }
  }
}

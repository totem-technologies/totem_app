import 'dart:async';

import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';

enum SessionCommandFailureKind {
  invalidState,
  unauthorized,
  network,
  conflict,
  device,
  partialSuccess,
  unknownOutcome,
  recoveryRequired,
  superseded,
  unexpected,
}

class SessionCommandException extends AppFeatureException {
  SessionCommandException(this.kind, String message, {this.cause})
    : super(message, details: cause);
  final Object? cause;
  final SessionCommandFailureKind kind;
}

class SessionCommandFailure {
  const SessionCommandFailure(this.kind, this.error);
  factory SessionCommandFailure.from(Object error) =>
      SessionCommandFailure(switch (error) {
        SessionCommandException(:final kind) => kind,
        AppNetworkException() ||
        TimeoutException() => SessionCommandFailureKind.network,
        AppAuthException() => SessionCommandFailureKind.unauthorized,
        ApiError(:final error)
            when error is RoomErrorResponse &&
                (error.code == ErrorCode.notKeeper ||
                    error.code == ErrorCode.banned) =>
          SessionCommandFailureKind.unauthorized,
        ApiError(:final error)
            when error is RoomErrorResponse &&
                (error.code == ErrorCode.staleVersion ||
                    error.code == ErrorCode.invalidTransition) =>
          SessionCommandFailureKind.conflict,
        _ => SessionCommandFailureKind.unexpected,
      }, error);
  final SessionCommandFailureKind kind;
  final Object error;
}

/// Rejects overlapping commands sharing a key and fences asynchronous results.
/// Backend errors retain their original types for the existing error UI.
class SessionCommandGate {
  SessionCommandGate(this.captureValidity);
  final bool Function() Function() captureValidity;
  final _busy = <Object>{};
  int _sequence = 0;
  bool _disposed = false;
  SessionCommandFailure? lastFailure;

  Future<T> run<T>(
    Future<T> Function(bool Function() current) action, {
    Object key = 'default',
  }) async {
    if (_disposed || _busy.contains(key)) {
      throw SessionCommandException(
        SessionCommandFailureKind.invalidState,
        'Another session command is running or this session has ended',
      );
    }
    _busy.add(key);
    final sequence = ++_sequence;
    final valid = captureValidity();
    bool current() => !_disposed && valid();
    try {
      if (!current()) {
        throw SessionCommandException(
          SessionCommandFailureKind.superseded,
          'This session connection has ended',
        );
      }
      final result = await action(current);
      if (sequence == _sequence) lastFailure = null;
      return result;
    } catch (error) {
      if (sequence == _sequence) {
        lastFailure = SessionCommandFailure.from(error);
      }
      rethrow;
    } finally {
      _busy.remove(key);
    }
  }

  void dispose() {
    _disposed = true;
  }
}

abstract interface class SessionTurnBackend {
  Future<RoomState> pass(
    int version, {
    String? customPrompt,
    int? sessionPromptId,
  });
  Future<RoomState> accept(int version);
  Future<RoomState> reorder(int version, List<String> order);
  Future<RoomState> forcePass(int version);
  Future<RoomState> start(int version, {String? prompt});
  Future<RoomState> end(int version);
  Future<RoomState> setPrompt(
    int version, {
    String? customPrompt,
    int? sessionPromptId,
    bool clearPrompt = false,
  });
}

abstract interface class SessionModerationBackend {
  Future<void> remove(String identity);
  Future<RoomState> ban(int version, String identity);
  Future<RoomState> unban(int version, String identity);
  Future<void> mute(String identity);
  Future<void> disableCamera(String identity);
  Future<void> muteEveryone();
}

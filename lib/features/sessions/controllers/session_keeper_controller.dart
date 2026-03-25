import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/session_controller.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/shared/logger.dart';

part 'session_keeper_controller.g.dart';

@Riverpod(keepAlive: true)
class SessionKeeperController extends _$SessionKeeperController {
  late SessionController _session;

  @override
  void build(SessionController session) {
    _session = session;
  }

  SessionRoomState get _state => _session.state;

  bool get _isCurrentUserKeeper => _session.isCurrentUserKeeper();

  String get _eventSlug => _session.options.eventSlug;

  int get _roomVersion => _state.roomState.version;

  Future<T> _run<T>({
    required Future<T> Function() action,
    required String errorMessage,
    Duration? timeout,
  }) async {
    try {
      final pending = action();
      if (timeout == null) {
        return await pending;
      }
      return await pending.timeout(
        timeout,
        onTimeout: () => throw AppNetworkException.timeout(),
      );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: errorMessage,
      );
      rethrow;
    }
  }

  Future<void> passTotem({String? roundMessage}) async {
    final room = _session.room;
    if (room == null || !_state.isMyTurn(room)) {
      throw StateError("Not the user's turn to pass the totem");
    }
    if (!_state.hasKeeper) {
      throw StateError('No keeper in the session to pass the totem');
    }
    if (roundMessage != null && !_isCurrentUserKeeper) {
      throw StateError(
        'Only the keeper can include a round message when passing the totem',
      );
    }

    await _session.devices.disableMicrophone();
    final roomState = await _run(
      action: () => ref.read(
        passTotemProvider(
          _eventSlug,
          _roomVersion,
          roundMessage: roundMessage,
        ).future,
      ),
      errorMessage: 'Error passing totem',
    );
    _session.applyRoomState(roomState);
    logger.i('Passed totem successfully');
  }

  Future<void> acceptTotem() async {
    final room = _session.room;
    if (room == null || !_state.amNext(room)) {
      throw StateError("Not the user's turn to accept the totem");
    }
    if (!_state.hasKeeper) {
      throw StateError('No keeper in the session to accept the totem');
    }

    final roomState = await _run(
      action: () => ref.read(
        acceptTotemProvider(
          _eventSlug,
          _roomVersion,
        ).future,
      ),
      errorMessage: 'Error accepting totem',
    );
    _session.applyRoomState(roomState);
    await _session.devices.enableMicrophone();
    logger.i('Accepted totem successfully');
  }

  Future<void> reorder(List<String> newOrder) async {
    if (!_isCurrentUserKeeper) return;
    final roomState = await _run(
      action: () => ref.read(
        reorderParticipantsProvider(
          _eventSlug,
          newOrder,
          _roomVersion,
        ).future,
      ),
      errorMessage: 'Error reordering participants',
    );
    _session.applyRoomState(roomState);
    logger.i('Reordered participants successfully');
  }

  Future<void> forcePassTotem() async {
    if (!_isCurrentUserKeeper) return;
    final roomState = await _run(
      action: () => ref.read(
        forcePassTotemProvider(
          _eventSlug,
          _roomVersion,
        ).future,
      ),
      errorMessage: 'Error force passing totem',
    );
    _session.applyRoomState(roomState);
    logger.i('Force passed totem successfully');
  }

  Future<void> removeParticipant(String participantSlug) async {
    if (!_isCurrentUserKeeper) return;
    await _run<void>(
      action: () => ref.read(
        removeParticipantProvider(
          _eventSlug,
          participantSlug,
        ).future,
      ),
      errorMessage: 'Error removing participant $participantSlug',
      timeout: const Duration(seconds: 20),
    );
    logger.i('Removed participant $participantSlug successfully');
  }

  Future<bool> startSession() async {
    if (!_isCurrentUserKeeper) return false;
    try {
      await _run<void>(
        action: () => ref.read(
          startSessionProvider(
            _eventSlug,
            _roomVersion,
          ).future,
        ),
        errorMessage: 'Error starting session',
        timeout: const Duration(seconds: 10),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> endSession() async {
    if (!_isCurrentUserKeeper) return false;
    try {
      final roomState = await _run(
        action: () => ref.read(
          endSessionProvider(
            _eventSlug,
            _roomVersion,
          ).future,
        ),
        errorMessage: 'Error ending session',
        timeout: const Duration(seconds: 10),
      );
      _session.applyRoomState(roomState);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> banParticipant(String participantSlug) async {
    if (!_isCurrentUserKeeper) return;
    await _run<void>(
      action: () => ref.read(
        banParticipantProvider(
          _eventSlug,
          participantSlug,
          _roomVersion,
        ).future,
      ),
      errorMessage: 'Error banning participant $participantSlug',
      timeout: const Duration(seconds: 20),
    );
    logger.i('Banned participant $participantSlug successfully');
  }

  Future<void> unbanParticipant(String participantSlug) async {
    if (!_isCurrentUserKeeper) return;

    await _run<void>(
      action: () => ref.read(
        unbanParticipantProvider(
          _eventSlug,
          participantSlug,
          _roomVersion,
        ).future,
      ),
      errorMessage: 'Error unbanning participant $participantSlug',
      timeout: const Duration(seconds: 20),
    );
    logger.i('Unbanned participant $participantSlug successfully');
  }

  Future<void> muteParticipant(String participantSlug) async {
    if (!_isCurrentUserKeeper) return;
    await _run<void>(
      action: () => ref.read(
        muteParticipantProvider(
          _eventSlug,
          participantSlug,
        ).future,
      ),
      errorMessage: 'Error muting participant $participantSlug',
      timeout: const Duration(seconds: 20),
    );
    logger.i('Muted participant $participantSlug successfully');
  }

  Future<void> muteEveryone() async {
    if (!_isCurrentUserKeeper) return;
    await _run<void>(
      action: () => ref.read(muteEveryoneProvider(_eventSlug).future),
      errorMessage: 'Error muting everyone',
      timeout: const Duration(seconds: 20),
    );
  }
}

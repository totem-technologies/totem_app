import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/app_exceptions.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart'
    hide session;
import 'package:totem_core/features/sessions/repositories/session_repository.dart';
import 'package:totem_core/shared/logger.dart';

part 'session_keeper_controller.g.dart';

@Riverpod(keepAlive: true)
class SessionKeeperController extends _$SessionKeeperController {
  static const keeperDisconnectionTimeout = Duration(minutes: 3);

  @visibleForTesting
  Timer? keeperDisconnectedTimer;

  @override
  void build(SessionController session) {}

  SessionRoomState get _state => session.state;

  String get _eventSlug => session.options.eventSlug;

  int get _roomVersion => _state.roomState.version;

  void onKeeperDisconnected(RoomStatus status) {
    if (status != RoomStatus.active) return;

    unawaited(session.devices.disableMicrophone());

    keeperDisconnectedTimer?.cancel();
    keeperDisconnectedTimer = Timer(keeperDisconnectionTimeout, () {
      unawaited(onKeeperDisconnectedTimeout());
    });
  }

  void onKeeperConnected() {
    keeperDisconnectedTimer?.cancel();
    keeperDisconnectedTimer = null;
  }

  Future<void> onKeeperDisconnectedTimeout() async {
    keeperDisconnectedTimer?.cancel();
    keeperDisconnectedTimer = null;

    await session.disconnectFromRoom();
  }

  void disposePresenceTracking() {
    keeperDisconnectedTimer?.cancel();
    keeperDisconnectedTimer = null;
  }

  Future<T> _run<T>({
    required AsyncValueGetter<T> action,
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
    final room = session.room;
    if (room == null || !_state.amSpeaking(room)) {
      throw StateError("Not the user's turn to pass the totem");
    }
    if (!_state.hasKeeper) {
      throw StateError('No keeper in the session to pass the totem');
    }
    if (roundMessage != null && !session.isCurrentUserKeeper()) {
      throw StateError(
        'Only the keeper can include a round message when passing the totem',
      );
    }

    await session.devices.disableMicrophone();
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
    session.applyRoomState(roomState);
    logger.i('Passed totem successfully');
  }

  /// Accepts the totem and enables the microphone.
  ///
  /// Throws a [StateError] if the user is not the next participant or there is no keeper.
  Future<void> acceptTotem() async {
    final room = session.room;
    if (room == null || !_state.amNext(room)) {
      throw StateError("Not the user's turn to accept the totem");
    }
    if (!_state.hasKeeper) {
      throw StateError('There is no Keeper in the session to accept the totem');
    }

    final wasMicEnabled = session.devices.isMicrophoneEnabled;
    final micFuture = session.devices.enableMicrophone();

    try {
      final roomState = await _run(
        action: () => ref.read(
          acceptTotemProvider(
            _eventSlug,
            _roomVersion,
          ).future,
        ),
        errorMessage: 'Error accepting totem',
      );
      session.applyRoomState(roomState);
      await micFuture;
      logger.i('Accepted totem successfully');
    } catch (e) {
      await micFuture.catchError((_) {});
      if (!wasMicEnabled) {
        await session.devices.disableMicrophone();
      }
      rethrow;
    }
  }

  Future<void> reorder(List<String> newOrder) async {
    if (!session.isCurrentUserKeeper()) return;
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
    session.applyRoomState(roomState);
    logger.i('Reordered participants successfully');
  }

  Future<void> forcePassTotem() async {
    if (!session.isCurrentUserKeeper()) return;
    final roomState = await _run(
      action: () => ref.read(
        forcePassTotemProvider(
          _eventSlug,
          _roomVersion,
        ).future,
      ),
      errorMessage: 'Error force passing totem',
    );
    session.applyRoomState(roomState);
    logger.i('Force passed totem successfully');
  }

  Future<void> removeParticipant(String participantSlug) async {
    if (!session.isCurrentUserKeeper()) return;
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
    if (!session.isCurrentUserKeeper()) return false;
    try {
      final roomState = await _run(
        action: () => ref.read(
          startSessionProvider(
            _eventSlug,
            _roomVersion,
          ).future,
        ),
        errorMessage: 'Error starting session',
        timeout: const Duration(seconds: 10),
      );
      session.applyRoomState(roomState);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> endSession() async {
    if (!session.isCurrentUserKeeper()) return false;
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
      session.applyRoomState(roomState);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> banParticipant(String participantSlug) async {
    if (!session.isCurrentUserKeeper()) return;
    final roomState = await _run(
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
    session.applyRoomState(roomState);

    logger.i('Banned participant $participantSlug successfully');
  }

  Future<void> unbanParticipant(String participantSlug) async {
    if (!session.isCurrentUserKeeper()) return;

    final roomState = await _run(
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
    session.applyRoomState(roomState);
    logger.i('Unbanned participant $participantSlug successfully');
  }

  Future<void> disableParticipantCamera(String participantSlug) async {
    if (!session.isCurrentUserKeeper()) return;
    await _run<void>(
      action: () => ref.read(
        disableParticipantCameraProvider(
          _eventSlug,
          participantSlug,
        ).future,
      ),
      errorMessage: 'Error disable participant camera $participantSlug',
      timeout: const Duration(seconds: 20),
    );
    logger.i('Disabled participant $participantSlug camera successfully');
  }

  Future<void> muteParticipant(String participantSlug) async {
    if (!session.isCurrentUserKeeper()) return;
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
    if (!session.isCurrentUserKeeper()) return;
    await _run<void>(
      action: () => ref.read(muteEveryoneProvider(_eventSlug).future),
      errorMessage: 'Error muting everyone',
      timeout: const Duration(seconds: 20),
    );
  }
}

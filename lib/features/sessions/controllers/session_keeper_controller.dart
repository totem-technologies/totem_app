import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/session_types.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/shared/logger.dart';

class SessionKeeperController {
  SessionKeeperController({
    required this.ref,
    required this.currentRoom,
    required this.isMyTurn,
    required this.amNext,
    required this.hasKeeper,
    required this.roomVersion,
    required this.eventSlug,
    required this.isCurrentUserKeeper,
    required this.enableMicrophone,
    required this.disableMicrophone,
    required this.onRoomState,
  });

  final Ref ref;
  final CurrentRoomGetter currentRoom;
  final RoomPredicate isMyTurn;
  final RoomPredicate amNext;
  final BoolGetter hasKeeper;
  final IntGetter roomVersion;
  final StringGetter eventSlug;
  final BoolGetter isCurrentUserKeeper;
  final AsyncCallback enableMicrophone;
  final AsyncCallback disableMicrophone;
  final RoomStateCallback onRoomState;

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
    final room = currentRoom();
    if (room == null || !isMyTurn(room)) {
      throw StateError("Not the user's turn to pass the totem");
    }
    if (!hasKeeper()) {
      throw StateError('No keeper in the session to pass the totem');
    }
    if (roundMessage != null && !isCurrentUserKeeper()) {
      throw StateError(
        'Only the keeper can include a round message when passing the totem',
      );
    }

    await disableMicrophone();
    final roomState = await _run(
      action: () => ref.read(
        passTotemProvider(
          eventSlug(),
          roomVersion(),
          roundMessage: roundMessage,
        ).future,
      ),
      errorMessage: 'Error passing totem',
    );
    onRoomState(roomState);
    logger.i('Passed totem successfully');
  }

  Future<void> acceptTotem() async {
    final room = currentRoom();
    if (room == null || !amNext(room)) {
      throw StateError("Not the user's turn to accept the totem");
    }
    if (!hasKeeper()) {
      throw StateError('No keeper in the session to accept the totem');
    }

    final roomState = await _run(
      action: () => ref.read(
        acceptTotemProvider(
          eventSlug(),
          roomVersion(),
        ).future,
      ),
      errorMessage: 'Error accepting totem',
    );
    onRoomState(roomState);
    await enableMicrophone();
    logger.i('Accepted totem successfully');
  }

  Future<void> reorder(List<String> newOrder) async {
    if (!isCurrentUserKeeper()) return;
    final roomState = await _run(
      action: () => ref.read(
        reorderParticipantsProvider(
          eventSlug(),
          newOrder,
          roomVersion(),
        ).future,
      ),
      errorMessage: 'Error reordering participants',
    );
    onRoomState(roomState);
    logger.i('Reordered participants successfully');
  }

  Future<void> forcePassTotem() async {
    if (!isCurrentUserKeeper()) return;
    final roomState = await _run(
      action: () => ref.read(
        forcePassTotemProvider(
          eventSlug(),
          roomVersion(),
        ).future,
      ),
      errorMessage: 'Error force passing totem',
    );
    onRoomState(roomState);
    logger.i('Force passed totem successfully');
  }

  Future<void> removeParticipant(String participantSlug) async {
    if (!isCurrentUserKeeper()) return;
    await _run<void>(
      action: () => ref.read(
        removeParticipantProvider(
          eventSlug(),
          participantSlug,
        ).future,
      ),
      errorMessage: 'Error removing participant $participantSlug',
      timeout: const Duration(seconds: 20),
    );
    logger.i('Removed participant $participantSlug successfully');
  }

  Future<bool> startSession() async {
    if (!isCurrentUserKeeper()) return false;
    try {
      await _run<void>(
        action: () => ref.read(
          startSessionProvider(
            eventSlug(),
            roomVersion(),
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
    if (!isCurrentUserKeeper()) return false;
    try {
      final roomState = await _run(
        action: () => ref.read(
          endSessionProvider(
            eventSlug(),
            roomVersion(),
          ).future,
        ),
        errorMessage: 'Error ending session',
        timeout: const Duration(seconds: 10),
      );
      onRoomState(roomState);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> banParticipant(String participantSlug) async {
    if (!isCurrentUserKeeper()) return;
    await _run<void>(
      action: () => ref.read(
        banParticipantProvider(
          eventSlug(),
          participantSlug,
          roomVersion(),
        ).future,
      ),
      errorMessage: 'Error banning participant $participantSlug',
      timeout: const Duration(seconds: 20),
    );
    logger.i('Banned participant $participantSlug successfully');
  }

  Future<void> unbanParticipant(String participantSlug) async {
    if (!isCurrentUserKeeper()) return;

    await _run<void>(
      action: () => ref.read(
        unbanParticipantProvider(
          eventSlug(),
          participantSlug,
          roomVersion(),
        ).future,
      ),
      errorMessage: 'Error unbanning participant $participantSlug',
      timeout: const Duration(seconds: 20),
    );
    logger.i('Unbanned participant $participantSlug successfully');
  }

  Future<void> muteParticipant(String participantSlug) async {
    if (!isCurrentUserKeeper()) return;
    await _run<void>(
      action: () => ref.read(
        muteParticipantProvider(
          eventSlug(),
          participantSlug,
        ).future,
      ),
      errorMessage: 'Error muting participant $participantSlug',
      timeout: const Duration(seconds: 20),
    );
    logger.i('Muted participant $participantSlug successfully');
  }

  Future<void> muteEveryone() async {
    if (!isCurrentUserKeeper()) return;
    await _run<void>(
      action: () => ref.read(muteEveryoneProvider(eventSlug()).future),
      errorMessage: 'Error muting everyone',
      timeout: const Duration(seconds: 20),
    );
  }
}

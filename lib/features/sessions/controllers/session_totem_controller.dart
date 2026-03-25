import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide logger;
import 'package:totem_app/core/api/lib/totem_mobile_api.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/shared/logger.dart';

class SessionTotemController {
  SessionTotemController({
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
  final Room? Function() currentRoom;
  final bool Function(Room room) isMyTurn;
  final bool Function(Room room) amNext;
  final bool Function() hasKeeper;
  final int Function() roomVersion;
  final String Function() eventSlug;
  final bool Function() isCurrentUserKeeper;
  final Future<void> Function() enableMicrophone;
  final Future<void> Function() disableMicrophone;
  final void Function(RoomState roomState) onRoomState;

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
    try {
      final roomState = await ref.read(
        passTotemProvider(
          eventSlug(),
          roomVersion(),
          roundMessage: roundMessage,
        ).future,
      );
      onRoomState(roomState);
      logger.i('Passed totem successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error passing totem',
      );
      rethrow;
    }
  }

  Future<void> acceptTotem() async {
    final room = currentRoom();
    if (room == null || !amNext(room)) {
      throw StateError("Not the user's turn to accept the totem");
    }
    if (!hasKeeper()) {
      throw StateError('No keeper in the session to accept the totem');
    }

    try {
      final roomState = await ref.read(
        acceptTotemProvider(
          eventSlug(),
          roomVersion(),
        ).future,
      );
      onRoomState(roomState);
      await enableMicrophone();
      logger.i('Accepted totem successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error accepting totem',
      );
      rethrow;
    }
  }

  Future<void> reorder(List<String> newOrder) async {
    if (!isCurrentUserKeeper()) return;
    try {
      final roomState = await ref.read(
        reorderParticipantsProvider(
          eventSlug(),
          newOrder,
          roomVersion(),
        ).future,
      );
      onRoomState(roomState);
      logger.i('Reordered participants successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error reordering participants',
      );
      rethrow;
    }
  }

  Future<void> forcePassTotem() async {
    if (!isCurrentUserKeeper()) return;
    try {
      final roomState = await ref.read(
        forcePassTotemProvider(
          eventSlug(),
          roomVersion(),
        ).future,
      );
      onRoomState(roomState);
      logger.i('Force passed totem successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error force passing totem',
      );
      rethrow;
    }
  }
}

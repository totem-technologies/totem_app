import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:totem_app/core/errors/app_exceptions.dart';
import 'package:totem_app/core/errors/error_handler.dart';
import 'package:totem_app/features/sessions/controllers/session_types.dart';
import 'package:totem_app/features/sessions/repositories/session_repository.dart';
import 'package:totem_app/shared/logger.dart';

class SessionModerationController {
  SessionModerationController({
    required this.ref,
    required this.eventSlug,
    required this.roomVersion,
    required this.isCurrentUserKeeper,
    required this.onRoomState,
  });

  final Ref ref;
  final StringGetter eventSlug;
  final IntGetter roomVersion;
  final BoolGetter isCurrentUserKeeper;
  final RoomStateCallback onRoomState;

  Future<void> removeParticipant(String participantSlug) async {
    if (!isCurrentUserKeeper()) return;
    try {
      await ref
          .read(
            removeParticipantProvider(
              eventSlug(),
              participantSlug,
            ).future,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw AppNetworkException.timeout();
            },
          );
      logger.i('Removed participant $participantSlug successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error removing participant $participantSlug',
      );
      rethrow;
    }
  }

  Future<bool> startSession() async {
    if (!isCurrentUserKeeper()) return false;
    try {
      await ref
          .read(
            startSessionProvider(
              eventSlug(),
              roomVersion(),
            ).future,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw AppNetworkException.timeout();
            },
          );
      return true;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error starting session',
      );
      return false;
    }
  }

  Future<bool> endSession() async {
    if (!isCurrentUserKeeper()) return false;
    try {
      final roomState = await ref
          .read(
            endSessionProvider(
              eventSlug(),
              roomVersion(),
            ).future,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw AppNetworkException.timeout();
            },
          );
      onRoomState(roomState);
      return true;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error ending session',
      );
      return false;
    }
  }

  Future<void> banParticipant(String participantSlug) async {
    if (!isCurrentUserKeeper()) return;
    try {
      await ref
          .read(
            banParticipantProvider(
              eventSlug(),
              participantSlug,
              roomVersion(),
            ).future,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw AppNetworkException.timeout(),
          );

      logger.i('Banned participant $participantSlug successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error banning participant $participantSlug',
      );
      rethrow;
    }
  }

  Future<void> unbanParticipant(String participantSlug) async {
    if (!isCurrentUserKeeper()) return;

    try {
      await ref
          .read(
            unbanParticipantProvider(
              eventSlug(),
              participantSlug,
              roomVersion(),
            ).future,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw AppNetworkException.timeout(),
          );
      logger.i('Unbanned participant $participantSlug successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error unbanning participant $participantSlug',
      );
      rethrow;
    }
  }

  Future<void> muteParticipant(String participantSlug) async {
    if (!isCurrentUserKeeper()) return;
    try {
      await ref
          .read(
            muteParticipantProvider(
              eventSlug(),
              participantSlug,
            ).future,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw AppNetworkException.timeout();
            },
          );
      logger.i('Muted participant $participantSlug successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error muting participant $participantSlug',
      );
      rethrow;
    }
  }

  Future<void> muteEveryone() async {
    if (!isCurrentUserKeeper()) return;
    try {
      await ref
          .read(muteEveryoneProvider(eventSlug()).future)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw AppNetworkException.timeout();
            },
          );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error muting everyone',
      );
      rethrow;
    }
  }
}

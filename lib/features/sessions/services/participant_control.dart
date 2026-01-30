// We need to access SessionService.ref to notify listeners
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'session_service.dart';

extension ParticipantControl on Session {
  /// Pass the totem to the next participant in the speaking order.
  ///
  /// This fails silently if it's not the user's turn.
  /// Throws an exception if the operation fails.
  Future<void> passTotem() async {
    if (!isKeeper() && !state.isMyTurn(context)) return;
    try {
      await ref.read(passTotemProvider(options.eventSlug).future);
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

  /// Accept the totem when it's passed to the user.
  ///
  /// This fails silently if it's not the user's turn.
  /// Throws an exception if the operation fails.
  Future<void> acceptTotem() async {
    if (!isKeeper() && !state.amNext(context)) {
      throw StateError("Not the user's turn to accept the totem");
    }
    try {
      await ref.read(acceptTotemProvider(options.eventSlug).future);
      enableMicrophone();
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

  /// Send an emoji to other participants.
  /// This operation is fire-and-forget and doesn't throw errors.
  Future<void> sendReaction(String emoji) async {
    try {
      await context.localParticipant
          ?.publishData(
            const Utf8Encoder().convert(emoji),
            topic: SessionCommunicationTopics.emoji.topic,
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              ErrorHandler.logError(
                TimeoutException('Sending emoji timed out'),
                message: 'Warning: Sending emoji timed out',
              );
            },
          );
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error sending emoji',
      );
    }
  }

  Future<void> emitAppState(AppLifecycleState state) async {
    try {
      await context.localParticipant?.publishData(
        const Utf8Encoder().convert(state.name),
        topic: SessionCommunicationTopics.lifecycle.topic,
      );
      logger.d('Emitted lifecycle status successfully');
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace: stackTrace,
        message: 'Error emitting lifecycle status',
      );
    }
  }
}

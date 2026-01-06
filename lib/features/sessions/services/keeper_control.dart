// We need to access LivekitService.ref to notify listeners
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'livekit_service.dart';

extension KeeperControl on LiveKitService {
  /// Get the participant who is currently speaking.
  Participant speakingNow() {
    return room.participants.firstWhere(
      (participant) {
        if (state.sessionState.speakingNow != null) {
          if (state.sessionState.totemStatus == TotemStatus.passing) {
            return participant.identity == options.keeperSlug;
          }
          return participant.identity == state.sessionState.speakingNow;
        } else {
          // If no one is speaking right now, show the keeper's video
          return participant.identity == options.keeperSlug;
        }
      },
      orElse: () => room.localParticipant!,
    );
  }

  Future<void> _onKeeperDisconnected() async {
    _hasKeeperDisconnected = true;
    await disableMicrophone();

    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = Timer(
      LiveKitService.keeperDisconnectionTimeout,
      _onKeeperDisconnectedTimeout,
    );

    closeKeeperLeftNotification ??= options.onKeeperLeaveRoom(this);
  }

  void _onKeeperConnected() {
    _hasKeeperDisconnected = false;

    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    closeKeeperLeftNotification?.call();
    closeKeeperLeftNotification = null;
  }

  Future<void> _onKeeperDisconnectedTimeout() async {
    await room.disconnect();

    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;
  }

  Future<void> startSession() async {
    if (!isKeeper()) return;
    try {
      await ref
          .read(startSessionProvider(_options.eventSlug).future)
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
        message: 'Error starting session',
      );
      rethrow;
    }
  }

  Future<void> endSession() async {
    if (!isKeeper()) return;
    try {
      await ref
          .read(endSessionProvider(_options.eventSlug).future)
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
        message: 'Error ending session',
      );
      rethrow;
    }
  }

  Future<void> muteEveryone() async {
    try {
      await ref
          .read(muteEveryoneProvider(_options.eventSlug).future)
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

// We need to access LivekitService.ref to notify listeners
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'session_service.dart';

extension KeeperControl on Session {
  bool isKeeper([String? userSlug]) {
    if (userSlug == null) {
      final currentUserSlug = ref.read(
        authControllerProvider.select((auth) => auth.user?.slug),
      );
      userSlug = currentUserSlug;
    }

    return state.sessionState.keeperSlug == userSlug;
  }

  /// Get the participant who is currently speaking.
  Participant speakingNowParticipant() {
    return state.participants.firstWhere(
      (participant) {
        if (state.sessionState.speakingNow != null) {
          return participant.identity == state.sessionState.speakingNow;
        } else {
          // If no one is speaking right now, show the keeper's video
          return participant.identity == state.sessionState.keeperSlug;
        }
      },
      orElse: () => context.localParticipant!,
    );
  }

  Participant? speakingNextParticipant() {
    if (state.sessionState.nextSpeaker == null) return null;
    return state.participants.firstWhereOrNull((participant) {
      return participant.identity == state.sessionState.nextSpeaker;
    });
  }

  Future<void> _onKeeperDisconnected() async {
    state = state.copyWith(hasKeeperDisconnected: true);

    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = Timer(
      Session.keeperDisconnectionTimeout,
      _onKeeperDisconnectedTimeout,
    );

    closeKeeperLeftNotification?.call();
    closeKeeperLeftNotification = null;
    closeKeeperLeftNotification ??= options.onKeeperLeaveRoom(this);
  }

  void _onKeeperConnected() {
    state = state.copyWith(hasKeeperDisconnected: false);

    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    closeKeeperLeftNotification?.call();
    closeKeeperLeftNotification = null;
  }

  Future<void> _onKeeperDisconnectedTimeout() async {
    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    closeKeeperLeftNotification?.call();
    closeKeeperLeftNotification = null;

    reason = SessionEndedReason.keeperLeft;

    await context.disconnect();
  }

  Future<bool> startSession() async {
    if (!isKeeper()) return false;
    try {
      await ref
          .read(startSessionProvider(_options.eventSlug).future)
          .timeout(
            const Duration(seconds: 20),
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
    if (!isKeeper()) return false;
    try {
      await ref
          .read(endSessionProvider(_options.eventSlug).future)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw AppNetworkException.timeout();
            },
          );
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

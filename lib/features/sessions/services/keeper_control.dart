// We need to access LivekitService.ref to notify listeners
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'session_service.dart';

extension KeeperControl on Session {
  bool isKeeper([String? userSlug]) {
    String? slug = userSlug;
    if (slug == null) {
      final currentUserSlug = ref.read(
        authControllerProvider.select((auth) => auth.user?.slug),
      );
      slug = currentUserSlug;
    }

    return state.roomState.keeper == slug;
  }

  /// Get the participant who is currently speaking.
  Participant speakingNowParticipant() {
    return state.participants.firstWhere(
      (participant) => participant.identity == state.speakingNow,
      orElse: () => context!.room.localParticipant!,
    );
  }

  Participant? speakingNextParticipant() {
    if (state.roomState.nextSpeaker == null) return null;
    return state.participants.firstWhereOrNull((participant) {
      return participant.identity == state.roomState.nextSpeaker;
    });
  }

  void closeKeeperLeftNotifications() {
    for (final close in closeKeeperLeftNotificationCallbacks) {
      close.call();
    }
    closeKeeperLeftNotificationCallbacks.clear();
  }

  void _onKeeperDisconnected() {
    if (state.roomState.status != RoomStatus.active) return;

    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = Timer(
      Session.keeperDisconnectionTimeout,
      _onKeeperDisconnectedTimeout,
    );

    closeKeeperLeftNotifications();
    closeKeeperLeftNotificationCallbacks.add(options.onKeeperLeaveRoom(this));

    state = state.copyWith(hasKeeperDisconnected: true);
  }

  void _onKeeperConnected() {
    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    closeKeeperLeftNotifications();

    state = state.copyWith(hasKeeperDisconnected: false);
  }

  Future<void> _onKeeperDisconnectedTimeout() async {
    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    closeKeeperLeftNotifications();

    await context?.disconnect();
  }

  Future<void> removeParticipant(String participantSlug) async {
    try {
      await ref
          .read(
            removeParticipantProvider(
              options.eventSlug,
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
    if (!isKeeper()) return false;
    try {
      await ref
          .read(
            startSessionProvider(
              _options!.eventSlug,
              state.roomState.version,
            ).future,
          )
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
      final roomState = await ref
          .read(
            endSessionProvider(
              _options!.eventSlug,
              state.roomState.version,
            ).future,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw AppNetworkException.timeout();
            },
          );
      _onRoomChanges(roomState);
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

  Future<void> muteParticipant(String participantSlug) async {
    try {
      await ref
          .read(
            muteParticipantProvider(
              options.eventSlug,
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
    try {
      await ref
          .read(muteEveryoneProvider(_options!.eventSlug).future)
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

  Future<void> reorder(List<String> newOrder) async {
    try {
      final roomState = await ref.read(
        reorderParticipantsProvider(
          options.eventSlug,
          newOrder,
          state.roomState.version,
        ).future,
      );
      _onRoomChanges(roomState);
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
    try {
      final roomState = await ref.read(
        forcePassTotemProvider(
          options.eventSlug,
          state.roomState.version,
        ).future,
      );
      _onRoomChanges(roomState);
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

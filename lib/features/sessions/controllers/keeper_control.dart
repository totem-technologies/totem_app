// We need to access LivekitService.ref to notify listeners
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

part of 'session_controller.dart';

extension KeeperControl on SessionController {
  /// Whether the current authenticated user is the keeper.
  bool isCurrentUserKeeper() {
    final currentUserSlug = ref.read(
      authControllerProvider.select((auth) => auth.user?.slug),
    );
    if (currentUserSlug == null) return false;
    return state.isKeeper(currentUserSlug);
  }

  void _onKeeperDisconnected() {
    if (state.roomState.status != RoomStatus.active) return;
    disableMicrophone();

    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = Timer(
      SessionController.keeperDisconnectionTimeout,
      _onKeeperDisconnectedTimeout,
    );

    _dispatch(const _KeeperDisconnectedChanged(true));
  }

  void _onKeeperConnected() {
    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    _dispatch(const _KeeperDisconnectedChanged(false));
  }

  Future<void> _onKeeperDisconnectedTimeout() async {
    _keeperDisconnectedTimer?.cancel();
    _keeperDisconnectedTimer = null;

    await room?.disconnect();
  }

  Future<void> removeParticipant(String participantSlug) async {
    if (!isCurrentUserKeeper()) return;
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
    if (!isCurrentUserKeeper()) return false;
    try {
      await ref
          .read(
            startSessionProvider(
              _options!.eventSlug,
              state.roomState.version,
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
              _options!.eventSlug,
              state.roomState.version,
            ).future,
          )
          .timeout(
            const Duration(seconds: 10),
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

  Future<void> banParticipant(String participantSlug) async {
    if (!isCurrentUserKeeper()) return;
    try {
      await ref
          .read(
            banParticipantProvider(
              options.eventSlug,
              participantSlug,
              state.roomState.version,
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
              options.eventSlug,
              participantSlug,
              state.roomState.version,
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
    if (!isCurrentUserKeeper()) return;
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
    await _totem.reorder(newOrder);
  }

  Future<void> forcePassTotem() async {
    await _totem.forcePassTotem();
  }
}

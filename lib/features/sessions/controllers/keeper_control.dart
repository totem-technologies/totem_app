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
    _keeperPresence.onKeeperDisconnected(state.roomState.status);
  }

  void _onKeeperConnected() {
    _keeperPresence.onKeeperConnected();
  }

  Future<void> removeParticipant(String participantSlug) async {
    await _moderation.removeParticipant(participantSlug);
  }

  Future<bool> startSession() async {
    return _moderation.startSession();
  }

  Future<bool> endSession() async {
    return _moderation.endSession();
  }

  Future<void> banParticipant(String participantSlug) async {
    await _moderation.banParticipant(participantSlug);
  }

  Future<void> unbanParticipant(String participantSlug) async {
    await _moderation.unbanParticipant(participantSlug);
  }

  Future<void> muteParticipant(String participantSlug) async {
    await _moderation.muteParticipant(participantSlug);
  }

  Future<void> muteEveryone() async {
    await _moderation.muteEveryone();
  }

  Future<void> reorder(List<String> newOrder) async {
    await _totem.reorder(newOrder);
  }

  Future<void> forcePassTotem() async {
    await _totem.forcePassTotem();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/permissions/model.dart';
import 'package:totem_core/features/sessions/controllers/core/session_controller.dart';
import 'package:totem_core/features/sessions/repositories/session_command_backend.dart';
import 'package:totem_core/features/sessions/services/session_keeper_presence.dart';
import 'package:totem_core/features/sessions/services/session_moderation_service.dart';
import 'package:totem_core/features/sessions/services/session_turn_service.dart';

part 'session_keeper_controller.g.dart';

/// Compatibility facade and composition boundary. Services own feature logic.
@riverpod
class SessionKeeperController extends _$SessionKeeperController {
  static const keeperDisconnectionTimeout = Duration(minutes: 3);
  late SessionTurnService _turns;
  SessionTurnService get turns => _turns;
  late SessionModerationService _moderation;
  SessionModerationService get moderation => _moderation;
  late SessionKeeperPresence _presence;
  SessionKeeperPresence get presence => _presence;
  @visibleForTesting
  Timer? get keeperDisconnectedTimer => presence.timer;

  @override
  void build(SessionController session) {
    final backend = SessionCommandBackend(ref, session.options.sessionSlug);
    bool Function() captureValidity() {
      final attempt = session.activeAttempt;
      return () => ref.mounted && (attempt?.isCurrent ?? false);
    }

    _turns = SessionTurnService(
      backend: backend,
      state: () => session.state,
      localIdentity: () => session.transport?.localIdentity,
      isKeeper: session.isCurrentUserKeeper,
      applyState: session.applyRoomState,
      disableMicrophone: session.devices.disableMicrophone,
      enableMicrophone: () => session.devices.turnOn(MediaKind.microphone),
      microphoneRevision: () => session.devices.microphoneIntentRevision,
      microphoneDesired: () => true,
      microphoneEnabled: () => session.devices.isMicrophoneEnabled,
      flagMicrophoneProblem: () =>
          session.devices.flagNeedsAttention(MediaKind.microphone),
      captureValidity: captureValidity,
    );
    _moderation = SessionModerationService(
      backend: backend,
      state: () => session.state,
      isKeeper: session.isCurrentUserKeeper,
      transport: () => session.transport,
      applyState: session.applyRoomState,

      markRemoved: session.markParticipantRemoved,
      leave: session.disconnectFromRoom,
      onError: (error, stack) => ErrorHandler.logError(
        error,
        stackTrace: stack,
        message: 'Session moderation failed',
      ),
      captureValidity: captureValidity,
    );
    _presence = SessionKeeperPresence(
      mute: session.devices.disableMicrophone,
      leave: session.disconnectFromRoom,
      onError: (error, stack) => ErrorHandler.logError(
        error,
        stackTrace: stack,
        message: 'Keeper presence operation failed',
      ),
    );
    ref.onDispose(() {
      turns.dispose();
      moderation.dispose();
      presence.dispose();
    });
  }

  void onKeeperDisconnected(RoomStatus status) => presence.disconnected(status);
  void onKeeperConnected() => presence.connected();
  Future<void> onKeeperDisconnectedTimeout() => presence.expired();
  void disposePresenceTracking() => presence.cancel();
  Future<void> passTotem({String? customPrompt, int? sessionPromptId}) => turns
      .passTotem(customPrompt: customPrompt, sessionPromptId: sessionPromptId);
  Future<void> acceptTotem() async {
    await turns.acceptTotem();
  }

  Future<void> reorder(List<String> order) => turns.reorder(order);
  Future<void> forcePassTotem() => turns.forcePassTotem();
  Future<void> setPrompt({
    String? customPrompt,
    int? sessionPromptId,
    bool clearPrompt = false,
  }) => turns.setPrompt(
    customPrompt: customPrompt,
    sessionPromptId: sessionPromptId,
    clearPrompt: clearPrompt,
  );
  // Legacy dialog callbacks still accept bool: failure now propagates instead
  // of silently returning false. The domain service has a void/exception API.
  Future<bool> startSession({String? prompt}) async {
    await turns.start(prompt: prompt);
    return true;
  }

  Future<bool> endSession() async {
    await turns.end();
    return true;
  }

  Future<void> removeParticipant(String identity) =>
      moderation.removeParticipant(identity);
  Future<void> banParticipant(String identity) =>
      moderation.banParticipant(identity);
  Future<void> unbanParticipant(String identity) =>
      moderation.unbanParticipant(identity);
  Future<void> muteParticipant(String identity) =>
      moderation.muteParticipant(identity);
  Future<void> disableParticipantCamera(String identity) =>
      moderation.disableParticipantCamera(identity);
  Future<void> muteEveryone() => moderation.muteEveryone();
}

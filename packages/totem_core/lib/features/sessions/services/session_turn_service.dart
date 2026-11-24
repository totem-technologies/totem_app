import 'dart:async';

import 'package:totem_core/core/api/api_client/api_client.dart';
import 'package:totem_core/features/permissions/media_control.dart';
import 'package:totem_core/features/sessions/controllers/core/session_state.dart';
import 'package:totem_core/features/sessions/services/session_commands.dart';

enum TurnAcceptance { accepted, acceptedDeviceUnavailable }

class SessionTurnService {
  SessionTurnService({
    required this.backend,
    required this.state,
    required this.localIdentity,
    required this.isKeeper,
    required this.applyState,
    required this.disableMicrophone,
    required this.enableMicrophone,
    required this.microphoneRevision,
    required this.microphoneDesired,
    required this.flagMicrophoneProblem,
    required bool Function() Function() captureValidity,
    bool Function()? microphoneEnabled,
  }) : microphoneEnabled = microphoneEnabled ?? (() => false),
       _commands = SessionCommandGate(captureValidity);
  final SessionTurnBackend backend;
  final SessionRoomState Function() state;
  final String? Function() localIdentity;
  final bool Function() isKeeper;
  final void Function(RoomState) applyState;
  final Future<void> Function() disableMicrophone;
  final Future<TurnOnOutcome> Function() enableMicrophone;
  final int Function() microphoneRevision;
  final bool Function() microphoneDesired;
  final bool Function() microphoneEnabled;
  final void Function() flagMicrophoneProblem;
  final SessionCommandGate _commands;
  SessionCommandFailure? get lastFailure => _commands.lastFailure;

  /// How long a turn command may wait for the backend before its outcome is
  /// reported as unknown.
  static const turnCommandTimeout = Duration(seconds: 10);

  /// The backend may still apply a timed-out turn command, so a timeout is an
  /// unknown outcome rather than a definite failure.
  /// Waits [turnCommandTimeout] for [request]. A timeout becomes an unknown
  /// outcome, unless room state already shows the command was applied, in
  /// which case this returns null so the caller can run side effects and
  /// skip committing a late HTTP response.
  Future<RoomState?> _awaitTurnCommand(
    Future<RoomState> request, {
    required bool Function() applied,
  }) async {
    try {
      return await request.timeout(turnCommandTimeout);
    } on TimeoutException catch (error) {
      if (applied()) return null;
      throw SessionCommandException(
        SessionCommandFailureKind.unknownOutcome,
        'The turn command timed out and may still be applied. Check the room state before retrying.',
        cause: error,
      );
    }
  }

  Future<void> _silenceAfterPass(bool Function() current) async {
    if (!current()) return;
    try {
      await disableMicrophone();
      if (current() && microphoneEnabled()) {
        throw StateError('Microphone remains enabled');
      }
    } catch (error) {
      if (current()) {
        throw SessionCommandException(
          SessionCommandFailureKind.partialSuccess,
          'Your turn was passed, but the microphone could not be muted. Mute it or leave the session.',
          cause: error,
        );
      }
    }
  }

  /// Mutes the local microphone if this participant is no longer speaking.
  ///
  /// Used when a pass is confirmed by room state after the HTTP request
  /// timed out, including when that confirmation arrives after the service
  /// has already thrown an unknown outcome.
  Future<void> silenceIfNoLongerSpeaking() async {
    if (state().amSpeaking(localIdentity())) return;
    try {
      await disableMicrophone();
    } catch (_) {}
  }

  void _requireKeeper() {
    if (!isKeeper()) {
      throw SessionCommandException(
        SessionCommandFailureKind.unauthorized,
        'Only the Keeper can perform this action',
      );
    }
  }

  void _commit(
    RoomState response,
    bool Function() current, {
    int? commandVersion,
  }) {
    if (!current()) {
      throw SessionCommandException(
        SessionCommandFailureKind.superseded,
        'The command completed after this session connection ended',
      );
    }
    final accepted = state().roomState;
    if (response.version < accepted.version) return;
    final ending =
        accepted.status != RoomStatus.ended &&
        response.status == RoomStatus.ended;
    final unchangedCommand =
        commandVersion != null && response.version <= commandVersion && !ending;
    if (unchangedCommand ||
        (response.version == accepted.version &&
            response != accepted &&
            !ending)) {
      throw SessionCommandException(
        SessionCommandFailureKind.conflict,
        'The command did not return a newer, consistent room state. Please try again.',
      );
    }
    applyState(response);
  }

  Future<void> passTotem({String? customPrompt, int? sessionPromptId}) =>
      _commands.run((current) async {
        if (!state().amSpeaking(localIdentity()) || !state().hasKeeper) {
          throw SessionCommandException(
            SessionCommandFailureKind.invalidState,
            'It is not your turn or the Keeper is away',
          );
        }
        if (customPrompt != null && sessionPromptId != null) {
          throw ArgumentError('Choose one prompt');
        }
        if (customPrompt != null || sessionPromptId != null) _requireKeeper();
        final version = state().roomState.version;
        final before = state().roomState;
        final response = await _awaitTurnCommand(
          backend.pass(
            version,
            customPrompt: customPrompt,
            sessionPromptId: sessionPromptId,
          ),
          applied: () => sessionPassApplied(before, state(), localIdentity()),
        );
        if (response != null) {
          _commit(response, current, commandVersion: version);
        }
        // A committed pass hands off the microphone even while room state is in
        // the passing transition and still names the previous current speaker.
        await _silenceAfterPass(current);
        if (!current()) {
          throw SessionCommandException(
            SessionCommandFailureKind.superseded,
            'This session connection has ended',
          );
        }
      });

  Future<TurnAcceptance> acceptTotem() => _commands.run((current) async {
    if (!state().amNext(localIdentity()) || !state().hasKeeper) {
      throw SessionCommandException(
        SessionCommandFailureKind.invalidState,
        'It is not your turn or the Keeper is away',
      );
    }
    final revision = microphoneRevision();
    final before = state().roomState;
    final response = await _awaitTurnCommand(
      backend.accept(state().roomState.version),
      applied: () => sessionAcceptApplied(before, state(), localIdentity()),
    );
    if (response != null) {
      _commit(response, current);
    }
    // Respect an explicit device decision made while the backend was pending.
    if (!current() ||
        !state().amSpeaking(localIdentity()) ||
        microphoneRevision() != revision ||
        !microphoneDesired()) {
      return TurnAcceptance.accepted;
    }
    try {
      final outcome = await enableMicrophone();
      if (current() && outcome is TurnOnFailed) {
        flagMicrophoneProblem();
        return TurnAcceptance.acceptedDeviceUnavailable;
      }
      return outcome is TurnOnSkipped
          ? TurnAcceptance.acceptedDeviceUnavailable
          : TurnAcceptance.accepted;
    } catch (_) {
      if (current()) flagMicrophoneProblem();
      return TurnAcceptance.acceptedDeviceUnavailable;
    }
  });

  Future<void> reorder(List<String> order) => _commands.run((current) async {
    _requireKeeper();
    _commit(await backend.reorder(state().roomState.version, order), current);
  });
  Future<void> forcePassTotem() => _commands.run((current) async {
    _requireKeeper();
    final before = state().roomState;
    final response = await _awaitTurnCommand(
      backend.forcePass(state().roomState.version),
      applied: () => sessionForcePassApplied(before, state()),
    );
    if (response != null) {
      _commit(response, current);
    }
  });
  Future<void> start({String? prompt}) => _commands.run((current) async {
    _requireKeeper();
    _commit(
      await backend
          .start(state().roomState.version, prompt: prompt)
          .timeout(const Duration(seconds: 10)),
      current,
    );
  });
  Future<void> end() => _commands.run((current) async {
    _requireKeeper();
    _commit(
      await backend
          .end(state().roomState.version)
          .timeout(const Duration(seconds: 10)),
      current,
    );
  }, key: 'end');
  Future<void> setPrompt({
    String? customPrompt,
    int? sessionPromptId,
    bool clearPrompt = false,
  }) => _commands.run((current) async {
    _requireKeeper();
    if ([
          customPrompt != null,
          sessionPromptId != null,
          clearPrompt,
        ].where((v) => v).length !=
        1) {
      throw ArgumentError('Choose one prompt action');
    }
    _commit(
      await backend.setPrompt(
        state().roomState.version,
        customPrompt: customPrompt,
        sessionPromptId: sessionPromptId,
        clearPrompt: clearPrompt,
      ),
      current,
    );
  });
  void dispose() => _commands.dispose();
}

/// Whether [after] shows that a pass already left this participant's turn.
///
/// A committed pass may still name the previous current speaker while the
/// turn is in the passing transition, so [TurnState.passing] also counts.
bool sessionPassApplied(
  RoomState before,
  SessionRoomState after,
  String? localIdentity,
) {
  final next = after.turn.roomState;
  if (next.turnState == TurnState.passing &&
      before.turnState != TurnState.passing) {
    return true;
  }
  return !after.amSpeaking(localIdentity) &&
      (before.currentSpeaker.value == localIdentity ||
          next.currentSpeaker.value != before.currentSpeaker.value);
}

/// Whether [after] shows this participant is now the speaker after an accept.
bool sessionAcceptApplied(
  RoomState before,
  SessionRoomState after,
  String? localIdentity,
) {
  return after.amSpeaking(localIdentity) &&
      before.currentSpeaker.value != localIdentity;
}

/// Whether [after] shows a force pass already moved the turn.
bool sessionForcePassApplied(RoomState before, SessionRoomState after) {
  final next = after.turn.roomState;
  return next.currentSpeaker.value != before.currentSpeaker.value ||
      next.nextSpeaker.value != before.nextSpeaker.value ||
      next.turnState != before.turnState;
}

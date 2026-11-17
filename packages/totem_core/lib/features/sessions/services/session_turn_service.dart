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

  Future<void> passTotem({
    String? customPrompt,
    int? sessionPromptId,
  }) => _commands.run((current) async {
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
    final response = await backend.pass(
      version,
      customPrompt: customPrompt,
      sessionPromptId: sessionPromptId,
    );
    _commit(response, current, commandVersion: version);
    // A committed pass hands off the microphone even while room state is in
    // the passing transition and still names the previous current speaker.
    if (current()) {
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
    final response = await backend.accept(state().roomState.version);
    _commit(response, current);
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
    _commit(await backend.forcePass(state().roomState.version), current);
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

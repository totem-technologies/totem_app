import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:totem_core/core/api/api_client/api_client.dart' show RoomState;
import 'package:totem_core/core/errors/error_handler.dart';
import 'package:totem_core/features/sessions/providers/session_scope_provider.dart';
import 'package:totem_core/features/sessions/services/session_commands.dart';
import 'package:totem_core/features/sessions/services/session_turn_service.dart';
import 'package:totem_core/shared/totem_icons.dart';
import 'package:totem_core/shared/widgets/notifications.dart';

part 'session_action_feedback.g.dart';

/// Manual in-session actions whose failures are reported at room level.
enum SessionAction {
  passTotem,
  acceptTotem,
  forcePass,
  startSession,
  endSession,
  muteEveryone,
  muteParticipant,
  disableParticipantCamera,
  removeParticipant,
  banParticipant,
  setPrompt,
}

typedef SessionActionErrorCopy = ({String title, String message});

const _checkConnection = 'Please check your connection and try again.';

/// User-facing copy for a failed [action].
///
/// Returns null when the failure needs no action banner, such as a superseded
/// connection that the disconnect UI already explains. Exception messages are
/// written for developers and are never shown here.
SessionActionErrorCopy? sessionActionErrorCopy(
  SessionAction action,
  SessionCommandFailure failure, {
  String? subject,
}) {
  final kind = failure.kind;
  if (kind == SessionCommandFailureKind.superseded) return null;
  final name = subject ?? 'this participant';
  return switch (action) {
    SessionAction.passTotem => switch (kind) {
      SessionCommandFailureKind.unknownOutcome => (
        title: 'Still passing the totem',
        message:
            "We couldn't confirm the pass. If the totem doesn't move in a moment, try again.",
      ),
      SessionCommandFailureKind.partialSuccess => (
        title: 'Totem passed',
        message:
            "Your microphone couldn't be muted. Please mute it from the controls below.",
      ),
      _ => (
        title: "Couldn't pass the totem",
        message: "It's still your turn. Check your connection and try again.",
      ),
    },
    SessionAction.acceptTotem => switch (kind) {
      SessionCommandFailureKind.unknownOutcome => (
        title: 'Still receiving the totem',
        message:
            "We couldn't confirm it. If it's not your turn in a moment, try again.",
      ),
      _ => (
        title: "Couldn't receive the totem",
        message: 'We were unable to accept the totem. Please try again.',
      ),
    },
    SessionAction.forcePass => switch (kind) {
      SessionCommandFailureKind.unknownOutcome => (
        title: "Still passing to ${subject ?? 'the next person'}",
        message: "We couldn't confirm it. Check the room before trying again.",
      ),
      _ => (
        title: "Couldn't pass to ${subject ?? 'the next person'}",
        message: "The totem hasn't moved. Please try again.",
      ),
    },
    SessionAction.startSession => (
      title: "Couldn't start the session",
      message: 'Everyone is still in the waiting room. Please try again.',
    ),
    SessionAction.endSession => (
      title: "Couldn't end the session",
      message: 'The session is still running. Please try again.',
    ),
    SessionAction.muteEveryone => (
      title: "Couldn't mute everyone",
      message: _checkConnection,
    ),
    SessionAction.muteParticipant => (
      title: "Couldn't mute $name",
      message: _checkConnection,
    ),
    SessionAction.disableParticipantCamera => (
      title: "Couldn't turn off $name's camera",
      message: _checkConnection,
    ),
    SessionAction.removeParticipant => switch (kind) {
      SessionCommandFailureKind.unknownOutcome => (
        title: "We're not sure $name was removed",
        message: 'Give it a moment before trying again.',
      ),
      SessionCommandFailureKind.partialSuccess => (
        title: '$name was removed',
        message: "Some cleanup didn't finish. Please keep the session open.",
      ),
      _ => (title: "Couldn't remove $name", message: _checkConnection),
    },
    SessionAction.banParticipant => (
      title: "Couldn't ban $name",
      message: _checkConnection,
    ),
    SessionAction.setPrompt => (
      title: "Couldn't update the prompt",
      message: 'Please try again.',
    ),
  };
}

/// Whether room state shows the totem changed hands or turn phase since
/// [before], which confirms a turn command whose own outcome is unknown.
bool sessionTurnMoved(RoomState? before, RoomState? after) =>
    before != null &&
    after != null &&
    (after.currentSpeaker.value != before.currentSpeaker.value ||
        after.turnState != before.turnState);

/// One reported action failure, ready to present.
///
/// Each report is a distinct object, so repeating the same failure notifies
/// listeners again.
class SessionActionReport {
  const SessionActionReport({
    required this.action,
    required this.subject,
    required this.kind,
    required this.copy,
  });
  final SessionAction action;
  final String? subject;
  final SessionCommandFailureKind kind;
  final SessionActionErrorCopy copy;

  /// Repeated failures of one action on one subject replace each other.
  Object get dedupeKey => ('sessionAction', action, subject);
}

/// Room-level channel for failed manual actions.
///
/// Actions report here instead of using a [BuildContext] that may already be
/// gone, for example when a dialog closes. [SessionActionFeedbackEffects]
/// presents each report on the room's shared notification queue.
@Riverpod(keepAlive: true, dependencies: [sessionScope, currentSessionState])
class SessionActionFeedback extends _$SessionActionFeedback {
  @override
  SessionActionReport? build() {
    ref.watch(sessionScopeProvider);
    return null;
  }

  /// The room state to compare against with [turnAppliedDespite].
  RoomState? turnSnapshot() => ref.read(currentSessionStateProvider)?.roomState;

  /// Whether a turn command that failed was applied anyway, because room
  /// state moved on since [before].
  ///
  /// Unknown outcomes, conflicts and invalid-state errors can all mean the
  /// first request landed after a timeout or retry.
  bool turnAppliedDespite(
    Object error,
    RoomState? before, {
    required SessionAction action,
    String? localIdentity,
  }) {
    final kind = SessionCommandFailure.from(error).kind;
    if (kind != SessionCommandFailureKind.unknownOutcome &&
        kind != SessionCommandFailureKind.conflict &&
        kind != SessionCommandFailureKind.invalidState) {
      return false;
    }
    final after = ref.read(currentSessionStateProvider);
    if (before == null || after == null) return false;
    return switch (action) {
      SessionAction.passTotem => sessionPassApplied(
        before,
        after,
        localIdentity,
      ),
      SessionAction.acceptTotem => sessionAcceptApplied(
        before,
        after,
        localIdentity,
      ),
      SessionAction.forcePass => sessionForcePassApplied(before, after),
      _ => sessionTurnMoved(before, after.roomState),
    };
  }

  void report(
    SessionAction action,
    Object error, {
    String? subject,
    StackTrace? stackTrace,
  }) {
    final failure = SessionCommandFailure.from(error);
    if (failure.kind == SessionCommandFailureKind.superseded) return;
    ErrorHandler.report(
      error,
      stackTrace: stackTrace,
      message: 'Session action failed: ${action.name} (${failure.kind.name})',
      incidentKey: 'session-action-${action.name}',
      // Connection and room-state races are expected while in a session.
      disposition: switch (failure.kind) {
        SessionCommandFailureKind.unexpected ||
        SessionCommandFailureKind.partialSuccess ||
        SessionCommandFailureKind.recoveryRequired =>
          ErrorDisposition.unexpected,
        _ => ErrorDisposition.expected,
      },
    );
    final copy = sessionActionErrorCopy(action, failure, subject: subject);
    if (copy == null) return;
    state = SessionActionReport(
      action: action,
      subject: subject,
      kind: failure.kind,
      copy: copy,
    );
  }
}

/// Shows [SessionActionFeedback] reports as room banners.
class SessionActionFeedbackEffects extends ConsumerWidget {
  const SessionActionFeedbackEffects({
    required this.notifications,
    required this.child,
    super.key,
  });
  final NotificationController notifications;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sessionActionFeedbackProvider, (_, report) {
      if (report == null || !context.mounted) return;
      notifications.showError(
        context,
        icon: TotemIcons.errorOutlined,
        title: report.copy.title,
        message: report.copy.message,
        urgentLatestWinsCategory: report.dedupeKey,
      );
    });
    return child;
  }
}
